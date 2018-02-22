module CLI
  module Kit
    class AppConfig
      attr_accessor :command_registry, :default_command, :error_handler, :executor, :log_file, :resolver, :tool_name
    end
  end
end
