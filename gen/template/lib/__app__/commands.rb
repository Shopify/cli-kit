require '__app__'

module __App__
  module Commands
    extend CLI::Kit::SubmoduleLoader

    Registry = CLI::Kit::CommandRegistry.new(
      default: 'help',
      contextual_resolver: nil
    )

    def self.register(const, cmd = nil)
      autoload_submodule const

      cmd = CLI::Kit::Util.dash_case(const.to_s) if cmd.nil?
      Registry.add(->() { const_get(const) }, cmd)
    end

    register :Example
    register :Help
  end
end
