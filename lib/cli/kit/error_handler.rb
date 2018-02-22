require 'cli/kit'
require 'English'

module CLI
  module Kit
    class ErrorHandler
      def initialize(log_file:, exception_reporter:)
        @log_file = log_file
        @exception_reporter_or_proc = exception_reporter || NullExceptionReporter
      end

      module NullExceptionReporter
        def self.report(_exception, _logs)
          nil
        end
      end

      def call(&block)
        install!
        handle_abort(&block)
      end

      private

      def install!
        at_exit { handle_final_exception(@exception || $ERROR_INFO) }
      end

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
        STDERR.puts(format_error_message("Interrupt"))
        return CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG
      end

      def handle_final_exception(error)
        notify_with = nil

        case error
        when nil         # normal, non-error termination
        when Interrupt   # ctrl-c
        when CLI::Kit::Abort, CLI::Kit::AbortSilent # Not a bug
        when SignalException
          skip = %w(SIGTERM SIGHUP SIGINT)
          unless skip.include?(error.message)
            notify_with = error
          end
        when SystemExit # "exit N" called
          case error.status
          when CLI::Kit::EXIT_SUCCESS # submit nothing if it was `exit 0`
          when CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG
            # if it was `exit 30`, translate the exit code to 1, and submit nothing
            # 30 is used to signal normal failures that are not indicative of bugs.
            # But users should see it presented as 1.
            exit 1
          else
            # A weird termination status happened. `error.exception "message"` will maintain backtrace
            # but allow us to set a message
            notify_with = error.exception "abnormal termination status: #{error.status}"
          end
        else
          notify_with = error
        end

        if notify_with
          logs = begin
            File.read(@log_file)
          rescue => e
            "(#{e.class}: #{e.message})"
          end
          exception_reporter.report(notify_with, logs)
        end
      end

      def exception_reporter
        if @exception_reporter_or_proc.respond_to?(:report)
          @exception_reporter_or_proc
        else
          @exception_reporter_or_proc.call
        end
      end

      def format_error_message(msg)
        CLI::UI.fmt("{{red:#{msg}}}")
      end

      def print_error_message(e)
        STDERR.puts(format_error_message(e.message))
      end
    end
  end
end
