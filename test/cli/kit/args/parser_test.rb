require 'test_helper'

module CLI
  module Kit
    module Args
      class ParserTest < Minitest::Test
        Token = Tokenizer::Token
        Node = Parser::Node

        def setup
          @defn = Args::Definition.new
          @defn.add_flag(:f, short: '-f', long: '--force')
          @defn.add_option(:zk, short: '-z', long: '--zookeeper')
          @defn.add_option(:height, long: '--height')
          @defn.add_option(:w, long: '--w')
        end

        def test_parse_empty
          parse = Args::Parser.new(@defn).parse([])
          assert_equal([], parse)
        end

        def test_parse_flag
          parse = Args::Parser.new(@defn).parse([
            Token::ShortOptionName.new('f'),
          ])
          assert_equal([Node::ShortFlag.new('f')], parse)

          parse = Args::Parser.new(@defn).parse([
            Token::LongOptionName.new('force'),
          ])
          assert_equal([Node::LongFlag.new('force')], parse)
        end

        def test_parse_long_option
          parse = Args::Parser.new(@defn).parse([
            Token::LongOptionName.new('zookeeper'),
            Token::OptionValueOrPositionalArgument.new('3'),
          ])
          assert_equal([Node::LongOption.new('zookeeper', '3')], parse)

          parse = Args::Parser.new(@defn).parse([
            Token::LongOptionName.new('zookeeper'),
            Token::OptionValue.new('4'),
          ])
          assert_equal([Node::LongOption.new('zookeeper', '4')], parse)

          assert_raises(Parser::OptionRequiresAnArgumentError) do
            Args::Parser.new(@defn).parse([
              Token::LongOptionName.new('zookeeper'),
              Token::PositionalArgument.new('5'),
            ])
          end
        end

        def test_parse_positional
          parse = Args::Parser.new(@defn).parse([
            Token::PositionalArgument.new('what'),
          ])
          assert_equal([Node::Argument.new('what')], parse)

          parse = Args::Parser.new(@defn).parse([
            Token::ShortOptionName.new('f'),
            Token::PositionalArgument.new('what'),
          ])
          assert_equal([Node::ShortFlag.new('f'), Node::Argument.new('what')], parse)

          parse = Args::Parser.new(@defn).parse([
            Token::ShortOptionName.new('f'),
            Token::OptionValueOrPositionalArgument.new('what'),
          ])
          assert_equal([Node::ShortFlag.new('f'), Node::Argument.new('what')], parse)
        end

        def test_unparsed
          parse = Args::Parser.new(@defn).parse([
            Token::UnparsedArgument.new('a'),
            Token::UnparsedArgument.new('b'),
          ])
          assert_equal([Node::Unparsed.new(['a', 'b'])], parse)

          parse = Args::Parser.new(@defn).parse([
            Token::ShortOptionName.new('f'),
            Token::UnparsedArgument.new('a'),
            Token::UnparsedArgument.new('b'),
          ])
          assert_equal([Node::ShortFlag.new('f'), Node::Unparsed.new(['a', 'b'])], parse)

          assert_raises(Parser::Error) do
            Args::Parser.new(@defn).parse([
              Token::UnparsedArgument.new('a'),
              Token::ShortOptionName.new('f'),
              Token::UnparsedArgument.new('b'),
            ])
          end
        end

        def test_invalid_token_type
          tok = Class.new(Token)
          assert_raises(Parser::Error) do
            Args::Parser.new(@defn).parse([tok.new('a')])
          end
          assert_raises(Parser::Error) do
            Args::Parser.new(@defn).parse([
              Token::LongOptionName.new('zookeeper'),
              tok.new('a'),
            ])
          end
        end

        def test_invalid_option_value
          assert_raises(Parser::Error) do
            Args::Parser.new(@defn).parse([
              Token::OptionValue.new('welp'),
            ])
          end
        end

        def test_missing_option
          assert_raises(Parser::InvalidOptionError) do
            Args::Parser.new(@defn).parse([
              Token::ShortOptionName.new('x'),
            ])
          end
        end

        def test_complex
          parse = Args::Parser.new(@defn).parse([
            Token::ShortOptionName.new('f'),
            Token::ShortOptionName.new('z'),
            Token::OptionValue.new('200'),
            Token::LongOptionName.new('height'),
            Token::OptionValueOrPositionalArgument.new('3'),
            Token::LongOptionName.new('w'),
            Token::OptionValue.new('4'),
            Token::PositionalArgument.new('a'),
            Token::PositionalArgument.new('b'),
            Token::PositionalArgument.new('c'),
            Token::UnparsedArgument.new('d'),
            Token::UnparsedArgument.new('--neato'),
            Token::UnparsedArgument.new('-f'),
          ])
          assert_equal(
            [
              Node::ShortFlag.new('f'),
              Node::ShortOption.new('z', '200'),
              Node::LongOption.new('height', '3'),
              Node::LongOption.new('w', '4'),
              Node::Argument.new('a'),
              Node::Argument.new('b'),
              Node::Argument.new('c'),
              Node::Unparsed.new(['d', '--neato', '-f']),
            ],
            parse,
          )
          assert_equal(
            [
              '#<CLI::Kit::Args::Parser::Node::ShortFlag f>',
              '#<CLI::Kit::Args::Parser::Node::ShortOption z=200>',
              '#<CLI::Kit::Args::Parser::Node::LongOption height=3>',
              '#<CLI::Kit::Args::Parser::Node::LongOption w=4>',
              '#<CLI::Kit::Args::Parser::Node::Argument a>',
              '#<CLI::Kit::Args::Parser::Node::Argument b>',
              '#<CLI::Kit::Args::Parser::Node::Argument c>',
              '#<CLI::Kit::Args::Parser::Node::Unparsed d --neato -f>',
            ],
            parse.map(&:inspect),
          )
        end
      end
    end
  end
end
