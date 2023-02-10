# typed: true

require 'cli/kit'
require 'English'
require 'fileutils'

module CLI
  module Kit
    class Executor
      extend T::Sig

      sig { params(log_file: String).void }
      def initialize(log_file:)
        FileUtils.mkpath(File.dirname(log_file))
        @log_file = log_file
      end

      sig { params(command: T.class_of(CLI::Kit::BaseCommand), command_name: String, args: T::Array[String]).void }
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

      sig do
        type_parameters(:T).params(block: T.proc.params(id: String).returns(T.type_parameter(:T)))
          .returns(T.type_parameter(:T))
      end
      def with_logging(&block)
        CLI::UI.log_output_to(@log_file) do
          CLI::UI::StdoutRouter.with_id(on_streams: [CLI::UI::StdoutRouter.duplicate_output_to].compact) do |id|
            block.call(id)
          end
        end
      end

      sig { type_parameters(:T).params(block: T.proc.returns(T.type_parameter(:T))).returns(T.type_parameter(:T)) }
      def with_traps(&block)
        twrap('QUIT', method(:quit_handler)) do
          twrap('INFO', method(:info_handler), &block)
        end
      end

      sig do
        type_parameters(:T)
          .params(signal: String, handler: Method, block: T.proc.returns(T.type_parameter(:T)))
          .returns(T.type_parameter(:T))
      end
      def twrap(signal, handler, &block)
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

      sig { params(_sig: T.untyped).void }
      def quit_handler(_sig)
        z = caller
        CLI::UI.raw do
          $stderr.puts('SIGQUIT: quit')
          $stderr.puts(z)
        end
        exit(CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG)
      end

      sig { params(_sig: T.untyped).void }
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
