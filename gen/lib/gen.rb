# typed: true

require 'cli/ui'
require 'cli/kit'

CLI::UI::StdoutRouter.enable

module Gen
  TOOL_NAME = 'cli-kit'
  CLI::Kit::CommandHelp.tool_name = TOOL_NAME

  ROOT = File.expand_path('../../..', __FILE__)

  TOOL_CONFIG_PATH = File.expand_path(File.join('~', '.config', TOOL_NAME))
  LOG_FILE = File.join(TOOL_CONFIG_PATH, 'logs', 'log.log')
  DEBUG_LOG_FILE = File.join(TOOL_CONFIG_PATH, 'logs', 'debug.log')

  autoload(:Generator,  'gen/generator')
  autoload(:EntryPoint, 'gen/entry_point')
  autoload(:Help,       'gen/help')
  autoload(:Commands,   'gen/commands')

  Config = CLI::Kit::Config.new(tool_name: TOOL_NAME)
  Command = CLI::Kit::BaseCommand
  Logger = CLI::Kit::Logger.new(debug_log_file: DEBUG_LOG_FILE)

  Executor = CLI::Kit::Executor.new(log_file: LOG_FILE)
  Resolver = CLI::Kit::Resolver.new(
    tool_name: TOOL_NAME,
    command_registry: Gen::Commands::Registry,
  )

  ErrorHandler = CLI::Kit::ErrorHandler.new(log_file: LOG_FILE)
end
