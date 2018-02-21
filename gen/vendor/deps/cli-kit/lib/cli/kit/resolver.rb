require 'cli/kit'

module CLI
  module Kit
    class Resolver
      def initialize(command_registry:, error_handler:)
        @command_registry = command_registry
        @error_handler = error_handler
      end

      def call(args)
        args = args.dup
        command_name = args.shift

        @error_handler.handle_abort do
          command, command_name = @command_registry.lookup_command(command_name)
          return [command, command_name, args]
        end

        exit CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG
      end
    end
  end
end
