# typed: true

require 'cli/kit'

module CLI
  module Kit
    # @abstract
    class BaseCommand
      include CLI::Kit::CommandHelp
      extend CLI::Kit::CommandHelp::ClassMethods

      class << self
        #: -> bool
        def defined?
          true
        end

        #: (Array[String] args, String command_name) -> void
        def call(args, command_name)
          new.call(args, command_name)
        end
      end

      #: -> bool
      def has_subcommands?
        false
      end
    end
  end
end
