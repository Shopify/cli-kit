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

      sig { returns(T::Boolean) }
      def self.defined?
        true
      end

      sig { params(args: T::Array[String], command_name: String).void }
      def self.call(args, command_name)
        new.call(args, command_name)
      end

      sig { returns(T::Boolean) }
      def has_subcommands?
        false
      end
    end
  end
end
