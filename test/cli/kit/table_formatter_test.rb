require 'test_helper'

module CLI
  module Kit
    class TableFormatterTest < MiniTest::Test
      def setup
        @tf = TableFormatter.new(:pid, :ppid, :cmd, default: [:pid, :ppid])
        @tfs = Struct.new(:pid, :ppid, :cmd)
        @tf << @tfs.new(1, 0, 'init')
        @tf << @tfs.new(2, 1, 'nginx')
        @tf << @tfs.new(4001, 2, 'nginx-worker')
        @out = StringIO.new
      end

      def test_simple
        @tf.render(to: @out, columns: [:pid, :ppid, :cmd])

        assert_equal(<<~OUT, @out.string)
          PID   PPID  CMD
          1     0     init
          2     1     nginx
          4001  2     nginx-worker
        OUT
      end

      def test_default
        @tf.render(to: @out)

        assert_equal(<<~OUT, @out.string)
          PID   PPID
          1     0
          2     1
          4001  2
        OUT
      end

      def test_opts
        @tf.render(to: @out, columns: [:pid], header: false)

        assert_equal(<<~OUT, @out.string)
          1
          2
          4001
        OUT
      end

      def test_parse_options
        assert_empty(@tf.parse_options('-o', 'pid', '-H'))

        @tf.render(to: @out)

        assert_equal(<<~OUT, @out.string)
          1
          2
          4001
        OUT
      end

      def test_custom_parser
        myparser = OptionParser.new do |opts|
          opts.on('--other', 'whatever') { |*| }
          @tf.add_options(opts)
        end
        assert_empty(myparser.parse!(['-o', 'pid', '-H', '--other']))

        @tf.render(to: @out)

        assert_equal(<<~OUT, @out.string)
          1
          2
          4001
        OUT
      end
    end
  end
end
