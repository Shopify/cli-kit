#!/usr/bin/env ruby
# typed: true

require 'cli/ui'
require 'cli/kit'

CLI::UI::StdoutRouter.enable

include(CLI::Kit)

registry = CommandRegistry.new(default: 'hello')
registry.add(
  Class.new(BaseCommand) do
    sig { params(_args: T::Array[String], _name: String).void }
    def call(_args, _name)
      puts 'hello, world!'
    end
  end,
  'hello',
)

executor      = Executor.new(log_file: '/tmp/example.log')
error_handler = ErrorHandler.new(log_file: '/tmp/example.log', exception_reporter: nil)
resolver      = Resolver.new(tool_name: 'example', command_registry: registry)
entry_point   = ->(args) { executor.call(*resolver.call(args)) }

exit(error_handler.call { entry_point.call(ARGV.dup) }) if __FILE__ == $PROGRAM_NAME
