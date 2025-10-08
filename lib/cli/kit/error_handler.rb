# typed: true

require 'cli/kit'
require 'English'

module CLI
  module Kit
    class ErrorHandler
      #: type exception_reporter_or_proc = singleton(ExceptionReporter) | ^() -> singleton(ExceptionReporter)

      #: ^(Exception arg0) -> Integer
      attr_writer :override_exception_handler

      #: (?log_file: String?, ?exception_reporter: exception_reporter_or_proc, ?tool_name: String?, ?dev_mode: bool) -> void
      def initialize(log_file: nil, exception_reporter: NullExceptionReporter, tool_name: nil, dev_mode: false)
        @log_file = log_file
        @exception_reporter_or_proc = exception_reporter
        @tool_name = tool_name
        @dev_mode = dev_mode
      end

      # @abstract
      class ExceptionReporter
        class << self
          # @abstract
          #: (Exception?, ?String?) -> void
          def report(exception, logs = nil)
            raise(NotImplementedError)
          end
        end
      end

      class NullExceptionReporter < ExceptionReporter
        class << self
          # @override
          #: (Exception? _exception, ?String? _logs) -> void
          def report(_exception, _logs = nil)
            nil
          end
        end
      end

      #: { -> void } -> Integer
      def call(&block)
        # @at_exit_exception is set if handle_abort decides to submit an error.
        # $ERROR_INFO is set if we terminate because of a signal.
        at_exit { report_exception(@at_exit_exception || $ERROR_INFO) }
        triage_all_exceptions(&block)
      end

      #: (Exception? error) -> void
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
      #: { -> void } -> Integer
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

      #: (Exception? error) -> Exception?
      def exception_for_submission(error)
        # happens on normal non-error termination
        return if error.nil?

        return unless error.bug?

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

      #: (String message) -> void
      def stderr_puts(message)
        $stderr.puts(CLI::UI.fmt("{{red:#{message}}}"))
      rescue Errno::EPIPE, Errno::EIO
        nil
      end

      #: -> singleton(ExceptionReporter)
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
