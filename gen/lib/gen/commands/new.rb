# typed: false
require 'gen'

module Gen
  module Commands
    class New < Gen::Command
      extend(T::Sig)

      sig { params(args: T::Array[String], _name: String).void }
      def call(args, _name)
        unless args.size == 1
          puts CLI::UI.fmt(self.class.help)
          raise(CLI::Kit::AbortSilent)
        end
        project = args.first

        Gen::Generator.run(project)
      end

      sig { returns(String) }
      def self.help
        "Generate a new cli-kit project.\nUsage: {{command:#{Gen::TOOL_NAME} new <name>}}"
      end
    end
  end
end
