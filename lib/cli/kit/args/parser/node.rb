# typed: true

require 'cli/kit'

module CLI
  module Kit
    module Args
      class Parser
        class Node
          extend T::Sig

          sig { void }
          def initialize
          end

          sig { params(other: T.untyped).returns(T::Boolean) }
          def ==(other)
            self.class == other.class
          end

          class Option < Node
            extend T::Sig

            sig { returns(String) }
            attr_reader :name

            sig { returns(String) }
            attr_reader :value

            sig { params(name: String, value: String).void }
            def initialize(name, value)
              @name = name
              @value = value
              super()
            end
            private_class_method(:new) # don't instantiate this class directly

            sig { returns(String) }
            def inspect
              "#<#{self.class.name} #{@name}=#{@value}>"
            end

            sig { params(other: T.untyped).returns(T::Boolean) }
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
            sig { returns(String) }
            attr_reader :value

            sig { params(value: String).void }
            def initialize(value)
              @value = value
              super()
            end
            private_class_method(:new) # don't instantiate this class directly

            sig { returns(String) }
            def inspect
              "#<#{self.class.name} #{@value}>"
            end

            sig { params(other: T.untyped).returns(T::Boolean) }
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
            sig { returns(String) }
            attr_reader :value

            sig { params(value: String).void }
            def initialize(value)
              @value = value
              super()
            end

            sig { returns(String) }
            def inspect
              "#<#{self.class.name} #{@value}>"
            end

            sig { params(other: T.untyped).returns(T::Boolean) }
            def ==(other)
              !!(super(other) && @value == other.value)
            end
          end

          class Unparsed < Node
            sig { returns(T::Array[String]) }
            attr_reader :value

            sig { params(value: T::Array[String]).void }
            def initialize(value)
              @value = value
              super()
            end

            sig { returns(String) }
            def inspect
              "#<#{self.class.name} #{@value.join(" ")}>"
            end

            sig { params(other: T.untyped).returns(T::Boolean) }
            def ==(other)
              !!(super(other) && @value == other.value)
            end
          end
        end
      end
    end
  end
end
