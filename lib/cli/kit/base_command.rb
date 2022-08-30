# typed: true

require 'cli/kit'

module CLI
  module Kit
    class BaseCommand
      extend T::Sig
      extend T::Helpers
      include CLI::Kit::CommandHelp
      extend CLI::Kit::CommandHelp::ClassMethods
      abstract!

      class << self
        extend T::Sig

        sig { returns(T::Boolean) }
        def defined?
          true
        end

        sig { params(args: T::Array[String], command_name: String).void }
        def call(args, command_name)
          new.call(args, command_name)
        end
      end

      sig { returns(T::Boolean) }
      def has_subcommands?
        false
      end
    end
  end
end
