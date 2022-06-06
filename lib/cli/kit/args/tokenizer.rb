# typed: true

require 'cli/kit'

module CLI
  module Kit
    module Args
      module Tokenizer
        extend T::Sig

        Error = Class.new(Args::Error)

        class InvalidShortOption < Error
          extend T::Sig
          sig { params(short_option: String).void }
          def initialize(short_option)
            super("invalid short option: '-#{short_option}'")
          end
        end

        class InvalidCharInShortOption < Error
          extend T::Sig
          sig { params(short_option: String, char: String).void }
          def initialize(short_option, char)
            super("invalid character '#{char}' in short option: '-#{short_option}'")
          end
        end

        class Token
          extend T::Sig

          sig { returns(String) }
          attr_reader :value

          sig { params(value: String).void }
          def initialize(value)
            @value = value
          end

          sig { returns(String) }
          def inspect
            "#<#{self.class.name} #{@value}>"
          end

          sig { params(other: T.untyped).returns(T::Boolean) }
          def ==(other)
            self.class == other.class && @value == other.value
          end

          OptionName = Class.new(Token)
          LongOptionName = Class.new(OptionName)
          ShortOptionName = Class.new(OptionName)

          OptionValue = Class.new(Token)
          PositionalArgument = Class.new(Token)
          OptionValueOrPositionalArgument = Class.new(Token)
          UnparsedArgument = Class.new(Token)
        end

        class << self
          extend T::Sig

          sig { params(raw_args: T::Array[String]).returns(T::Array[Token]) }
          def tokenize(raw_args)
            args = []

            mode = :init

            raw_args.each do |arg|
              case mode
              when :unparsed
                args << Token::UnparsedArgument.new(arg)
              when :init
                case arg
                when '--'
                  mode = :unparsed
                when /\A--./
                  name, value = arg.split('=', 2)
                  args << Token::LongOptionName.new(T.must(T.must(name)[2..-1]))
                  if value
                    args << Token::OptionValue.new(value)
                  end
                when /\A-./
                  args.concat(tokenize_short_option(T.must(arg[1..-1])))
                else
                  args << if args.last.is_a?(Token::OptionName)
                    Token::OptionValueOrPositionalArgument.new(arg)
                  else
                    Token::PositionalArgument.new(arg)
                  end
                end
              end
            end

            args
          end

          sig { params(arg: String).returns(T::Array[Token]) }
          def tokenize_short_option(arg)
            args = []
            mode = :init
            number = +''
            arg.each_char do |char|
              case mode
              when :numeric
                case char
                when /[0-9]/
                  number << char
                else
                  raise(InvalidShortOption, arg)
                end
              when :init
                case char
                when /[a-zA-Z]/
                  args << Token::ShortOptionName.new(char)
                when /[0-9]/
                  mode = :numeric
                  number << char
                else
                  raise(InvalidCharInShortOption.new(arg, char))
                end
              end
            end
            if number != ''
              args << Token::OptionValue.new(number)
            end
            args
          end
        end
      end
    end
  end
end
