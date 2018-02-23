require 'test_helper'
require 'tempfile'

module CLI
  module Kit
    class ErrorHandlerTest < MiniTest::Test
      def setup
        @rep = Object.new
        @tf  = Tempfile.create('executor-log').tap(&:close)
        @eh = ErrorHandler.new(log_file: @tf.path, exception_reporter: @rep)
        class << @eh
          attr_reader :exit_handler
          # Prevent `install!` from actually installing the hook.
          def at_exit(&block)
            @exit_handler = block
          end
        end
      end

      def teardown
        File.unlink(@tf.path)
      end

      def test_success
        @rep.expects(:report).never
        out, err, code = with_handler do
          puts 'neato'
        end
        assert_equal("neato\n", out)
        assert_empty(err)
        assert_equal(CLI::Kit::EXIT_SUCCESS, code)
      end

      def test_abort_silent
        @rep.expects(:report).never
        out, err, code = with_handler do
          raise(CLI::Kit::AbortSilent)
        end
        assert_empty(out)
        assert_empty(err)
        assert_equal(CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG, code)
      end

      def test_abort
        @rep.expects(:report).never
        out, err, code = with_handler do
          raise(CLI::Kit::Abort, 'foo')
        end
        assert_empty(out)
        assert_match(/foo/, err)
        assert_equal(CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG, code)
      end

      def test_bug_silent
        @rep.expects(:report).once.with(is_a(CLI::Kit::BugSilent), 'words')
        File.write(@tf.path, 'words')
        out, err, code = with_handler do
          raise(CLI::Kit::BugSilent)
        end
        assert_empty(out)
        assert_empty(err)
        assert_equal(CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG, code)
      end

      def test_bug
        @rep.expects(:report).once.with(is_a(CLI::Kit::Bug), '')
        out, err, code = with_handler do
          raise(CLI::Kit::Bug, 'foo')
        end
        assert_empty(out)
        assert_match(/foo/, err)
        assert_equal(CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG, code)
      end

      def test_interrupt
        @rep.expects(:report).never
        out, err, code = with_handler do
          raise(Interrupt)
        end
        assert_empty(out)
        assert_match(/Interrupt/, err)
        assert_equal(CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG, code)
      end

      def test_unhandled
        @rep.expects(:report).once.with(is_a(RuntimeError), '')
        out, err, code = with_handler do
          raise 'wups'
        end
        assert_empty(out)
        assert_empty(err)
        assert_equal(:unhandled, code)
      end

      # the rest of these are hard because they kind of rely on the handler
      # actually running in at_exit.

      def test_non_bug_signal
        # e.g. SIGTERM
        skip
      end

      def test_bug_signal
        # e.g. SIGSEGV
        skip
      end

      def test_exit_0
        skip
      end

      def test_exit_30
        skip
      end

      def test_exit_1
        skip
      end


      private

      def with_handler
        code = nil
        out, err = capture_io do
          begin
            CLI::UI::StdoutRouter.with_enabled do
              code = @eh.call { yield }
            end
          rescue => e
            # This is cheating, but it's the easiest way I could think of to
            # work around not wanting to actually have to call an at_exit
            # handler with $ERROR_INFO here.
            @eh.instance_variable_set(:@exception, e)
            code = :unhandled
          ensure
            @eh.exit_handler.call
          end
        end
        [out, err, code]
      end
    end
  end
end
