# typed: true
require 'cli/kit'

module CLI
  module Kit
    class Opts
      extend T::Sig

      module Mixin
        extend T::Sig
        include Kernel

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
              name, short: short, long: long, desc: desc, default: default,
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
              name, short: short, long: long, desc: desc, default: default,
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

        private

        sig { returns(Symbol) }
        def infer_name
          to_skip = 1
          Kernel.caller_locations&.each do |loc|
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

      sig { params(name: String).returns(T.nilable(Symbol)) }
      def option_missing(name)
        nil
      end

      sig { returns(T::Boolean) }
      def helpflag
        flag(name: :help, short: '-h', long: '--help', desc: 'Show this help message')
      end

      sig { params(obj: T.any(Args::Definition, Args::Evaluation)).void }
      def initialize(obj)
        @obj = obj
      end

      sig { returns(T::Array[String]) }
      def args
        obj = assert_result!
        obj.args
      end

      sig { returns(T::Array[String]) }
      def rest
        obj = assert_result!
        obj.rest
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

      sig { void }
      def install_to_definition
        raise('not a Definition') unless @obj.is_a?(Args::Definition)

        @obj.option_missing(method(:option_missing))

        methods = self.class.ancestors.reduce([]) do |acc, klass|
          break(acc) if klass == CLI::Kit::Opts
          acc + klass.public_instance_methods(false)
        end
        methods.each do |m|
          next if m == :option_missing
          send(m)
        end
        DEFAULT_OPTIONS.each do |m|
          send(m)
        end
      end
    end
  end
end
