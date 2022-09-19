# typed: true

require 'cli/kit'

module CLI
  module Kit
    module Args
      class Definition
        extend T::Sig

        Error = Class.new(Args::Error)
        ConflictingFlag = Class.new(Error)
        InvalidFlag = Class.new(Error)
        InvalidLookup = Class.new(Error)
        InvalidPosition = Class.new(Error)

        sig { returns(T::Array[Flag]) }
        attr_reader :flags

        sig { returns(T::Array[Option]) }
        attr_reader :options

        sig { returns(T::Array[Position]) }
        attr_reader :positions

        sig { params(name: Symbol, short: T.nilable(String), long: T.nilable(String), desc: T.nilable(String)).void }
        def add_flag(name, short: nil, long: nil, desc: nil)
          short, long = strip_prefixes_and_validate(short, long)
          flag = Flag.new(name: name, short: short, long: long, desc: desc)
          add_resolution(flag)
          @flags << flag
        end

        sig do
          params(
            name: Symbol, short: T.nilable(String), long: T.nilable(String),
            desc: T.nilable(String),
            default: T.any(
              NilClass,
              String, T.proc.returns(String),
              T::Array[String], T.proc.returns(T::Array[String])
            ),
            required: T::Boolean, multi: T::Boolean
          ).void
        end
        def add_option(name, short: nil, long: nil, desc: nil, default: nil, required: false, multi: false)
          short, long = strip_prefixes_and_validate(short, long)
          option = Option.new(
            name: name, short: short, long: long, desc: desc, default: default,
            required: required, multi: multi
          )
          add_resolution(option)
          @options << option
        end

        sig do
          params(
            name: Symbol,
            required: T::Boolean,
            multi: T::Boolean,
            desc: T.nilable(String),
            default: T.any(NilClass, String, T.proc.returns(String)),
            skip: T.any(
              NilClass,
              T.proc.returns(T::Boolean),
              T.proc.params(arg0: String).returns(T::Boolean),
            ),
          ).void
        end
        def add_position(name, required:, multi:, desc: nil, default: nil, skip: nil)
          position = Position.new(
            name: name, desc: desc, required: required, multi: multi,
            default: default, skip: skip
          )
          validate_order(position)
          add_name_resolution(position)
          @positions << position
        end

        sig { void }
        def initialize
          @flags = []
          @options = []
          @by_short = {}
          @by_long = {}
          @by_name = {}
          @positions = []
        end

        module OptBase
          extend T::Sig

          sig { returns(Symbol) }
          attr_reader :name

          sig { returns(T.nilable(String)) }
          attr_reader :desc
        end

        module OptValue
          extend T::Sig

          sig { returns(T.any(NilClass, String, T::Array[String])) }
          def default
            if @default.is_a?(Proc)
              @default.call
            else
              @default
            end
          end

          sig { returns(T::Boolean) }
          def dynamic_default?
            @default.is_a?(Proc)
          end

          sig { returns(T::Boolean) }
          def required?
            @required
          end

          sig { returns(T::Boolean) }
          def multi?
            @multi
          end

          sig { returns(T::Boolean) }
          def optional?
            !required?
          end
        end

        class Flag
          extend T::Sig
          include OptBase

          sig { returns(T.nilable(String)) }
          attr_reader :short

          sig { returns(T.nilable(String)) }
          attr_reader :long

          sig { returns(String) }
          def as_written_by_user
            long ? "--#{long}" : "-#{short}"
          end

          sig { params(name: Symbol, short: T.nilable(String), long: T.nilable(String), desc: T.nilable(String)).void }
          def initialize(name:, short: nil, long: nil, desc: nil)
            if long&.start_with?('-') || short&.start_with?('-')
              raise(ArgumentError, 'invalid - prefix')
            end

            @name = name
            @short = short
            @long = long
            @desc = desc
          end
        end

        class Position
          extend T::Sig
          include OptBase
          include OptValue

          sig do
            params(
              name: Symbol,
              desc: T.nilable(String),
              required: T::Boolean,
              multi: T::Boolean,
              default: T.any(NilClass, String, T.proc.returns(String)),
              skip: T.any(
                NilClass,
                T.proc.returns(T::Boolean),
                T.proc.params(arg0: String).returns(T::Boolean),
              ),
            ).void
          end
          def initialize(name:, desc:, required:, multi:, default: nil, skip: nil)
            if multi && (default || required)
              raise(ArgumentError, 'multi-valued positions cannot have a default or required value')
            end

            @name = name
            @desc = desc
            @required = required
            @multi = multi
            @default = default
            @skip = skip
          end

          sig { params(arg: String).returns(T::Boolean) }
          def skip?(arg)
            if @skip.nil?
              false
            elsif T.must(@skip).arity == 0
              T.cast(@skip, T.proc.returns(T::Boolean)).call
            else
              T.cast(@skip, T.proc.params(arg0: String).returns(T::Boolean)).call(arg)
            end
          end
        end

        class Option < Flag
          extend T::Sig
          include OptValue

          sig do
            params(
              name: Symbol, short: T.nilable(String), long: T.nilable(String),
              desc: T.nilable(String),
              default: T.any(
                NilClass,
                String, T.proc.returns(String),
                T::Array[String], T.proc.returns(T::Array[String])
              ),
              required: T::Boolean, multi: T::Boolean
            ).void
          end
          def initialize(name:, short: nil, long: nil, desc: nil, default: nil, required: false, multi: false)
            if multi && required
              raise(ArgumentError, 'multi-valued options cannot have a required value')
            end

            super(name: name, short: short, long: long, desc: desc)
            @default = default
            @required = required
            @multi = multi
          end
        end

        sig { params(name: Symbol).returns(T.nilable(Flag)) }
        def lookup_flag(name)
          flagopt = @by_name[name]
          if flagopt.class == Flag
            flagopt
          end
        end

        sig { params(name: Symbol).returns(T.nilable(Option)) }
        def lookup_option(name)
          flagopt = @by_name[name]
          if flagopt.class == Option
            flagopt
          end
        end

        sig { params(name: String).returns(T.any(Flag, Option, NilClass)) }
        def lookup_short(name)
          raise(InvalidLookup, "invalid '-' prefix") if name.start_with?('-')

          @by_short[name]
        end

        sig { params(name: String).returns(T.any(Flag, Option, NilClass)) }
        def lookup_long(name)
          raise(InvalidLookup, "invalid '-' prefix") if name.start_with?('-')

          @by_long[name]
        end

        sig { params(name: Symbol).returns(T.nilable(Position)) }
        def lookup_position(name)
          position = @by_name[name]
          if position.class == Position
            position
          end
        end

        private

        sig { params(position: Position).void }
        def validate_order(position)
          raise(InvalidPosition, 'Cannot have any more positional arguments after multi') if @positions.last&.multi?
        end

        sig { params(short: String).returns(String) }
        def strip_short_prefix(short)
          unless short.match?(/^-[^-]/)
            raise(InvalidFlag, "Short flag '#{short}' does not start with '-'")
          end
          if short.size != 2
            raise(InvalidFlag, 'Short flag must be a single character')
          end

          short.sub(/^-/, '')
        end

        sig { params(long: String).returns(String) }
        def strip_long_prefix(long)
          unless long.match?(/^--[^-]/)
            raise(InvalidFlag, "Long flag '#{long}' does not start with '--'")
          end

          long.sub(/^--/, '')
        end

        sig do
          params(short: T.nilable(String), long: T.nilable(String))
            .returns([T.nilable(String), T.nilable(String)])
        end
        def strip_prefixes_and_validate(short, long)
          if short.nil? && long.nil?
            raise(Error, 'One or more of short and long must be specified')
          end

          short = strip_short_prefix(short) if short
          long = strip_long_prefix(long) if long

          [short, long]
        end

        sig { params(flagopt: Flag).void }
        def add_resolution(flagopt)
          if flagopt.short
            if (existing = @by_short[flagopt.short])
              raise(ConflictingFlag, "Short flag '#{flagopt.short}' already defined by #{existing.name}")
            end

            @by_short[flagopt.short] = flagopt
          end
          if flagopt.long
            if (existing = @by_long[flagopt.long])
              raise(ConflictingFlag, "Long flag '#{flagopt.long}' already defined by #{existing.name}")
            end

            @by_long[flagopt.long] = flagopt
          end
          add_name_resolution(flagopt)
        end

        sig { params(arg: T.any(Flag, Position)).void }
        def add_name_resolution(arg)
          if (existing = @by_name[arg.name])
            raise(ConflictingFlag, "Flag '#{arg.name}' already defined by #{existing.name}")
          end

          @by_name[arg.name] = arg
        end
      end
    end
  end
end
