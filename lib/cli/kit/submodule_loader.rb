require 'pathname'
require 'cli/kit/util'

# Utility to register submodules or classes with autoload,
# if they follow the pattern of Foo::PascalCase => foo/snake_case.rb
#
# Usage:
#
# /path/to/lib/app.rb
# module App
#   extend CLI::Kit::SubmoduleLoader
#   autoload_submodule :Foo        # /path/to/lib/app/foo.rb
# end
#
# /path/to/lib/app/foo.rb
# module App
#   module Foo
#     extend CLI::Kit::SubmoduleLoader
#     autoload_submodule :Bar      # /path/to/lib/app/foo/bar.rb
#     autoload_submodule :Baz      # /path/to/lib/app/foo/baz.rb
#   end
# end
module CLI
  module Kit
    module SubmoduleLoader
      def self.included(_mod)
        raise "#{self} should be used with 'extend', not 'include'"
      end

      def self.extended(mod)
        file = caller_locations(1, 1).first.absolute_path
        filename = File.basename(file, '.rb')
        autoload_dir = Pathname.new(file).parent.join(filename).expand_path
        mod.class_eval { @autoload_dir = autoload_dir }
      end

      def autoload_submodule(sym)
        submodule_name = CLI::Kit::Util.snake_case(sym.to_s)
        autoload(sym, @autoload_dir.join(submodule_name))
      end
    end
  end
end
