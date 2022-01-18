# typed: true
require 'gen'

module Gen
  module Commands
    extend T::Sig

    Registry = CLI::Kit::CommandRegistry.new(
      default: 'help',
      contextual_resolver: nil
    )

    sig { params(const: Symbol, cmd: String, path: String, lamda_const: T.proc.returns(Runtime::Command)).void }
    def self.register(const, cmd, path, lamda_const)
      autoload(const, path)
      Registry.add(lamda_const, cmd)
    end

    register :Help, 'help', 'gen/commands/help', -> { Help }
    register :New,  'new',  'gen/commands/new'
  end
end
