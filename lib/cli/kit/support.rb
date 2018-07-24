require 'cli/kit'

module CLI
  module Kit
    module Support
      extend CLI::Kit::SubmoduleLoader

      autoload_submodule :TestHelper
    end
  end
end
