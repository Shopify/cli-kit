require 'todo'
require 'json'

module Todo
  module Commands
    class Complete < Todo::Command
      def call(args, _name)
        list = Todo::Config.get('default', 'list') || '[]'
        data = JSON.parse(list)
        data.slice!(args.first.to_i)
        Todo::Config.set('default', 'list', data.to_json)
      end

      def self.help
        "Completes the todo entry at specified index.\nUsage: {{command:#{Todo::TOOL_NAME} add}} {{info:index_of_entry}}"
      end
    end
  end
end
