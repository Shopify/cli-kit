require 'todo'

module Todo
  Executor = CLI::Kit::Executor.new(
    tool_name: Todo::TOOL_NAME,
    log_file: '/tmp/todo.log',
    command_registry: Todo::Commands::REGISTRY,
    error_handler: Todo::ErrorHandler
  )
end
