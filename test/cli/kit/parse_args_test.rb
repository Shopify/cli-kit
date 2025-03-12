# typed: ignore

require('cli/kit')
require('test_helper')

module CLI
  module Kit
    class ParseArgsTest < Minitest::Test
      # not a real command, just something to show the use of parse_args
      class Command
        include CLI::Kit::ParseArgs

        OPTS = {
          maybe: [false, 'on/off', '-m'],
          choice: [nil, 'will not be set by default', '-i'],
          count: [nil, 'a count', '-c N', Integer],
          sum: [11, 'a sum', '-s N', Integer],
          val: [nil, 'a val', '-v VAL'],
          str: ['foo', 'a string', '-x STR'],
          opt: [['init_val', 'def_val'], 'a default', '-o [OPT]'],
          snake_squad_alpha: ['snakes', 'snake magic', '-k SNAKE_SQUAD'],
        }

        attr_reader(:args)

        def call(args)
          @args = parse_args(args, OPTS)
        end

        def call_no_opts(args)
          @args = parse_args(args)
        end
      end

      def setup
        @cmd = Command.new
      end

      def test_positional
        @cmd.call('  alpha   beta  gamma       ')
        assert_equal(['alpha', 'beta', 'gamma'], @cmd.args[:sub])

        @cmd.call('alpha 1')
        assert_equal(['alpha', '1'], @cmd.args[:sub])
      end

      def test_options_default
        @cmd.call('')
        assert_equal(
          { maybe: false, sum: 11, str: 'foo', opt: 'init_val', snake_squad_alpha: 'snakes' },
          @cmd.args[:opts],
        )
      end

      def test_no_opts
        @cmd.call_no_opts('one two')
        assert_equal(
          {
            opts: {},
            sub: ['one', 'two'],
          },
          @cmd.args,
        )
      end

      def test_array_args
        @cmd.call('-m -i -c 100 -s 111 -v bar -x baz -o other_val -k cobras'.split(/\s/))
        assert_equal(
          {
            maybe: true,
            choice: true,
            count: 100,
            sum: 111,
            val: 'bar',
            str: 'baz',
            opt: 'other_val',
            snake_squad_alpha: 'cobras',
          },
          @cmd.args[:opts],
        )
      end

      def test_options_short
        @cmd.call('-m -i -c 100 -s 111 -v bar -x baz -o other_val -k cobras')
        assert_equal(
          {
            maybe: true,
            choice: true,
            count: 100,
            sum: 111,
            val: 'bar',
            str: 'baz',
            opt: 'other_val',
            snake_squad_alpha: 'cobras',
          },
          @cmd.args[:opts],
        )

        # assume the default value for '-o'
        @cmd.call('-m -i -c 100 -s 111 -v bar -x baz -o -k cobras')
        assert_equal(
          {
            maybe: true,
            choice: true,
            count: 100,
            sum: 111,
            val: 'bar',
            str: 'baz',
            opt: 'def_val',
            snake_squad_alpha: 'cobras',
          },
          @cmd.args[:opts],
        )
      end

      def test_options_long
        @cmd.call(
          '--maybe --choice --count 100 --sum 111 --val bar --str baz --opt other_val --snake-squad-alpha cobras',
        )
        assert_equal(
          {
            maybe: true,
            choice: true,
            count: 100,
            sum: 111,
            val: 'bar',
            str: 'baz',
            opt: 'other_val',
            snake_squad_alpha: 'cobras',
          },
          @cmd.args[:opts],
        )
      end

      def test_options_multi
        # rubocop:disable Layout/LineLength
        @cmd.call(
          '--maybe --choice --count 100 --sum 111 --val bar --str baz --opt other_val --snake-squad-alpha cobras --count 200 --opt france --opt',
        )
        # rubocop:enable Layout/LineLength
        assert_equal(
          {
            maybe: true,
            choice: true,
            count: [100, 200],
            sum: 111,
            val: 'bar',
            str: 'baz',
            opt: ['other_val', 'france', 'def_val'],
            snake_squad_alpha: 'cobras',
          },
          @cmd.args[:opts],
        )
      end
    end
  end
end
