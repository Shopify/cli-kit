# typed: true
require 'gen'

module Gen
  module Commands
    class New < Gen::Command
      sig { params(args: T.untyped, _name: T.untyped).returns(T.untyped) }
      def call(args, _name)
        unless args.size == 1
          puts CLI::UI.fmt(self.class.help)
          raise(CLI::Kit::AbortSilent)
        end
        project = args.first

        Gen::Generator.run(project)
      end

      sig { returns(T.untyped) }
      def self.help
        "Generate a new cli-kit project.\nUsage: {{command:#{Gen::TOOL_NAME} new <name>}}"
      end
    end
  end
end
