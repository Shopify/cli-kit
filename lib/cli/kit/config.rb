# typed: true

require 'cli/kit'
require 'fileutils'
require 'tempfile'

module CLI
  module Kit
    class Config
      XDG_CONFIG_HOME = 'XDG_CONFIG_HOME'

      # Raised when the config file cannot be written (e.g. read-only
      # directory, read-only filesystem, nix/home-manager-managed symlink
      # pointing into +/nix/store+).
      #
      # Inherits from SystemCallError so existing `rescue SystemCallError`
      # handlers around +Config#set+ continue to match. The message contains
      # only the keys that actually changed; unchanged keys (which may
      # include sensitive values such as API tokens) are intentionally
      # excluded so the failure message can never leak secrets through
      # stderr or exception reports.
      class ConfigWriteError < SystemCallError
        class << self
          # Ruby's +SystemCallError.===+ uses errno-based matching,
          # which means +rescue ConfigWriteError+ would otherwise fail
          # to catch a ConfigWriteError instance (it would match
          # +Errno::EACCES+ or +Errno::EPERM+ instead, based on the
          # wrapped errno). Override with plain class-hierarchy
          # matching so +rescue ConfigWriteError+ works as callers
          # expect. +rescue SystemCallError+ still matches via normal
          # inheritance.
          #: (untyped other) -> bool
          def ===(other)
            other.is_a?(self)
          end

          # +SystemCallError.new+ has a factory-style signature defined
          # in Sorbet's stdlib RBI (+(String | Integer?) ->
          # SystemCallError+) which doesn't match this subclass's
          # four-argument constructor. Override +.new+ here so type
          # checkers and callers see the real signature, and allocate
          # the instance manually to bypass +SystemCallError+'s
          # factory behaviour.
          #: (String config_path, String old_content, String new_content, SystemCallError cause) -> ConfigWriteError
          def new(config_path, old_content, new_content, cause)
            instance = allocate
            instance.__send__(:initialize, config_path, old_content, new_content, cause)
            instance
          end
        end

        #: String
        attr_reader :config_path

        #: String
        attr_reader :old_content

        #: String
        attr_reader :new_content

        # rubocop:disable Lint/MissingSuper
        # +SystemCallError#initialize+ has a factory-style signature that
        # cannot be invoked from a plain subclass (it expects a matching
        # Errno constant on the class). We bypass it deliberately and
        # initialize via Exception so we just get a message-only
        # exception that +rescue SystemCallError+ still catches via
        # inheritance. +super+ would not work here.
        #: (String config_path, String old_content, String new_content, SystemCallError cause) -> void
        def initialize(config_path, old_content, new_content, cause)
          @config_path = config_path
          @old_content = old_content
          @new_content = new_content
          @wrapped_errno = cause.errno
          message = <<~MSG.rstrip
            Could not write to #{config_path}: #{cause.message}

            Attempted changes (unchanged keys omitted):
            #{diff}
          MSG
          Exception.instance_method(:initialize).bind(self).call(message)
        end
        # rubocop:enable Lint/MissingSuper

        # Preserve the original errno from the wrapped Errno so callers
        # that inspect +errno+ continue to see the real underlying code.
        #: -> Integer?
        def errno
          @wrapped_errno
        end

        # A line-by-line diff of only the sections/keys that changed
        # between +old_content+ and +new_content+. Unchanged keys are
        # omitted so that sensitive values stored elsewhere in the config
        # are never included in the failure message.
        #: -> String
        def diff
          old_ini = CLI::Kit::Ini.new(config: @old_content).tap(&:parse).ini
          new_ini = CLI::Kit::Ini.new(config: @new_content).tap(&:parse).ini

          lines = []
          (old_ini.keys | new_ini.keys).each do |section|
            old_section = old_ini[section] || {}
            new_section = new_ini[section] || {}

            changes = []
            (old_section.keys | new_section.keys).each do |key|
              old_val = old_section[key]
              new_val = new_section[key]
              next if old_val == new_val

              changes << "- #{key} = #{old_val}" if old_val
              changes << "+ #{key} = #{new_val}" if new_val
            end
            next if changes.empty?

            prefix = if old_section.empty?
              '+ '
            elsif new_section.empty?
              '- '
            else
              '  '
            end
            lines << "#{prefix}#{section}"
            lines.concat(changes)
          end
          lines.join("\n")
        end
      end

      #: (tool_name: String) -> void
      def initialize(tool_name:)
        @tool_name = tool_name
      end

      # Returns the config corresponding to `name` from the config file
      # `false` is returned if it doesn't exist
      #
      # #### Parameters
      # `section` : the section of the config value you are looking for
      # `name` : the name of the config value you are looking for
      #
      # #### Returns
      # `value` : the value of the config variable (nil if none)
      #
      # #### Example Usage
      # `config.get('name.of.config')`
      #
      #: (String section, String name, ?default: String?) -> String?
      def get(section, name, default: nil)
        all_configs.dig("[#{section}]", name) || default
      end

      # Coalesce and enforce the value of a config to a boolean
      #: (String section, String name, ?default: bool?) -> bool?
      def get_bool(section, name, default: false)
        case get(section, name)
        when 'true'
          true
        when 'false'
          false
        when nil
          default
        else
          raise CLI::Kit::Abort, "Invalid config: #{section}.#{name} is expected to be true or false"
        end
      end

      # Sets the config value in the config file
      #
      # #### Parameters
      # `section` : the section of the config you are setting
      # `name` : the name of the config you are setting
      # `value` : the value of the config you are setting
      #
      # #### Example Usage
      # `config.set('section', 'name.of.config', 'value')`
      #
      #: (String section, String name, (String | bool)? value) -> void
      def set(section, name, value)
        all_configs["[#{section}]"] ||= {}
        section = all_configs["[#{section}]"] #: as !nil
        case value
        when nil
          section.delete(name)
        else
          section[name] = value.to_s
        end
        write_config
      end

      # Unsets a config value in the config file
      #
      # #### Parameters
      # `section` : the section of the config you are deleting
      # `name` : the name of the config you are deleting
      #
      # #### Example Usage
      # `config.unset('section', 'name.of.config')`
      #
      #: (String section, String name) -> void
      def unset(section, name)
        set(section, name, nil)
      end

      # Gets the hash for the entire section
      #
      # #### Parameters
      # `section` : the section of the config you are getting
      #
      # #### Example Usage
      # `config.get_section('section')`
      #
      #: (String section) -> Hash[String, String]
      def get_section(section)
        (all_configs["[#{section}]"] || {}).dup
      end

      #: -> String
      def to_s
        ini.to_s
      end

      # The path on disk at which the configuration is stored:
      #   `$XDG_CONFIG_HOME/<toolname>/config`
      # if ENV['XDG_CONFIG_HOME'] is not set, we default to ~/.config, e.g.:
      #   ~/.config/tool/config
      #
      #: -> String
      def file
        config_home = ENV.fetch(XDG_CONFIG_HOME, '~/.config')
        File.expand_path(File.join(@tool_name, 'config'), config_home)
      end

      private

      #: -> Hash[String, Hash[String, String]]
      def all_configs
        ini.ini
      end

      #: -> CLI::Kit::Ini
      def ini
        @ini ||= CLI::Kit::Ini.new(file).tap(&:parse)
      end

      #: -> void
      def write_config
        all_configs.each do |section, sub_config|
          all_configs.delete(section) if sub_config.empty?
        end

        # Capture +file+ and +to_s+ up front so they are visible (and
        # known to be non-nil) inside the rescue block below.
        config_path = file
        new_content = to_s

        begin
          # Always write atomically (tmpfile + rename) so readers never
          # observe a partial write. If +config_path+ is a symlink (e.g.
          # a nix/home-manager-managed config), resolve it so the rename
          # replaces the real file at the end of the chain and leaves
          # the managed symlink itself intact.
          target_path = resolved_write_path(config_path)
          target_dir = File.dirname(target_path)
          FileUtils.mkdir_p(target_dir)
          write_config_atomic(target_path, target_dir, new_content)
        rescue Errno::EACCES, Errno::EPERM, Errno::EROFS => e
          # +EROFS+ (read-only filesystem) is the canonical error raised
          # when the underlying filesystem is mounted read-only — common
          # for nix/home-manager configs that live in +/nix/store+. Wrap
          # it the same way as +EACCES+/+EPERM+ so callers always see
          # the diff and any +rescue ConfigWriteError+ handler matches.
          old_content = read_config_for_diff(config_path)
          raise(ConfigWriteError.new(config_path, old_content, new_content, e))
        end
      end

      # Write +new_content+ into +config_path+ atomically, via a tmpfile
      # in the same directory followed by rename. Readers never observe
      # a partial write.
      #: (String config_path, String config_dir, String new_content) -> void
      def write_config_atomic(config_path, config_dir, new_content)
        tmpfile = Tempfile.new([File.basename(config_path), '.tmp'], config_dir)
        tmpfile_path = tmpfile.path #: as !nil
        begin
          tmpfile.write(new_content)
          tmpfile.close
          # Tempfile defaults to 0o600. Match the permissions a plain
          # +File.write+ would have produced: preserve the existing
          # mode when the config is being updated, and use the
          # umask-adjusted default (matching +open(2)+ for new files)
          # otherwise. This avoids silently tightening permissions on
          # an existing config and avoids creating new configs with
          # the more restrictive Tempfile default.
          mode = if File.exist?(config_path)
            File.stat(config_path).mode
          else
            0o666 & ~File.umask
          end
          File.chmod(mode, tmpfile_path)
          File.rename(tmpfile_path, config_path)
        rescue Exception # rubocop:disable Lint/RescueException
          tmpfile.close unless tmpfile.closed?
          File.unlink(tmpfile_path) if File.exist?(tmpfile_path)
          raise
        end
      end

      #: (String config_path) -> String
      def read_config_for_diff(config_path)
        File.read(config_path)
      rescue SystemCallError
        ''
      end

      # Resolve +config_path+ through any symlinks so the atomic rename
      # in +write_config_atomic+ replaces the real file at the end of
      # the chain instead of clobbering the symlink with a regular file.
      # For broken symlinks, fall back to +config_path+ itself so we
      # still create a config there.
      #: (String config_path) -> String
      def resolved_write_path(config_path)
        return config_path unless File.symlink?(config_path)

        File.realpath(config_path)
      rescue Errno::ENOENT
        config_path
      end
    end
  end
end
