# typed: true
require 'gen'

module Gen
  module Commands
    extend T::Sig

    Registry = CLI::Kit::CommandRegistry.new(
      default: 'help',
      contextual_resolver: nil
    )

    sig { params(const: T.untyped, cmd: T.untyped, path: T.untyped).returns(T.untyped) }
    def self.register(const, cmd, path)
      autoload(const, path)
      # rubocop:disable Sorbet/ConstantsFromStrings
      Registry.add(->() { const_get(const) }, cmd)
      # rubocop:enable Sorbet/ConstantsFromStrings
    end

    register :Help, 'help', 'gen/commands/help'
    register :New,  'new',  'gen/commands/new'
  end
end
