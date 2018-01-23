require 'cli/kit'

module CLI
  module Kit
    class BaseCommand
      def self.defined?
        true
      end

      def self.statsd_increment(metric, **kwargs)
        nil
      end

      def self.statsd_time(metric, **kwargs)
        yield
      end

      def self.call(args, command_name)
        cmd = new
        stats_tags = ["task:#{cmd.class}"]
        stats_tags << "subcommand:#{args.first}" if args && args.first && cmd.has_subcommands?
        begin
          statsd_increment("cli.command.invoked", tags: stats_tags)
          statsd_time("cli.command.time", tags: stats_tags) do
            cmd.call(args, command_name)
          end
          statsd_increment("cli.command.success", tags: stats_tags)
        rescue => e
          statsd_increment("cli.command.exception", tags: stats_tags + ["exception:#{e.class}"])
          raise e
        end
      end

      def call(args, command_name)
        raise NotImplementedError
      end

      def has_subcommands?
        false
      end
    end
  end
end
