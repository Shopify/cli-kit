# typed: true
require 'cli/kit'
require 'English'
require 'fileutils'

module CLI
  module Kit
    class Executor
      extend T::Sig

      sig { params(log_file: T.untyped).void }
      def initialize(log_file:)
        FileUtils.mkpath(File.dirname(log_file))
        @log_file = log_file
      end

      sig { params(command: T.untyped, command_name: T.untyped, args: T.untyped).returns(T.untyped) }
      def call(command, command_name, args)
        with_traps do
          with_logging do |id|
            command.call(args, command_name)
          rescue => e
            begin
              $stderr.puts "This command ran with ID: #{id}"
              $stderr.puts 'Please include this information in any issues/report along with relevant logs'
            rescue SystemCallError
              # Outputting to stderr is best-effort.  Avoid raising another error when outputting debug info so that
              # we can detect and log the original error, which may even be the source of this error.
              nil
            end
            raise e
          end
        end
      end

      private

      sig { params(block: T.untyped).returns(T.untyped) }
      def with_logging(&block)
        return yield unless @log_file
        CLI::UI.log_output_to(@log_file) do
          CLI::UI::StdoutRouter.with_id(on_streams: [CLI::UI::StdoutRouter.duplicate_output_to]) do |id|
            block.call(id)
          end
        end
      end

      sig { params(block: T.untyped).returns(T.untyped) }
      def with_traps(&block)
        twrap('QUIT', method(:quit_handler)) do
          twrap('INFO', method(:info_handler), &block)
        end
      end

      sig { params(signal: T.untyped, handler: T.untyped).returns(T.untyped) }
      def twrap(signal, handler)
        return yield unless Signal.list.key?(signal)

        begin
          begin
            prev_handler = trap(signal, handler)
            installed = true
          rescue ArgumentError
            # If we couldn't install a signal handler because the signal is
            # reserved, remember not to uninstall it later.
            installed = false
          end
          yield
        ensure
          trap(signal, prev_handler) if installed
        end
      end

      sig { params(_sig: T.untyped).returns(T.untyped) }
      def quit_handler(_sig)
        z = caller
        CLI::UI.raw do
          $stderr.puts('SIGQUIT: quit')
          $stderr.puts(z)
        end
        exit(CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG)
      end

      sig { params(_sig: T.untyped).returns(T.untyped) }
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
