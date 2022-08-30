# typed: true

require 'gen'

module Gen
  module Commands
    extend T::Sig

    Registry = CLI::Kit::CommandRegistry.new(default: 'help')

    class << self
      extend T::Sig

      sig do
        params(const: Symbol, cmd: String, path: String, lamda_const: T.proc.returns(T.class_of(Gen::Command))).void
      end
      def register(const, cmd, path, lamda_const)
        autoload(const, path)
        Registry.add(lamda_const, cmd)
      end
    end

    register :Help, 'help', 'gen/commands/help', -> { Commands::Help }
    register :New,  'new',  'gen/commands/new', -> { Commands::New }

    # TODO(burke): Really, cli-kit needs to handle global flags/options.
    Registry.add_alias('-h', 'help')
    Registry.add_alias('--help', 'help')
  end
end
