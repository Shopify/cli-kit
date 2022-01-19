# typed: true
require 'cli/kit'

module CLI
  module Kit
    class BaseCommand
      extend T::Sig
      extend T::Helpers
      abstract!

      sig { returns(T::Boolean) }
      def self.defined?
        true
      end

      sig { params(args: T::Array[String], command_name: String).void }
      def self.call(args, command_name)
        cmd = new
        begin
          cmd.call(args, command_name)
        rescue Exception => e # rubocop:disable Lint/RescueException
          raise e
        end
      end

      sig { abstract.params(_args: T::Array[String], _command_name: String).void }
      def call(_args, _command_name); end

      sig { returns(T::Boolean) }
      def has_subcommands?
        false
      end
    end
  end
end
