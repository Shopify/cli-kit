# typed: true

require 'cli/kit'

module CLI
  module Kit
    module Args
      module Tokenizer
        Error = Class.new(Args::Error)

        class InvalidShortOption < Error
          #: (String short_option) -> void
          def initialize(short_option)
            super("invalid short option: '-#{short_option}'")
          end
        end

        class InvalidCharInShortOption < Error
          #: (String short_option, String char) -> void
          def initialize(short_option, char)
            super("invalid character '#{char}' in short option: '-#{short_option}'")
          end
        end

        class Token
          #: String
          attr_reader :value

          #: (String value) -> void
          def initialize(value)
            @value = value
          end

          #: -> String
          def inspect
            "#<#{self.class.name} #{@value}>"
          end

          #: (untyped other) -> bool
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
          #: (Array[String] raw_args) -> Array[Token]
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
                  name = name #: as !nil
                  args << Token::LongOptionName.new(
                    name[2..-1], #: as !nil
                  )
                  if value
                    args << Token::OptionValue.new(value)
                  end
                when /\A-./
                  args.concat(tokenize_short_option(
                    arg[1..-1], #: as !nil
                  ))
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

          #: (String arg) -> Array[Token]
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
