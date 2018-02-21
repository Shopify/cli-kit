require 'todo'

module Todo
  Resolver = CLI::Kit::Resolver.new(
    command_registry: Todo::Commands::REGISTRY,
    error_handler: Todo::ErrorHandler
  )
end
