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
    Registry = CLI::Kit::CommandRegistry.new(
      default: 'hello',
      contextual_resolver: nil
    )

    sig { params(const: T.untyped, cmd: T.untyped, path: T.untyped).returns(T.untyped) }
    def self.register(const, cmd, path)
      autoload(const, path)
      Registry.add(->() { const_get(const) }, cmd)
    end

    # register(:Hello, 'hello', 'a/b/hello')

    class Hello < Example::Command
      sig { params(_args: T.untyped, _name: T.untyped).returns(T.untyped) }
      def call(_args, _name)
        puts 'hello, world!'
      end
    end
  end

  module EntryPoint
    sig { params(args: T.untyped).returns(T.untyped) }
    def self.call(args)
      cmd, command_name, args = Example::Resolver.call(args)
      Example::Executor.call(cmd, command_name, args)
    end
  end

  Config = CLI::Kit::Config.new(tool_name: TOOL_NAME)
  Command = CLI::Kit::BaseCommand

  Executor = CLI::Kit::Executor.new(log_file: LOG_FILE)
  Resolver = CLI::Kit::Resolver.new(
    tool_name: TOOL_NAME,
    command_registry: Example::Commands::Registry
  )

  ErrorHandler = CLI::Kit::ErrorHandler.new(log_file: LOG_FILE)
end

if __FILE__ == $PROGRAM_NAME
  exit(Example::ErrorHandler.call do
    Example::EntryPoint.call(ARGV.dup)
  end)
end
