require 'gen'

module Gen
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

    register :Help
    register :New
  end
end
