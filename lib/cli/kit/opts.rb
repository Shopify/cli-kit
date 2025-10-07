# typed: true

require 'cli/kit'

module CLI
  module Kit
    class Opts
      module Mixin
        include Kernel

        module MixinClassMethods
          #: (Module included_module) -> void
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

          #: (Symbol method_name) -> void
          def track_method(method_name)
            @tracked_methods ||= []
            @tracked_methods << method_name unless @tracked_methods.include?(method_name)
          end

          #: -> Array[Symbol]
          def tracked_methods
            @tracked_methods || []
          end
        end

        class << self
          #: (Module klass) -> void
          def included(klass)
            klass.extend(MixinClassMethods)
          end
        end

        #: (?name: Symbol, ?short: String?, ?long: String?, ?desc: String?, ?default: (String | ^-> String)?) -> String?
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

        #: (?name: Symbol, ?short: String?, ?long: String?, ?desc: String?, ?default: (String | ^-> String)?) -> String
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

        #: (?name: Symbol, ?short: String?, ?long: String?, ?desc: String?, ?default: (Array[String] | ^-> Array[String])) -> Array[String]
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

        #: (?name: Symbol, ?short: String?, ?long: String?, ?desc: String?) -> bool
        def flag(name: infer_name, short: nil, long: nil, desc: nil)
          case @obj
          when Args::Definition
            @obj.add_flag(name, short: short, long: long, desc: desc)
            false
          when Args::Evaluation
            @obj.flag.send(name)
          end
        end

        #: (?name: Symbol, ?desc: String?) -> String
        def position!(name: infer_name, desc: nil)
          case @obj
          when Args::Definition
            @obj.add_position(name, desc: desc, required: true, multi: false)
            '(result unavailable)'
          when Args::Evaluation
            @obj.position.send(name)
          end
        end

        #: (?name: Symbol, ?desc: String?, ?default: (String | ^-> String)?, ?skip: (^-> bool | ^(String arg0) -> bool)?) -> String?
        def position(name: infer_name, desc: nil, default: nil, skip: nil)
          case @obj
          when Args::Definition
            @obj.add_position(name, desc: desc, required: false, multi: false, default: default, skip: skip)
            '(result unavailable)'
          when Args::Evaluation
            @obj.position.send(name)
          end
        end

        #: (?name: Symbol, ?desc: String?) -> Array[String]
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

        #: (String? label) -> Symbol?
        def symbolize(label)
          return if label.nil?

          label.split('#').last&.to_sym
        end

        #: -> Symbol
        def infer_name
          to_skip = 1
          Kernel.caller_locations.each do |loc|
            next if loc.path =~ /sorbet-runtime/

            if to_skip > 0
              to_skip -= 1
              next
            end
            return symbolize(loc.label) #: as !nil
          end
          raise(ArgumentError, 'could not infer name')
        end
      end
      include(Mixin)

      DEFAULT_OPTIONS = [:helpflag]

      #: -> bool
      def helpflag
        flag(name: :help, short: '-h', long: '--help', desc: 'Show this help message')
      end

      #: -> Array[String]
      def unparsed
        obj = assert_result!
        obj.unparsed
      end

      #: ?{ (Symbol arg0, String? arg1) -> void } -> untyped
      def each_option(&block)
        return enum_for(:each_option) unless block_given?

        obj = assert_result!
        obj.defn.options.each do |opt|
          name = opt.name
          value = obj.opt.send(name)
          yield(name, value)
        end
      end

      #: ?{ (Symbol arg0, bool arg1) -> void } -> untyped
      def each_flag(&block)
        return enum_for(:each_flag) unless block_given?

        obj = assert_result!
        obj.defn.flags.each do |flag|
          name = flag.name
          value = obj.flag.send(name)
          yield(name, value)
        end
      end

      #: (String name) -> (String | bool)?
      def [](name)
        obj = assert_result!
        if obj.opt.respond_to?(name)
          obj.opt.send(name)
        elsif obj.flag.respond_to?(name)
          obj.flag.send(name)
        end
      end

      #: (String name) -> String?
      def lookup_option(name)
        obj = assert_result!
        obj.opt.send(name)
      rescue NoMethodError
        # TODO: should we raise a KeyError?
        nil
      end

      #: (String name) -> bool
      def lookup_flag(name)
        obj = assert_result!
        obj.flag.send(name)
      rescue NoMethodError
        false
      end

      #: -> Args::Evaluation
      def assert_result!
        raise(NotImplementedError, 'not implemented') if @obj.is_a?(Args::Definition)

        @obj
      end

      #: (Args::Definition defn) -> void
      def define!(defn)
        @obj = defn
        klass = self.class #: as Mixin::MixinClassMethods
        klass.tracked_methods.each do |m|
          send(m)
        end
        DEFAULT_OPTIONS.each do |m|
          send(m)
        end
      end

      #: (Args::Evaluation ev) -> void
      def evaluate!(ev)
        @obj = ev
        ev.resolve_positions!
      end
    end
  end
end
