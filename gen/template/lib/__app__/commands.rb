require '__app__'

module __App__
  module Commands
    Registry = CLI::Kit::CommandRegistry.new(default: 'help')

    def self.register(const, cmd, path)
      autoload(const, path)
      Registry.add(->() { const_get(const) }, cmd)
    end

    register :Example, 'example', '__app__/commands/example'
    register :Help,    'help',    '__app__/commands/help'
  end
end
