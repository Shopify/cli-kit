require 'cli/kit'
require 'English'

module CLI
  module Kit
    class Executor
      def initialize(log_file:)
        @log_file = log_file
      end

      def call(command, command_name, args)
        trap_signals
        with_logging { command.call(args, command_name) }
      end

      private

      def with_logging(&block)
        return yield unless @log_file
        CLI::UI.log_output_to(@log_file, &block)
      end

      def trap_signals
        trap('QUIT') do
          z = caller
          CLI::UI.raw do
            STDERR.puts('SIGQUIT: quit')
            STDERR.puts(z)
          end
          exit 1
        end
        trap('INFO') do
          z = caller
          CLI::UI.raw do
            STDERR.puts('SIGINFO:')
            STDERR.puts(z)
            # Thread.list.map { |t| t.backtrace }
          end
        end
      end
    end
  end
end
