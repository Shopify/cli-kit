# typed: true
require 'cli/kit'

module CLI
  module Kit
    class BaseCommand
      extend T::Sig
      include CLI::Kit::CommandHelp
      extend CLI::Kit::CommandHelp::ClassMethods

      sig { returns(T.untyped) }
      def self.defined?
        true
      end

      sig { params(_metric: T.untyped, _kwargs: T.untyped).returns(T.untyped) }
      def self.statsd_increment(_metric, **_kwargs)
        nil
      end

      sig { params(_metric: T.untyped, _kwargs: T.untyped).returns(T.untyped) }
      def self.statsd_time(_metric, **_kwargs)
        yield
      end

      sig { params(args: T.untyped, command_name: T.untyped).returns(T.untyped) }
      def self.call(args, command_name)
        cmd = new
        stats_tags = cmd.stats_tags(args, command_name)
        begin
          statsd_increment('cli.command.invoked', tags: stats_tags)
          statsd_time('cli.command.time', tags: stats_tags) do
            cmd.call(args, command_name)
          end
          statsd_increment('cli.command.success', tags: stats_tags)
        rescue Exception => e # rubocop:disable Lint/RescueException
          statsd_increment('cli.command.exception', tags: stats_tags + ["exception:#{e.class}"])
          raise e
        end
      end

      sig { params(args: T.untyped, command_name: T.untyped).returns(T.untyped) }
      def stats_tags(args, command_name)
        tags = ["task:#{self.class}"]
        tags << "command:#{command_name}" if command_name
        tags << "subcommand:#{args.first}" if args&.first && has_subcommands?
        tags
      end

      # sig { params(_args: T.untyped, _command_name: T.untyped).returns(T.untyped) }
      # def call(_args, _command_name)
      #   raise NotImplementedError, "#{self.class.name} must implement #{__method__}"
      # end

      sig { returns(T.untyped) }
      def has_subcommands?
        false
      end
    end
  end
end
