require 'cli/kit'
require 'cli/ui'

module CLI
  module Kit
    module Errors
      def self.on_error(&block)
        @on_error = block
      end

      def self.handle_abort
        yield
      rescue CLI::Kit::GenericAbort => e
        is_bug    = e.is_a?(CLI::Kit::Bug) || e.is_a?(CLI::Kit::BugSilent)
        is_silent = e.is_a?(CLI::Kit::AbortSilent) || e.is_a?(CLI::Kit::BugSilent)

        if !is_silent && ENV['IM_ALREADY_PRO_THANKS'].nil? && @on_error
          @on_error.call(e)
        elsif !is_silent
          STDERR.puts(format_error_message(e.message))
        end

        if is_bug
          CLI::Kit::ReportErrors.exception = e
        end

        return CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG
      rescue Interrupt
        STDERR.puts(format_error_message("Interrupt"))
        return CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG
      end
    end
  end
end
