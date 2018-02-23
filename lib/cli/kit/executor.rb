require 'cli/kit'
require 'English'

module CLI
  module Kit
    class Executor
      def initialize(log_file:)
        @log_file = log_file
      end

      def call(command, command_name, args)
        with_traps { with_logging { command.call(args, command_name) } }
      end

      private

      def with_logging(&block)
        return yield unless @log_file
        CLI::UI.log_output_to(@log_file, &block)
      end

      def with_traps
        twrap('QUIT', method(:quit_handler)) do
          twrap('INFO', method(:info_handler)) do
            yield
          end
        end
      end

      def twrap(signal, handler)
        prev_handler = trap(signal, handler)
        yield
      ensure
        trap(signal, prev_handler)
      end

      def quit_handler(_sig)
        z = caller
        CLI::UI.raw do
          $stderr.puts('SIGQUIT: quit')
          $stderr.puts(z)
        end
        exit(CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG)
      end

      def info_handler(_sig)
        z = caller
        CLI::UI.raw do
          $stderr.puts('SIGINFO:')
          $stderr.puts(z)
        end
      end
    end
  end
end
