require 'English'

module CLI
  module Kit
    module ReportErrors
      class << self
        attr_accessor :exception
      end

      # error_reporter should support the interface:
      #  .call(
      #    notify_with, :: Exception
      #    logs,        :: String (stdout+stderr of process before crash)
      #  )
      def self.setup(logfile_path, error_reporter)
        at_exit do
          CLI::Kit::ReportErrors.call(exception || $ERROR_INFO, logfile_path, error_reporter)
        end
      end

      def self.call(error, logfile_path, error_reporter)
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
        when SystemExit  # "exit N" called
          case error.status
          when CLI::Kit::EXIT_SUCCESS  # submit nothing if it was `exit 0`
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
            File.read(logfile_path)
          rescue => e
            "(#{e.class}: #{e.message})"
          end
          error_reporter.call(notify_with, logs)
        end
      end
    end
  end
end
