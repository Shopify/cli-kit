require 'cli/ui'
require 'cli/kit'

CLI::UI::StdoutRouter.enable

module __App__
  TOOL_NAME = '__app__'
  ROOT      = File.expand_path('../..', __FILE__)
  LOG_FILE  = '/tmp/__app__.log'

  autoload(:EntryPoint, '__app__/entry_point')
  autoload(:Commands,   '__app__/commands')

  Config = CLI::Kit::Config.new(tool_name: TOOL_NAME)
  Command = CLI::Kit::BaseCommand

  Executor = CLI::Kit::Executor.new(log_file: LOG_FILE)
  Resolver = CLI::Kit::Resolver.new(
    tool_name: TOOL_NAME,
    command_registry: __App__::Commands::Registry
  )

  ErrorHandler = CLI::Kit::ErrorHandler.new(log_file: LOG_FILE)
end
