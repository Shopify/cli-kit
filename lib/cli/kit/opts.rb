# typed: true

require 'cli/kit'

module CLI
  module Kit
    class Opts
      extend T::Sig

      module Mixin
        extend T::Sig
        include Kernel

        module MixinClassMethods
          extend T::Sig

          sig { params(included_module: Module).void }
          def include(included_module)
            super
            return unless included_module.is_a?(MixinClassMethods)

            included_module.tracked_methods.each { |m| track_method(m) }
          end

          # No signature - Sorbet uses method_added internally, so can't verify it
          def method_added(method_name) # rubocop:disable Sorbet/EnforceSignatures
            super
            track_method(method_name)
          end

          sig { params(method_name: Symbol).void }
          def track_method(method_name)
            @tracked_methods ||= []
            @tracked_methods << method_name unless @tracked_methods.include?(method_name)
          end

          sig { returns(T::Array[Symbol]) }
          def tracked_methods
            @tracked_methods || []
          end
        end

        class << self
          extend T::Sig

          sig { params(klass: Module).void }
          def included(klass)
            klass.extend(MixinClassMethods)
          end
        end

        sig do
          params(
            name: Symbol,
            short: T.nilable(String),
            long: T.nilable(String),
            desc: T.nilable(String),
            default: T.any(NilClass, String, T.proc.returns(String)),
          ).returns(T.nilable(String))
        end
        def option(name: infer_name, short: nil, long: nil, desc: nil, default: nil)
          unless default.nil?
            raise(ArgumentError, 'declare options with non-nil defaults using `option!` instead of `option`')
          end

          case @obj
          when Args::Definition
            @obj.add_option(
              name, short: short, long: long, desc: desc, default: default
            )
            '(result unavailable)'
          when Args::Evaluation
            @obj.opt.send(name)
          end
        end

        sig do
          params(
            name: Symbol,
            short: T.nilable(String),
            long: T.nilable(String),
            desc: T.nilable(String),
            default: T.any(NilClass, String, T.proc.returns(String)),
          ).returns(String)
        end
        def option!(name: infer_name, short: nil, long: nil, desc: nil, default: nil)
          case @obj
          when Args::Definition
            @obj.add_option(
              name, short: short, long: long, desc: desc, default: default
            )
            '(result unavailable)'
          when Args::Evaluation
            @obj.opt.send(name)
          end
        end

        sig do
          params(
            name: Symbol,
            short: T.nilable(String),
            long: T.nilable(String),
            desc: T.nilable(String),
            default: T.any(T::Array[String], T.proc.returns(T::Array[String])),
          ).returns(T::Array[String])
        end
        def multi_option(name: infer_name, short: nil, long: nil, desc: nil, default: [])
          case @obj
          when Args::Definition
            @obj.add_option(
              name, short: short, long: long, desc: desc, default: default, multi: true
            )
            ['(result unavailable)']
          when Args::Evaluation
            @obj.opt.send(name)
          end
        end

        sig do
          params(
            name: Symbol,
            short: T.nilable(String),
            long: T.nilable(String),
            desc: T.nilable(String),
          ).returns(T::Boolean)
        end
        def flag(name: infer_name, short: nil, long: nil, desc: nil)
          case @obj
          when Args::Definition
            @obj.add_flag(name, short: short, long: long, desc: desc)
            false
          when Args::Evaluation
            @obj.flag.send(name)
          end
        end

        sig { params(name: Symbol, desc: T.nilable(String)).returns(String) }
        def position!(name: infer_name, desc: nil)
          case @obj
          when Args::Definition
            @obj.add_position(name, desc: desc, required: true, multi: false)
            '(result unavailable)'
          when Args::Evaluation
            @obj.position.send(name)
          end
        end

        sig do
          params(
            name: Symbol,
            desc: T.nilable(String),
            default: T.any(NilClass, String, T.proc.returns(String)),
            skip: T.any(
              NilClass,
              T.proc.returns(T::Boolean),
              T.proc.params(arg0: String).returns(T::Boolean),
            ),
          ).returns(T.nilable(String))
        end
        def position(name: infer_name, desc: nil, default: nil, skip: nil)
          case @obj
          when Args::Definition
            @obj.add_position(name, desc: desc, required: false, multi: false, default: default, skip: skip)
            '(result unavailable)'
          when Args::Evaluation
            @obj.position.send(name)
          end
        end

        sig { params(name: Symbol, desc: T.nilable(String)).returns(T::Array[String]) }
        def rest(name: infer_name, desc: nil)
          case @obj
          when Args::Definition
            @obj.add_position(name, desc: desc, required: false, multi: true)
            ['(result unavailable)']
          when Args::Evaluation
            @obj.position.send(name)
          end
        end

        private

        sig { returns(Symbol) }
        def infer_name
          to_skip = 1
          Kernel.caller_locations.each do |loc|
            next if loc.path =~ /sorbet-runtime/

            if to_skip > 0
              to_skip -= 1
              next
            end
            return(T.must(loc.label&.to_sym))
          end
          raise(ArgumentError, 'could not infer name')
        end
      end
      include(Mixin)

      DEFAULT_OPTIONS = [:helpflag]

      sig { returns(T::Boolean) }
      def helpflag
        flag(name: :help, short: '-h', long: '--help', desc: 'Show this help message')
      end

      sig { returns(T::Array[String]) }
      def unparsed
        obj = assert_result!
        obj.unparsed
      end

      sig do
        params(
          block: T.nilable(
            T.proc.params(arg0: Symbol, arg1: T.nilable(String)).void,
          ),
        ).returns(T.untyped)
      end
      def each_option(&block)
        return(enum_for(:each_option)) unless block_given?

        obj = assert_result!
        obj.defn.options.each do |opt|
          name = opt.name
          value = obj.opt.send(name)
          yield(name, value)
        end
      end

      sig do
        params(
          block: T.nilable(
            T.proc.params(arg0: Symbol, arg1: T::Boolean).void,
          ),
        ).returns(T.untyped)
      end
      def each_flag(&block)
        return(enum_for(:each_flag)) unless block_given?

        obj = assert_result!
        obj.defn.flags.each do |flag|
          name = flag.name
          value = obj.flag.send(name)
          yield(name, value)
        end
      end

      sig { params(name: String).returns(T.nilable(T.any(String, T::Boolean))) }
      def [](name)
        obj = assert_result!
        if obj.opt.respond_to?(name)
          obj.opt.send(name)
        elsif obj.flag.respond_to?(name)
          obj.flag.send(name)
        end
      end

      sig { params(name: String).returns(T.nilable(String)) }
      def lookup_option(name)
        obj = assert_result!
        obj.opt.send(name)
      rescue NoMethodError
        # TODO: should we raise a KeyError?
        nil
      end

      sig { params(name: String).returns(T::Boolean) }
      def lookup_flag(name)
        obj = assert_result!
        obj.flag.send(name)
      rescue NoMethodError
        false
      end

      sig { returns(Args::Evaluation) }
      def assert_result!
        raise(NotImplementedError, 'not implemented') if @obj.is_a?(Args::Definition)

        @obj
      end

      sig { params(defn: Args::Definition).void }
      def define!(defn)
        @obj = defn
        T.cast(self.class, Mixin::MixinClassMethods).tracked_methods.each do |m|
          send(m)
        end
        DEFAULT_OPTIONS.each do |m|
          send(m)
        end
      end

      sig { params(ev: Args::Evaluation).void }
      def evaluate!(ev)
        @obj = ev
        ev.resolve_positions!
      end
    end
  end
end
