require 'todo'
require 'json'

module Todo
  module Commands
    class Add < Todo::Command
      def call(args, _name)
        list = Todo::Config.get('default', 'list') || '[]'
        data = JSON.parse(list)
        data << args.first
        Todo::Config.set('default', 'list', data.to_json)
      end

      def self.help
        "Add a todo entry.\nUsage: {{command:#{Todo::TOOL_NAME} add}} {{info:data}}"
      end
    end
  end
end
