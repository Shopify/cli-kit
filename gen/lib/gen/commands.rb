# typed: true
require 'gen'

module Gen
  module Commands
    extend(T::Sig)

    Registry = CLI::Kit::CommandRegistry.new(
      default: 'help',
      contextual_resolver: nil
    )

    sig { params(const: Symbol, cmd: String, path: String).void }
    def self.register(const, cmd, path)
      autoload(const, path)
      Registry.add(->() { const_get(const) }, cmd)
    end

    register :Help, 'help', 'gen/commands/help'
    register :New,  'new',  'gen/commands/new'
  end
end
