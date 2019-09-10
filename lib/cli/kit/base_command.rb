# typed: true
require 'cli/kit'

module CLI
  module Kit
    class BaseCommand
      extend(T::Sig)

      sig { returns(T::Boolean) }
      def self.defined?
        true
      end

      sig { params(_metric: String, _kwargs: T.untyped).void }
      def self.statsd_increment(_metric, **_kwargs)
        nil
      end

      sig do
        type_parameters(:U)
          .params(_metric: String, _kwargs: T.untyped, block: T.proc.returns(T.type_parameter(:U)))
          .returns(T.type_parameter(:U))
      end
      def self.statsd_time(_metric, **_kwargs, &block)
        block.call
      end

      sig { params(args: T.nilable(T::Array[String]), command_name: String).void }
      def self.call(args, command_name)
        cmd = new
        stats_tags = cmd.stats_tags(args, command_name)
        begin
          statsd_increment("cli.command.invoked", tags: stats_tags)
          statsd_time("cli.command.time", tags: stats_tags) do
            cmd.call(args, command_name)
          end
          statsd_increment("cli.command.success", tags: stats_tags)
        rescue Exception => e # rubocop:disable Lint/RescueException
          statsd_increment("cli.command.exception", tags: stats_tags + ["exception:#{e.class}"])
          raise e
        end
      end

      sig { params(args: T.nilable(T::Array[String]), command_name: String).returns(T::Array[String]) }
      def stats_tags(args, command_name)
        tags = ["task:#{self.class}"]
        tags << "command:#{command_name}" if command_name
        tags << "subcommand:#{args.first}" if args&.first && has_subcommands?
        tags
      end

      sig { params(_args: T.nilable(T::Array[String]), _command_name: String).void }
      def call(_args, _command_name)
        raise NotImplementedError
      end

      sig { returns(T::Boolean) }
      def has_subcommands?
        false
      end
    end
  end
end
