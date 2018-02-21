require 'todo'

module Todo
  module EntryPoint
    def self.call(args)
      cmd, command_name, args = Todo::Resolver.call(args)
      Todo::Executor.call(cmd, command_name, args)
    end
  end
end
