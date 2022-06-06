# typed: true

require 'gen'

module Gen
  module Commands
    class Help < Gen::Command
      extend T::Sig

      desc('Show help for a command, or this page')

      sig { params(args: T::Array[String], _name: String).void }
      def call(args, _name)
        Gen::Help.generate(args)
      end
    end
  end
end
