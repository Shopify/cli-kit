require 'cli/kit'
require 'cli/ui'

module CLI
  module Kit
    class Resolver
      def initialize(command_registry:)
        @command_registry = command_registry
      end

      def call(args)
        args = args.dup
        command_name = args.shift

        CLI::Kit::Errors.handle_abort do
          command, command_name = @command_registry.lookup_command(command_name)
          return [command, command_name, args]
        end

        exit CLI::Kit::EXIT_FAILURE_BUT_NOT_BUG
      end
    end
  end
end
