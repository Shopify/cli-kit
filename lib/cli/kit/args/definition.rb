# typed: true

require 'cli/kit'

module CLI
  module Kit
    module Args
      class Definition
        Error = Class.new(Args::Error)
        ConflictingFlag = Class.new(Error)
        InvalidFlag = Class.new(Error)
        InvalidLookup = Class.new(Error)
        InvalidPosition = Class.new(Error)

        #: Array[Flag]
        attr_reader :flags

        #: Array[Option]
        attr_reader :options

        #: Array[Position]
        attr_reader :positions

        #: (Symbol name, ?short: String?, ?long: String?, ?desc: String?) -> void
        def add_flag(name, short: nil, long: nil, desc: nil)
          short, long = strip_prefixes_and_validate(short, long)
          flag = Flag.new(name: name, short: short, long: long, desc: desc)
          add_resolution(flag)
          @flags << flag
        end

        #: (Symbol name, ?short: String?, ?long: String?, ?desc: String?, ?default: (String | ^-> String | Array[String] | ^-> Array[String])?, ?required: bool, ?multi: bool) -> void
        def add_option(name, short: nil, long: nil, desc: nil, default: nil, required: false, multi: false)
          short, long = strip_prefixes_and_validate(short, long)
          option = Option.new(
            name: name, short: short, long: long, desc: desc, default: default,
            required: required, multi: multi
          )
          add_resolution(option)
          @options << option
        end

        #: (Symbol name, required: bool, multi: bool, ?desc: String?, ?default: (String | ^-> String)?, ?skip: (^-> bool | ^(String arg0) -> bool)?) -> void
        def add_position(name, required:, multi:, desc: nil, default: nil, skip: nil)
          position = Position.new(
            name: name, desc: desc, required: required, multi: multi,
            default: default, skip: skip
          )
          validate_order(position)
          add_name_resolution(position)
          @positions << position
        end

        #: -> void
        def initialize
          @flags = []
          @options = []
          @by_short = {}
          @by_long = {}
          @by_name = {}
          @positions = []
        end

        module OptBase
          #: Symbol
          attr_reader :name

          #: String?
          attr_reader :desc
        end

        module OptValue
          #: -> (String | Array[String])?
          def default
            if @default.is_a?(Proc)
              @default.call
            else
              @default
            end
          end

          #: -> bool
          def dynamic_default?
            @default.is_a?(Proc)
          end

          #: -> bool
          def required?
            @required
          end

          #: -> bool
          def multi?
            @multi
          end

          #: -> bool
          def optional?
            !required?
          end
        end

        class Flag
          include OptBase

          #: String?
          attr_reader :short

          #: String?
          attr_reader :long

          #: -> String
          def as_written_by_user
            long ? "--#{long}" : "-#{short}"
          end

          #: (name: Symbol, ?short: String?, ?long: String?, ?desc: String?) -> void
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
          include OptBase
          include OptValue

          #: (name: Symbol, desc: String?, required: bool, multi: bool, ?default: (String | ^-> String)?, ?skip: (^-> bool | ^(String arg0) -> bool)?) -> void
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

          #: (String arg) -> bool
          def skip?(arg)
            if @skip.nil?
              false
            elsif @skip.arity == 0
              prc = @skip #: as ^() -> bool
              prc.call
            else
              prc = @skip #: as ^(String) -> bool
              prc.call(arg)
            end
          end
        end

        class Option < Flag
          include OptValue

          #: (name: Symbol, ?short: String?, ?long: String?, ?desc: String?, ?default: (String | ^-> String | Array[String] | ^-> Array[String])?, ?required: bool, ?multi: bool) -> void
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

        #: (Symbol name) -> Flag?
        def lookup_flag(name)
          flagopt = @by_name[name]
          if flagopt.class == Flag
            flagopt
          end
        end

        #: (Symbol name) -> Option?
        def lookup_option(name)
          flagopt = @by_name[name]
          if flagopt.class == Option
            flagopt
          end
        end

        #: (String name) -> (Flag | Option)?
        def lookup_short(name)
          raise(InvalidLookup, "invalid '-' prefix") if name.start_with?('-')

          @by_short[name]
        end

        #: (String name) -> (Flag | Option)?
        def lookup_long(name)
          raise(InvalidLookup, "invalid '-' prefix") if name.start_with?('-')

          @by_long[name]
        end

        #: (Symbol name) -> Position?
        def lookup_position(name)
          position = @by_name[name]
          if position.class == Position
            position
          end
        end

        private

        #: (Position position) -> void
        def validate_order(position)
          raise(InvalidPosition, 'Cannot have any more positional arguments after multi') if @positions.last&.multi?
        end

        #: (String short) -> String
        def strip_short_prefix(short)
          unless short.match?(/^-[^-]/)
            raise(InvalidFlag, "Short flag '#{short}' does not start with '-'")
          end
          if short.size != 2
            raise(InvalidFlag, 'Short flag must be a single character')
          end

          short.sub(/^-/, '')
        end

        #: (String long) -> String
        def strip_long_prefix(long)
          unless long.match?(/^--[^-]/)
            raise(InvalidFlag, "Long flag '#{long}' does not start with '--'")
          end

          long.sub(/^--/, '')
        end

        #: (String? short, String? long) -> [String?, String?]
        def strip_prefixes_and_validate(short, long)
          if short.nil? && long.nil?
            raise(Error, 'One or more of short and long must be specified')
          end

          short = strip_short_prefix(short) if short
          long = strip_long_prefix(long) if long

          [short, long]
        end

        #: (Flag flagopt) -> void
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

        #: ((Flag | Position) arg) -> void
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
