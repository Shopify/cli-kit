require 'test_helper'

module CLI
  module Kit
    module Args
      class TokenizerTest < Minitest::Test
        Token = Tokenizer::Token

        def test_simple
          check('-a', [Token::ShortOptionName.new('a')])
          check('--b', [Token::LongOptionName.new('b')])
          check('c', [Token::PositionalArgument.new('c')])
          check('-', [Token::PositionalArgument.new('-')])
          assert_raises(Tokenizer::InvalidCharInShortOption) { Tokenizer.tokenize(['-@']) }
        end

        def test_compacted_short_options
          check('-ab', [
            Token::ShortOptionName.new('a'),
            Token::ShortOptionName.new('b'),
          ])
          check('-ab211', [
            Token::ShortOptionName.new('a'),
            Token::ShortOptionName.new('b'),
            Token::OptionValue.new('211'),
          ])
          check('-ab 211', [
            Token::ShortOptionName.new('a'),
            Token::ShortOptionName.new('b'),
            Token::OptionValueOrPositionalArgument.new('211'),
          ])
          assert_raises(Tokenizer::InvalidShortOption) { Tokenizer.tokenize(['-ab2c']) }
          assert_raises(Tokenizer::InvalidCharInShortOption) { Tokenizer.tokenize(['-ab@']) }
        end

        def test_long
          check('--height 3', [
            Token::LongOptionName.new('height'),
            Token::OptionValueOrPositionalArgument.new('3'),
          ])
          check('--height=3', [
            Token::LongOptionName.new('height'),
            Token::OptionValue.new('3'),
          ])
        end

        def test_unparsed
          check('-- b c', [
            Token::UnparsedArgument.new('b'),
            Token::UnparsedArgument.new('c'),
          ])
          check('-a -- b c', [
            Token::ShortOptionName.new('a'),
            Token::UnparsedArgument.new('b'),
            Token::UnparsedArgument.new('c'),
          ])
          check('-- -a --b', [
            Token::UnparsedArgument.new('-a'),
            Token::UnparsedArgument.new('--b'),
          ])
        end

        def test_complex
          check('-fz200 --height 3 --w=4 a b c -- d --neato -f', [
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
        end

        def test_inspect
          tokens = Tokenizer.tokenize(['-f'])
          assert_equal(
            ['#<CLI::Kit::Args::Tokenizer::Token::ShortOptionName f>'],
            tokens.map(&:inspect),
          )
        end

        def test_errors
          e = Tokenizer::InvalidShortOption.new('abc')
          assert_equal("invalid short option: '-abc'", e.message)

          e = Tokenizer::InvalidCharInShortOption.new('ab@', '@')
          assert_equal("invalid character '@' in short option: '-ab@'", e.message)
        end

        private

        def check(str, exp)
          act = Tokenizer.tokenize(str.split(' '))
          assert_equal(exp, act)
        end
      end
    end
  end
end
