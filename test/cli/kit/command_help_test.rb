require 'test_helper'

module CLI
  module Kit
    class CommandHelpTest < Minitest::Test
      def setup
        CLI::Kit::CommandHelp.tool_name = 'test'
      end

      class ACommand < CLI::Kit::BaseCommand
        command_name('a-command')
        desc('do a thing')
        long_desc(<<~LONGDESC)
          This is a long description.
          It spans multiple lines.
        LONGDESC

        usage('[-q|-l] [-u] {{yellow:<word>}}')

        example('-q -u neato', "quietly do a thing with 'neato'")

        class BaseOpts < CLI::Kit::Opts
          class << self
            def inherited(subclass)
              super
              subclass.class_eval do
                def dry_run
                  flag(short: '-d', desc: 'dry run')
                end
              end
            end
          end
        end

        class Opts < BaseOpts
          def quiet
            flag(short: '-q', desc: 'be quiet')
          end

          def loud
            flag(short: '-l', long: '--loud', desc: 'be loud')
          end

          def undescribed
            flag(short: '-u')
          end
        end
      end

      def test_a
        assert_equal(<<~EXPECTED, ACommand.build_help)
          \e[0;1;36mtest a-command\e[0;1m: do a thing\e[0m

          This is a long description.
          It spans multiple lines.

          \e[0;1mUsage:\e[0m \e[0;36mtest a-command\e[0m [-q|-l] [-u] \e[0;33m<word>\e[0m

          \e[0;1mExamples:\e[0m
            \e[0;36mtest a-command\e[0m -q -u neato  \e[0;3;38;5;244m# quietly do a thing with 'neato'\e[0m

          \e[0;1mOptions:\e[0m
            -d  \e[0;3;38;5;244m# dry run\e[0m
            -h, --help  \e[0;3;38;5;244m# Show this help message\e[0m
            -l, --loud  \e[0;3;38;5;244m# be loud\e[0m
            -q  \e[0;3;38;5;244m# be quiet\e[0m
            -u
        EXPECTED
      end

      class BCommand < CLI::Kit::BaseCommand
        # infer command name
        # no desc, long_desc, examples, opts/flags, or usage
        Opts = Class.new(CLI::Kit::Opts)
      end

      def test_b
        assert_equal(<<~EXPECTED, BCommand.build_help)
          \e[0;1;36mtest bcommand\e[0m

          \e[0;1mUsage:\e[0m \e[0;36mtest bcommand\e[0m [options]

          \e[0;1mOptions:\e[0m
            -h, --help  \e[0;3;38;5;244m# Show this help message\e[0m
        EXPECTED
      end

      def test_80_cap_on_desc
        Class.new(CLI::Kit::BaseCommand) do
          desc('a' * 80)
        end
        assert_raises do
          Class.new(CLI::Kit::BaseCommand) do
            desc('a' * 81)
          end
        end
        # custom max length
        CLI::Kit::CommandHelp.max_desc_length = 85
        Class.new(CLI::Kit::BaseCommand) do
          desc('b' * 85)
        end
        assert_raises(ArgumentError, 'description must be 85 characters or less') do
          Class.new(CLI::Kit::BaseCommand) do
            desc('b' * 86)
          end
        end
      end

      class DoSomething < CLI::Kit::BaseCommand
        desc('run a thing with no options')

        usage('a')
        usage('b')

        example('something', 'this exceeds the terminal width, which is stubbed as 50')
        example('something2', 'this does not')
      end

      def test_c
        CLI::UI::Terminal.expects(:width).times(2).returns(50)

        assert_equal(<<~EXPECTED, DoSomething.build_help)
          \e[0;1;36mtest do-something\e[0;1m: run a thing with no options\e[0m

          \e[0;1mUsage:\e[0m
            \e[0;36mtest do-something\e[0m a
            \e[0;36mtest do-something\e[0m b

          \e[0;1mExamples:\e[0m
            \e[0;3;38;5;244m# this exceeds the terminal width, which is stubbed as 50\e[0m
            \e[0;36mtest do-something\e[0m something

            \e[0;36mtest do-something\e[0m something2  \e[0;3;38;5;244m# this does not\e[0m

          \e[0;1mOptions:\e[0m
            -h, --help  \e[0;3;38;5;244m# Show this help message\e[0m
        EXPECTED
      end

      def test_invoke_call_not_defined
        assert_raises(NotImplementedError) do
          BCommand.new.call([], 'b')
        end
        out, err = capture_io { BCommand.new.call(['-h'], 'b') }
        assert_equal('', err)
        assert_equal(<<~EXPECTED, out)
          \e[0;1;36mtest bcommand\e[0m

          \e[0;1mUsage:\e[0m \e[0;36mtest bcommand\e[0m [options]

          \e[0;1mOptions:\e[0m
            -h, --help  \e[0;3;38;5;244m# Show this help message\e[0m
        EXPECTED
      end

      def test_already_set
        fails = ->(&blk) { assert_raises(ArgumentError, &blk) }

        Class.new(CLI::Kit::BaseCommand) do
          command_name('a-command')
          fails.call { command_name('b-command') }
        end

        Class.new(CLI::Kit::BaseCommand) do
          desc('a')
          fails.call { desc('b') }
        end

        Class.new(CLI::Kit::BaseCommand) do
          long_desc('a')
          fails.call { long_desc('b') }
        end
      end
    end
  end
end
