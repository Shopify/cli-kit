# typed: false
require 'cli/kit'
require 'English'
require 'fileutils'

module CLI
  module Kit
    class Executor
      extend(T::Sig)

      sig { params(log_file: String).void }
      def initialize(log_file:)
        FileUtils.mkpath(File.dirname(log_file))
        @log_file = log_file
      end

      sig do
        params(
          command: T.untyped,
          command_name: String,
          args: T.nilable(T::Array[String]),
        ).void
      end
      def call(command, command_name, args)
        with_traps do
          with_logging do |id|
            begin
              command.call(args, command_name)
            rescue => e
              begin
                $stderr.puts "This command ran with ID: #{id}"
                $stderr.puts "Please include this information in any issues/report along with relevant logs"
              rescue SystemCallError
                # Outputting to stderr is best-effort.  Avoid raising another error when outputting debug info so that
                # we can detect and log the original error, which may even be the source of this error.
                nil
              end
              raise e
            end
          end
        end
      end

      private

      sig do
        type_parameters(:U)
          .params(block: T.proc.returns(T.type_parameter(:U)))
          .returns(T.type_parameter(:U))
      end
      def with_logging(&block)
        return yield unless @log_file
        CLI::UI.log_output_to(@log_file) do
          CLI::UI::StdoutRouter.with_id(on_streams: [CLI::UI::StdoutRouter.duplicate_output_to]) do |id|
            block.call(id)
          end
        end
      end

      sig do
        type_parameters(:U)
          .params(block: T.proc.returns(T.type_parameter(:U)))
          .returns(T.type_parameter(:U))
      end
      def with_traps(&block)
        twrap('QUIT', method(:quit_handler)) do
          twrap('INFO', method(:info_handler), &block)
        end
      end

      sig do
        type_parameters(:U)
          .params(signal: T.untyped, handler: T.untyped, block: T.proc.returns(T.type_parameter(:U)))
          .returns(T.type_parameter(:U))
      end
      def twrap(signal, handler, &block)
        return block.call unless Signal.list.key?(signal)

        begin
          prev_handler = trap(signal, handler)
          block.call
        ensure
          trap(signal, prev_handler)
        end
      end

      sig { params(_sig: Integer).returns(T.noreturn) }
      def quit_handler(_sig)
        z = caller
        CLI::UI.raw do
          $stderr.puts('SIGQUIT: quit')
          $stderr.puts(z)
        end
        exit(CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG)
      end

      sig { params(_sig: Integer).void }
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
