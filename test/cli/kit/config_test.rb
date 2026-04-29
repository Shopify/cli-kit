require 'test_helper'

module CLI
  module Kit
    class ConfigTest < Minitest::Test
      include CLI::Kit::Support::TestHelper::FakeConfig

      def setup
        super
        @file = File.join(@tmpdir, 'tool', 'config')
        @config = Config.new(tool_name: 'tool')
      end

      def test_config_get_returns_false_for_not_existant_key
        refute(@config.get('section', 'invalid-key-no-existing'))
      end

      def test_config_get_returns_default_for_not_existant_key
        assert_equal('custom', @config.get('section', 'invalid-key-no-existing', default: 'custom'))
      end

      def test_config_get_bool_non_existant
        refute(@config.get('section', 'invalid-key-no-existing')) # doesn't exist yet
        refute(@config.get_bool('section', 'invalid-key-no-existing')) # defaults to false
      end

      def test_config_get_bool_non_existant_with_default
        assert_equal('default', @config.get('section', 'invalid-key-no-existing', default: 'default'))
        assert(@config.get_bool('section', 'invalid-key-no-existing', default: true))
      end

      def test_config_get_bool_on_string
        @config.set('section', 'foo-key', 'true')
        assert_equal('true', @config.get('section', 'foo-key')) # doesn't parse by default
        assert_equal(true, @config.get_bool('section', 'foo-key'))

        @config.set('section', 'foo-key', 'false')
        assert_equal('false', @config.get('section', 'foo-key')) # doesn't parse by default
        assert_equal(false, @config.get_bool('section', 'foo-key'))
      end

      def test_config_get_bool_on_bool
        @config.set('section', 'foo-key', true)
        assert_equal('true', @config.get('section', 'foo-key'))
        assert_equal(true, @config.get_bool('section', 'foo-key'))

        @config.set('section', 'foo-key', false)
        assert_equal('false', @config.get('section', 'foo-key'))
        assert_equal(false, @config.get_bool('section', 'foo-key'))
      end

      def test_config_get_bool_on_invalid
        @config.set('section', 'foo-key', 'yes')
        assert_equal('yes', @config.get('section', 'foo-key'))

        e = assert_raises(CLI::Kit::Abort) do
          @config.get_bool('section', 'foo-key')
        end
        assert_equal('Invalid config: section.foo-key is expected to be true or false', e.message)
      end

      def test_get_bool_on_default_nil_unset
        assert_nil(@config.get_bool('section', 'foo-key', default: nil))
      end

      def test_get_bool_on_default_nil_set_false
        @config.set('section', 'foo-key', false)
        assert_equal(false, @config.get_bool('section', 'foo-key', default: nil))
      end

      def test_config_key_never_padded_with_whitespace
        # There was a bug that occured when a key was reset
        # We split on `=` and 'key ' became the new key (with a space)
        # This is a regression test to make sure that doesnt happen
        @config.set('section', 'key', 'value')
        assert_equal({ '[section]' => { 'key' => 'value' } }, @config.send(:all_configs))
        3.times { @config.set('section', 'key', 'value') }
        assert_equal({ '[section]' => { 'key' => 'value' } }, @config.send(:all_configs))
      end

      def test_config_set
        @config.set('section', 'some-key', '~/.test')
        assert_equal("[section]\nsome-key = ~/.test", File.read(@file))

        @config.set('section', 'some-key', nil)
        assert_equal('', File.read(@file))

        @config.set('section', 'some-key', '~/.test')
        @config.set('section', 'some-other-key', '~/.test')
        assert_equal("[section]\nsome-key = ~/.test\nsome-other-key = ~/.test", File.read(@file))
      end

      def test_config_unset
        @config.set('section', 'some-key', '~/.test')
        assert_equal("[section]\nsome-key = ~/.test", File.read(@file))
        @config.unset('section', 'some-key')
        assert_equal('', File.read(@file))
      end

      def test_config_mutli_argument_get
        @config.set('some-parent', 'some-key', 'some-value')
        assert_equal('some-value', @config.get('some-parent', 'some-key'))
      end

      def test_get_section
        @config.set('section', 'some-key', 'should not show')
        @config.set('srcpath', 'other', 'test')
        @config.set('srcpath', 'default', 'Shopify')
        assert_equal({ 'other' => 'test', 'default' => 'Shopify' }, @config.get_section('srcpath'))
      end

      def test_atomic_write_produces_valid_config
        @config.set('section', 'key', 'value')

        assert_equal('value', @config.get('section', 'key'))
        assert(File.exist?(@file), 'config file should exist after set')
        assert_includes(File.read(@file), 'key = value')
      end

      def test_atomic_write_leaves_no_stale_tmpfile
        @config.set('section', 'key', 'value')

        siblings = Dir.entries(File.dirname(@file)) - ['.', '..']
        assert_equal(['config'], siblings, "expected only 'config', got #{siblings.inspect}")
      end

      def test_atomic_write_applies_umask_for_new_file_permissions
        # Tempfile defaults to 0o600. New configs should instead use
        # the umask-adjusted default that +File.write+ would produce.
        original_umask = File.umask(0o022)
        begin
          @config.set('section', 'key', 'value')

          mode = File.stat(@file).mode & 0o777
          assert_equal(0o644, mode, "expected 0o644 with umask 0o022, got #{mode.to_s(8)}")
        ensure
          File.umask(original_umask)
        end
      end

      def test_atomic_write_preserves_existing_file_permissions
        # When the config already exists, its mode should be preserved
        # across the rename rather than replaced by the umask default.
        config_dir = File.dirname(@file)
        FileUtils.mkdir_p(config_dir)
        File.write(@file, "[section]\nkey = original\n")
        FileUtils.chmod(0o640, @file)

        @config.set('section', 'key', 'updated')

        mode = File.stat(@file).mode & 0o777
        assert_equal(0o640, mode, "expected mode to be preserved at 0o640, got #{mode.to_s(8)}")
      end

      def test_write_to_readonly_dir_raises_config_write_error
        config_dir = File.dirname(@file)
        FileUtils.mkdir_p(config_dir)
        File.write(@file, "[section]\nkey = original\n")
        FileUtils.chmod(0o555, config_dir)

        error = assert_raises(CLI::Kit::Config::ConfigWriteError) do
          @config.set('section', 'key', 'updated')
        end

        assert_includes(error.message, @file)
        assert_includes(error.message, '- key = original')
        assert_includes(error.message, '+ key = updated')
      ensure
        FileUtils.chmod(0o755, config_dir) if config_dir && File.directory?(config_dir)
      end

      def test_config_write_error_includes_new_sections
        config_dir = File.dirname(@file)
        FileUtils.mkdir_p(config_dir)
        File.write(@file, '')
        FileUtils.chmod(0o555, config_dir)

        error = assert_raises(CLI::Kit::Config::ConfigWriteError) do
          @config.set('hooks', 'path_check_enabled', 'false')
        end

        assert_includes(error.message, '+ [hooks]')
        assert_includes(error.message, '+ path_check_enabled = false')
      ensure
        FileUtils.chmod(0o755, config_dir) if config_dir && File.directory?(config_dir)
      end

      def test_config_write_error_omits_unchanged_sensitive_values
        config_dir = File.dirname(@file)
        FileUtils.mkdir_p(config_dir)
        File.write(@file, <<~INI)
          [buildkite]
          api_token = super_secret_token_xyz

          [hooks]
          path_check_enabled = true
        INI
        FileUtils.chmod(0o555, config_dir)

        error = assert_raises(CLI::Kit::Config::ConfigWriteError) do
          @config.set('hooks', 'path_check_enabled', 'false')
        end

        refute_includes(
          error.message,
          'super_secret_token_xyz',
          'unchanged sensitive values must not appear in the error message',
        )
        refute_includes(
          error.message,
          'api_token',
          'unchanged keys must not appear in the error message',
        )
        refute_includes(
          error.message,
          '[buildkite]',
          'sections with no changes must not appear in the error message',
        )
        assert_includes(error.message, '- path_check_enabled = true')
        assert_includes(error.message, '+ path_check_enabled = false')
      ensure
        FileUtils.chmod(0o755, config_dir) if config_dir && File.directory?(config_dir)
      end

      def test_config_write_error_is_rescued_as_system_call_error
        config_dir = File.dirname(@file)
        FileUtils.mkdir_p(config_dir)
        File.write(@file, "[section]\nkey = original\n")
        FileUtils.chmod(0o555, config_dir)

        # Existing callers may rescue SystemCallError around Config#set.
        # ConfigWriteError must still be catchable that way.
        caught = begin
          @config.set('section', 'key', 'updated')
          nil
        rescue SystemCallError => e
          e
        end

        assert_kind_of(CLI::Kit::Config::ConfigWriteError, caught)
        assert_kind_of(SystemCallError, caught)
        assert_equal(Errno::EACCES::Errno, caught.errno)
      ensure
        FileUtils.chmod(0o755, config_dir) if config_dir && File.directory?(config_dir)
      end

      def test_write_to_readonly_filesystem_raises_config_write_error
        config_dir = File.dirname(@file)
        FileUtils.mkdir_p(config_dir)
        File.write(@file, "[section]\nkey = original\n")

        # Simulate a read-only filesystem (e.g. /nix/store): Tempfile.new
        # raises EROFS rather than EACCES/EPERM. The wrapper must still
        # produce ConfigWriteError so callers see the diff and the
        # wrapped errno.
        Tempfile.stubs(:new).raises(Errno::EROFS.new(@file))

        error = assert_raises(CLI::Kit::Config::ConfigWriteError) do
          @config.set('section', 'key', 'updated')
        end

        assert_includes(error.message, @file)
        assert_includes(error.message, '- key = original')
        assert_includes(error.message, '+ key = updated')
        assert_equal(Errno::EROFS::Errno, error.errno)
      end

      def test_write_preserves_symlink_on_successful_write
        Dir.mktmpdir do |dir|
          target_dir = File.join(dir, 'target', 'tool')
          link_dir = File.join(dir, 'link', 'tool')
          FileUtils.mkdir_p(target_dir)
          FileUtils.mkdir_p(link_dir)

          target_path = File.join(target_dir, 'config')
          link_path = File.join(link_dir, 'config')
          File.write(target_path, "[section]\nkey = original\n")
          File.symlink(target_path, link_path)

          with_env('XDG_CONFIG_HOME' => File.join(dir, 'link')) do
            config = Config.new(tool_name: 'tool')
            config.set('section', 'key', 'updated')
          end

          assert(File.symlink?(link_path), 'symlink must be preserved after write')
          assert_equal(target_path, File.readlink(link_path))
          assert_includes(File.read(target_path), 'key = updated')
        end
      end

      def test_write_preserves_symlink_when_target_is_readonly
        Dir.mktmpdir do |dir|
          target_dir = File.join(dir, 'nix-store', 'tool')
          link_dir = File.join(dir, 'home', 'tool')
          FileUtils.mkdir_p(target_dir)
          FileUtils.mkdir_p(link_dir)

          target_path = File.join(target_dir, 'config')
          link_path = File.join(link_dir, 'config')
          File.write(target_path, "[section]\nkey = original\n")
          File.symlink(target_path, link_path)
          # Mirror the nix/home-manager scenario: both the store
          # directory and the target file are read-only.
          FileUtils.chmod(0o444, target_path)
          FileUtils.chmod(0o555, target_dir)

          error = with_env('XDG_CONFIG_HOME' => File.join(dir, 'home')) do
            config = Config.new(tool_name: 'tool')
            assert_raises(CLI::Kit::Config::ConfigWriteError) do
              config.set('section', 'key', 'updated')
            end
          end

          assert(
            File.symlink?(link_path),
            'symlink must NOT be replaced with a regular file when the target is read-only',
          )
          assert_equal(target_path, File.readlink(link_path))
          assert_includes(error.message, '- key = original')
          assert_includes(error.message, '+ key = updated')
        ensure
          if defined?(target_dir) && target_dir && File.directory?(target_dir)
            FileUtils.chmod(0o755, target_dir)
            FileUtils.chmod(0o644, target_path) if defined?(target_path) && target_path && File.file?(target_path)
          end
        end
      end
    end
  end
end
