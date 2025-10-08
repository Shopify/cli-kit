# typed: true

require 'gen'

module Gen
  module Commands
    Registry = CLI::Kit::CommandRegistry.new(default: 'help')

    class << self
      #: (Symbol const, String cmd, String path, ^-> singleton(Gen::Command) lamda_const) -> void
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
