# typed: true
require 'gen'

module Gen
  module Commands
    class New < Gen::Command
      extend T::Sig

      command_name('new')
      desc('Create a new project')
      long_desc(<<~LONGDESC)
        This is currently a very simple command. In theory it could be extended
        to support a number of flags like {{command:bundle gem}}, etc. As it is, it only
        takes an application name.
      LONGDESC
      usage('[app_name]')
      example('mycliapp', "create a new project called 'mycliapp'")

      class Opts < CLI::Kit::Opts
      end

      sig { params(op: Opts, _name: T.untyped).returns(T.untyped) }
      def invoke(op, _name)
        unless op.args.size == 1
          puts(self.class.build_help)
          raise(CLI::Kit::AbortSilent)
        end

        Gen::Generator.run(op.args.first)
      end
    end
  end
end
