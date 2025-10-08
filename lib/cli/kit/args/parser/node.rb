# typed: true

require 'cli/kit'

module CLI
  module Kit
    module Args
      class Parser
        class Node
          #: -> void
          def initialize
          end

          #: (untyped other) -> bool
          def ==(other)
            self.class == other.class
          end

          class Option < Node
            #: String
            attr_reader :name

            #: String
            attr_reader :value

            #: (String name, String value) -> void
            def initialize(name, value)
              @name = name
              @value = value
              super()
            end
            private_class_method(:new) # don't instantiate this class directly

            #: -> String
            def inspect
              "#<#{self.class.name} #{@name}=#{@value}>"
            end

            #: (untyped other) -> bool
            def ==(other)
              !!(super(other) && @value == other.value && @name == other.name)
            end
          end

          class LongOption < Option
            public_class_method(:new)
          end

          class ShortOption < Option
            public_class_method(:new)
          end

          class Flag < Node
            #: String
            attr_reader :value

            #: (String value) -> void
            def initialize(value)
              @value = value
              super()
            end
            private_class_method(:new) # don't instantiate this class directly

            #: -> String
            def inspect
              "#<#{self.class.name} #{@value}>"
            end

            #: (untyped other) -> bool
            def ==(other)
              !!(super(other) && @value == other.value)
            end
          end

          class LongFlag < Flag
            public_class_method(:new)
          end

          class ShortFlag < Flag
            public_class_method(:new)
          end

          class Argument < Node
            #: String
            attr_reader :value

            #: (String value) -> void
            def initialize(value)
              @value = value
              super()
            end

            #: -> String
            def inspect
              "#<#{self.class.name} #{@value}>"
            end

            #: (untyped other) -> bool
            def ==(other)
              !!(super(other) && @value == other.value)
            end
          end

          class Unparsed < Node
            #: Array[String]
            attr_reader :value

            #: (Array[String] value) -> void
            def initialize(value)
              @value = value
              super()
            end

            #: -> String
            def inspect
              "#<#{self.class.name} #{@value.join(" ")}>"
            end

            #: (untyped other) -> bool
            def ==(other)
              !!(super(other) && @value == other.value)
            end
          end
        end
      end
    end
  end
end
