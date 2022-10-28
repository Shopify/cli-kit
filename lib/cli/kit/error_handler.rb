# typed: true

require 'cli/kit'
require 'English'

module CLI
  module Kit
    class ErrorHandler
      extend T::Sig

      ExceptionReporterOrProc = T.type_alias do
        T.any(T.class_of(ExceptionReporter), T.proc.returns(T.class_of(ExceptionReporter)))
      end

      sig { params(override_exception_handler: T.proc.params(arg0: Exception).returns(Integer)).void }
      attr_writer :override_exception_handler

      sig do
        params(
          log_file: T.nilable(String),
          exception_reporter: ExceptionReporterOrProc,
          tool_name: T.nilable(String),
          dev_mode: T::Boolean,
        ).void
      end
      def initialize(log_file: nil, exception_reporter: NullExceptionReporter, tool_name: nil, dev_mode: false)
        @log_file = log_file
        @exception_reporter_or_proc = exception_reporter
        @tool_name = tool_name
        @dev_mode = dev_mode
      end

      class ExceptionReporter
        extend T::Sig
        extend T::Helpers
        abstract!

        class << self
          extend T::Sig

          sig { abstract.params(exception: T.nilable(Exception), logs: T.nilable(String)).void }
          def report(exception, logs = nil); end
        end
      end

      class NullExceptionReporter < ExceptionReporter
        extend T::Sig

        class << self
          extend T::Sig

          sig { override.params(_exception: T.nilable(Exception), _logs: T.nilable(String)).void }
          def report(_exception, _logs = nil)
            nil
          end
        end
      end

      sig { params(block: T.proc.void).returns(Integer) }
      def call(&block)
        # @at_exit_exception is set if handle_abort decides to submit an error.
        # $ERROR_INFO is set if we terminate because of a signal.
        at_exit { report_exception(@at_exit_exception || $ERROR_INFO) }
        triage_all_exceptions(&block)
      end

      sig { params(error: T.nilable(Exception)).void }
      def report_exception(error)
        if (notify_with = exception_for_submission(error))
          logs = nil
          if @log_file
            logs = begin
              File.read(@log_file)
            rescue => e
              "(#{e.class}: #{e.message})"
            end
          end
          exception_reporter.report(notify_with, logs)
        end
      end

      SIGNALS_THAT_ARENT_BUGS = [
        'SIGTERM', 'SIGHUP', 'SIGINT',
      ].freeze

      private

      # Run the program, handling any errors that occur.
      #
      # Errors are printed to stderr unless they're #silent?, and are reported
      # to bugsnag (by setting @at_exit_exeption for our at_exit handler) if
      # they're #bug?
      #
      # Returns an exit status for the program.
      sig { params(block: T.proc.void).returns(Integer) }
      def triage_all_exceptions(&block)
        begin
          block.call
          CLI::Kit::EXIT_SUCCESS
        rescue Interrupt => e # Ctrl-C
          # transform message, prevent bugsnag
          exc = e.exception('Interrupt')
          CLI::Kit.raise(exc, bug: false)
        rescue Errno::ENOSPC => e
          # transform message, prevent bugsnag
          message = if @tool_name
            "Your disk is full - {{command:#{@tool_name}}} requires free space to operate"
          else
            'Your disk is full - free space is required to operate'
          end
          exc = e.exception(message)
          CLI::Kit.raise(exc, bug: false)
        end
      # If SystemExit was raised, e.g. `exit()`, then
      # return whatever status is attached to the exception
      # object. The special exit statuses have already been
      # handled below.
      rescue SystemExit => e
        e.status
      rescue Exception => e # rubocop:disable Lint/RescueException
        @at_exit_exception = e if e.bug?

        if (eh = @override_exception_handler)
          return eh.call(e)
        end

        raise(e) if @dev_mode && e.bug?

        stderr_puts(e.message) unless e.silent?
        e.bug? ? CLI::Kit::EXIT_BUG : CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG
      end

      sig { params(error: T.nilable(Exception)).returns(T.nilable(Exception)) }
      def exception_for_submission(error)
        # happens on normal non-error termination
        return(nil) if error.nil?

        return(nil) unless error.bug?

        case error
        when SignalException
          SIGNALS_THAT_ARENT_BUGS.include?(error.message) ? nil : error
        when SystemExit # "exit N" called
          case error.status
          when CLI::Kit::EXIT_SUCCESS # submit nothing if it was `exit 0`
            nil
          when CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG
            # if it was `exit 30`, translate the exit code to 1, and submit
            # nothing. 30 is used to signal normal failures that are not
            # indicative of bugs. However, users should see it presented as 1.
            exit(1)
          else
            # don't treat this as an exception, simply reraise.
            # this is indicative of `exit` being called with a
            # non-zero number, and the requested exit status
            # needs to be maintained.
            exit(error.status)
          end
        else
          error
        end
      end

      sig { params(message: String).void }
      def stderr_puts(message)
        $stderr.puts(CLI::UI.fmt("{{red:#{message}}}"))
      rescue Errno::EPIPE, Errno::EIO
        nil
      end

      sig { returns(T.class_of(ExceptionReporter)) }
      def exception_reporter
        case @exception_reporter_or_proc
        when Proc
          @exception_reporter_or_proc.call
        else
          @exception_reporter_or_proc
        end
      end
    end
  end
end
