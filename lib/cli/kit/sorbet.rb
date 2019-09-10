# typed: ignore

unless defined?(T)
  module T
    class << self
      def any(type_a, type_b, *types)
      end

      def nilable(type)
      end

      def untyped
      end

      def noreturn
      end

      def all(type_a, type_b, *types)
      end

      def enum(values)
      end

      def proc
      end

      def self_type
      end

      def class_of(klass)
      end

      def type_alias(type)
      end

      def type_parameter(name)
      end

      def cast(value, _type, _checked: true)
        value
      end

      def let(value, _type, _checked: true)
        value
      end

      def assert_type!(value, _type, _checked: true)
        value
      end

      def unsafe(value)
        value
      end

      def must(arg, _msg = nil)
        arg
      end

      def reveal_type(value)
        value
      end
    end
  end

  module T
    module Helpers
      def interface!
      end

      def abstract!
      end
    end

    module Sig
      def sig(&blk)
      end
    end

    module Array
      def self.[](type)
      end
    end

    module Hash
      def self.[](keys, values)
      end
    end

    module Enumerable
      def self.[](type)
      end
    end

    module Range
      def self.[](type)
      end
    end

    module Set
      def self.[](type)
      end
    end

    module Boolean
    end
  end
end
