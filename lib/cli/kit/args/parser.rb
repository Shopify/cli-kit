# typed: true

require 'cli/kit'

module CLI
  module Kit
    module Args
      class Parser
        extend T::Sig

        autoload :Node, 'cli/kit/args/parser/node'

        Error = Class.new(Args::Error)

        class InvalidOptionError < Error
          extend T::Sig
          sig { params(option: String).void }
          def initialize(option)
            super("invalid option -- '#{option}'")
          end
        end

        class OptionRequiresAnArgumentError < Error
          extend T::Sig
          sig { params(option: String).void }
          def initialize(option)
            super("option requires an argument -- '#{option}'")
          end
        end

        sig { params(tokens: T::Array[Tokenizer::Token]).returns(T::Array[Node]) }
        def parse(tokens)
          nodes = T.let([], T::Array[Node])
          args = T.let(tokens, T::Array[T.nilable(Tokenizer::Token)])
          args << nil # to make each_cons pass (args.last, nil) on the final round.
          state = :init
          # TODO: test that "--height -- 3" is parsed correctly.
          args.each_cons(2) do |(arg, next_arg)|
            case state
            when :skip
              state = :init
            when :init
              state, val = parse_token(T.must(arg), next_arg)
              nodes << val
            when :unparsed
              unless arg.is_a?(Tokenizer::Token::UnparsedArgument)
                raise(Error, 'bug: non-unparsed argument after unparsed argument')
              end

              unparsed = nodes.last
              unless unparsed.is_a?(Node::Unparsed)
                # :nocov: not actually possible, in theory
                raise(Error, 'bug: parser failed to recognize first unparsed argument')
                # :nocov:
              end

              unparsed.value << arg.value
            end
          end
          nodes
        end

        sig { params(definition: Definition).void }
        def initialize(definition)
          @defn = definition
        end

        private

        sig do
          params(token: Tokenizer::Token, next_token: T.nilable(Tokenizer::Token))
            .returns([Symbol, Parser::Node])
        end
        def parse_token(token, next_token)
          case token
          when Tokenizer::Token::LongOptionName
            case @defn.lookup_long(token.value)
            when Definition::Option
              [:skip, parse_option(token, next_token)]
            when Definition::Flag
              [:init, Node::LongFlag.new(token.value)]
            else
              raise(InvalidOptionError, token.value)
            end
          when Tokenizer::Token::ShortOptionName
            case @defn.lookup_short(token.value)
            when Definition::Option
              [:skip, parse_option(token, next_token)]
            when Definition::Flag
              [:init, Node::ShortFlag.new(token.value)]
            else
              raise(InvalidOptionError, token.value)
            end
          when Tokenizer::Token::OptionValue
            raise(Error, "bug: unexpected option value in argument parse sequence: #{token.value}")
          when Tokenizer::Token::PositionalArgument
            [:init, Node::Argument.new(token.value)]
          when Tokenizer::Token::OptionValueOrPositionalArgument
            [:init, Node::Argument.new(token.value)]
          when Tokenizer::Token::UnparsedArgument
            [:unparsed, Node::Unparsed.new([token.value])]
          else
            raise(Error, "bug: unexpected token type: #{token.class}")
          end
        end

        sig { params(arg: Tokenizer::Token::OptionName, next_arg: T.nilable(Tokenizer::Token)).returns(Node) }
        def parse_option(arg, next_arg)
          case next_arg
          when nil, Tokenizer::Token::LongOptionName,
            Tokenizer::Token::ShortOptionName, Tokenizer::Token::PositionalArgument
            raise(OptionRequiresAnArgumentError, arg.value)
          when Tokenizer::Token::OptionValue, Tokenizer::Token::OptionValueOrPositionalArgument
            case arg
            when Tokenizer::Token::LongOptionName
              Node::LongOption.new(arg.value, next_arg.value)
            when Tokenizer::Token::ShortOptionName
              Node::ShortOption.new(arg.value, next_arg.value)
            else
              raise(Error, "bug: unexpected token type: #{arg.class}")
            end
          else
            raise(Error, "bug: unexpected argument type: #{next_arg.class}")
          end
        end
      end
    end
  end
end
