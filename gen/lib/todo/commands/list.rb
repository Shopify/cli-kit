require 'todo'
require 'json'

module Todo
  module Commands
    class List < Todo::Command
      def call(args, _name)
        list = Todo::Config.get('default', 'list') || '[]'
        data = JSON.parse(list)
        data.each.with_index { |d, i| puts(format("%2d: %s", i, d)) }
      end

      def self.help
        "Lists the todo entries.\nUsage: {{command:#{Todo::TOOL_NAME} list}}"
      end
    end
  end
end
