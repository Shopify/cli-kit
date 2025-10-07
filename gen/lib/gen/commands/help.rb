# typed: true

require 'gen'

module Gen
  module Commands
    class Help < Gen::Command
      desc('Show help for a command, or this page')

      #: (Array[String] args, String _name) -> void
      def call(args, _name)
        Gen::Help.generate(args)
      end
    end
  end
end
