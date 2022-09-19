#!/usr/bin/env ruby
# typed: true

require 'cli/ui'
require 'cli/kit'

CLI::UI::StdoutRouter.enable

module Example
  TOOL_NAME = 'example'
  ROOT      = File.expand_path('../..', __FILE__)
  LOG_FILE  = '/tmp/example.log'

  module Commands
    Registry = CLI::Kit::CommandRegistry.new(default: 'hello')

    class << self
      sig { params(const: Symbol, cmd: String, path: String, lamda_const: T.proc.returns(Example::Command)).void }
      def register(const, cmd, path, lamda_const)
        autoload(const, path)
        Registry.add(lamda_const, cmd)
      end

      # register(:Hello, 'hello', 'a/b/hello', -> { Commands::Hello })
    end

    class Hello < Example::Command
      sig { override.params(_args: T::Array[String], _name: String).void }
      def call(_args, _name)
        puts 'hello, world!'
      end
    end
  end

  module EntryPoint
    class << self
      sig { params(args: T::Array[String]).void }
      def call(args)
        cmd, command_name, args = Example::Resolver.call(args)
        Example::Executor.call(cmd, command_name, args)
      end
    end
  end

  Config = CLI::Kit::Config.new(tool_name: TOOL_NAME)
  Command = CLI::Kit::BaseCommand

  Executor = CLI::Kit::Executor.new(log_file: LOG_FILE)
  Resolver = CLI::Kit::Resolver.new(
    tool_name: TOOL_NAME,
    command_registry: Example::Commands::Registry,
  )

  ErrorHandler = CLI::Kit::ErrorHandler.new(log_file: LOG_FILE)
end

if __FILE__ == $PROGRAM_NAME
  exit(Example::ErrorHandler.call do
    Example::EntryPoint.call(ARGV.dup)
  end)
end
