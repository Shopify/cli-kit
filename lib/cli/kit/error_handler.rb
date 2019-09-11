# typed: true
require 'cli/kit'
require 'English'

module CLI
  module Kit
    class ErrorHandler
      extend(T::Sig)

      sig do
        params(
          log_file: String,
          exception_reporter: T.untyped,
          tool_name: T.nilable(String),
        ).void
      end
      def initialize(log_file:, exception_reporter:, tool_name: nil)
        @log_file = log_file
        @exception_reporter_or_proc = exception_reporter || NullExceptionReporter
        @tool_name = tool_name
      end

      module NullExceptionReporter
        extend(T::Sig)

        sig { params(_exception: Exception, _logs: String).void }
        def self.report(_exception, _logs)
          nil
        end
      end

      sig { params(block: T.proc.returns(T.untyped)).returns(Integer) }
      def call(&block)
        install!
        handle_abort(&block)
      end

      sig { params(error: T.untyped).void }
      def handle_exception(error)
        if (notify_with = exception_for_submission(error))
          logs = begin
            File.read(@log_file)
          rescue => e
            "(#{e.class}: #{e.message})"
          end
          exception_reporter.report(notify_with, logs)
        end
      end

      # maybe we can get rid of this.
      sig { params(exception: Exception).void }
      attr_writer :exception

      private

      sig { params(error: T.nilable(Exception)).returns(T.nilable(Exception)) }
      def exception_for_submission(error)
        case error
        when nil         # normal, non-error termination
          nil
        when Interrupt   # ctrl-c
          nil
        when CLI::Kit::Abort, CLI::Kit::AbortSilent # Not a bug
          nil
        when SignalException
          skip = %w(SIGTERM SIGHUP SIGINT)
          skip.include?(error.message) ? nil : error
        when SystemExit # "exit N" called
          case error.status
          when CLI::Kit::EXIT_SUCCESS # submit nothing if it was `exit 0`
            nil
          when CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG
            # if it was `exit 30`, translate the exit code to 1, and submit nothing.
            # 30 is used to signal normal failures that are not indicative of bugs.
            # However, users should see it presented as 1.
            exit 1
          else
            # A weird termination status happened. `error.exception "message"` will maintain backtrace
            # but allow us to set a message
            error.exception("abnormal termination status: #{error.status}")
          end
        else
          error
        end
      end

      sig { void }
      def install!
        at_exit { handle_exception(@exception || $ERROR_INFO) }
      end

      sig { returns(Integer) }
      def handle_abort
        yield
        CLI::Kit::EXIT_SUCCESS
      rescue CLI::Kit::GenericAbort => e
        is_bug    = e.is_a?(CLI::Kit::Bug) || e.is_a?(CLI::Kit::BugSilent)
        is_silent = e.is_a?(CLI::Kit::AbortSilent) || e.is_a?(CLI::Kit::BugSilent)

        print_error_message(e) unless is_silent
        (@exception = e) if is_bug

        CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG
      rescue Interrupt
        stderr_puts_message('Interrupt')
        CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG
      rescue Errno::ENOSPC
        message = if @tool_name
          "Your disk is full - {{command:#{@tool_name}}} requires free space to operate"
        else
          "Your disk is full - free space is required to operate"
        end
        stderr_puts_message(message)
        CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG
      end

      sig { params(message: String).void }
      def stderr_puts_message(message)
        $stderr.puts(format_error_message(message))
      rescue Errno::EPIPE
        nil
      end

      sig { returns(T.untyped) }
      def exception_reporter
        if @exception_reporter_or_proc.respond_to?(:report)
          @exception_reporter_or_proc
        else
          @exception_reporter_or_proc.call
        end
      end

      sig { params(msg: String).returns(String) }
      def format_error_message(msg)
        CLI::UI.fmt("{{red:#{msg}}}")
      end

      sig { params(e: Exception).void }
      def print_error_message(e)
        $stderr.puts(format_error_message(e.message))
      end
    end
  end
end
