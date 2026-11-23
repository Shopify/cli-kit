require 'test_helper'
require 'timeout'

module CLI
  module Kit
    include CLI::Kit::Support::TestHelper

    class SystemTest < Minitest::Test
      module StallAfterSpawn
        class << self
          attr_accessor :seconds
        end

        def spawn(*args, **kwargs)
          pid = super
          sleep(StallAfterSpawn.seconds) if StallAfterSpawn.seconds
          pid
        end
      end
      Process.singleton_class.prepend(StallAfterSpawn)

      def test_split_partial_characters_doesnt_split_single_byte_characters
        str = 'ルビー is cool'

        assert_equal([str, ''], System.split_partial_characters(str))
      end

      def test_split_partial_characters_splits_partial_characters_with_multiple_bytes
        str = 'ルビー'.byteslice(0...-1) # => "ルビ\xE3\x83"

        data, trailing = System.split_partial_characters(str)

        assert_equal('ルビ', data)
        assert_equal(str, data + trailing)
      end

      def test_split_partial_characters_splits_partial_characters_with_a_single_byte
        str = 'ルビー'.byteslice(0...-2) # => "ルビ\xE3"

        data, trailing = System.split_partial_characters(str)

        assert_equal('ルビ', data)
        assert_equal(str, data + trailing)
      end

      def test_split_partial_characters_gives_up_without_error_for_bad_utf8
        str = "Hello\x83\x83\x83\x83\x83\x83\x83\x83"

        assert_equal([str, ''], System.split_partial_characters(str))
      end

      def test_split_partial_characters_when_ending_in_multibyte_character
        str = 'ルビ'

        assert_equal([str, ''], System.split_partial_characters(str))
      end

      def test_system_finds_system_ruby_instead_of_local_script
        CLI::Kit::System.fake('ruby', '-e', "puts 'system ruby'", allow: true)

        with_script_in_tmpdir('ruby') do |tmpdir|
          Dir.chdir(tmpdir) do
            out, stat = System.capture2('ruby', '-e', "puts 'system ruby'", env: ENV.to_h)

            assert(stat, message: 'expected command to successfully run')
            assert_equal('system ruby', out.chomp)
          end
        end
      end

      def test_system_finds_ruby_script_with_path_modifications
        CLI::Kit::System.fake('ruby', '-e', "puts 'system ruby'", allow: true)

        with_script_in_tmpdir('ruby') do |tmpdir|
          with_env('PATH' => "#{tmpdir}#{File::PATH_SEPARATOR}#{ENV["PATH"]}") do
            out, stat = System.capture2('ruby', '-e', "puts 'system ruby'", env: ENV.to_h)

            assert(stat, message: 'expected command to successfully run')
            assert_equal('from script', out.chomp)
          end
        end
      end

      def test_system_finds_ruby_script_with_path_modifications_and_single_command
        CLI::Kit::System.fake("ruby -e 'puts \"system ruby\"'", allow: true)

        with_script_in_tmpdir('ruby') do |tmpdir|
          with_env('PATH' => "#{tmpdir}#{File::PATH_SEPARATOR}#{ENV["PATH"]}") do
            out, stat = System.capture2("ruby -e 'puts \"system ruby\"'", env: ENV.to_h)

            assert(stat, message: 'expected command to successfully run')
            assert_equal('from script', out.chomp)
          end
        end
      end

      def test_system_keeps_the_output_of_a_child_that_exits_before_the_first_read
        out, err, stat = run_sh('echo out; echo err >&2; exit 3', stall_after_spawn: 0.2)

        assert_equal(3, stat.exitstatus)
        assert_equal("out\n", out)
        assert_equal("err\n", err)
      end

      def test_system_keeps_a_trailing_partial_character
        out, _, stat = run_sh("printf 'ok\\343'")

        assert_predicate(stat, :success?)
        assert_equal("ok\xE3".b, out.b)
      end

      def test_system_returns_once_the_child_exits_even_if_a_descendant_holds_its_output
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        out, _, stat = run_sh('echo started; sleep 5 &')
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

        assert_predicate(stat, :success?)
        assert_equal("started\n", out)
        assert_operator(elapsed, :<, 2.5)
      end

      def test_system_stops_reading_when_a_descendant_keeps_writing_after_the_child_exits
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        _, _, stat = Timeout.timeout(10) do
          run_sh('yes payload & exit 3') { sleep(0.001) }
        end
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

        assert_equal(3, stat.exitstatus)
        assert_operator(elapsed, :<, 5)
      end

      def test_system_does_not_wait_out_the_poll_interval_after_the_pipes_close
        started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
        _, _, stat = run_sh('exec >&- 2>&-; sleep 0.2')
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

        assert_predicate(stat, :success?)
        assert_operator(elapsed, :<, 0.9)
      end

      def test_system_returns_the_child_status_when_the_block_runs_a_command
        out, _, stat = run_sh('head -c 20000 /dev/zero; exit 3', stall_after_spawn: 0.2) do
          Kernel.system('true')
        end

        assert_equal(3, stat.exitstatus)
        assert_equal(20000, out.bytesize)
      end

      private

      def run_sh(script, stall_after_spawn: nil, &on_output)
        skip('needs a POSIX shell') if CLI::Kit::System.os == :windows

        CLI::Kit::System.fake('sh', '-c', script, allow: true)
        out = +''
        err = +''
        StallAfterSpawn.seconds = stall_after_spawn
        stat = System.system('sh', '-c', script) do |o, e|
          out << o
          err << e
          on_output&.call
        end
        [out, err, stat]
      ensure
        StallAfterSpawn.seconds = nil
      end

      def with_script_in_tmpdir(script_name)
        Dir.mktmpdir do |tmpdir|
          is_windows = CLI::Kit::System.os == :windows
          script_name += '.BAT' if is_windows

          File.open(File.join(tmpdir, script_name), 'w', 0o755) do |f|
            if is_windows
              f.write("@echo off\n")
            else
              f.write("#!/bin/sh\n")
            end
            f.write("echo from script\n")
          end
          yield tmpdir
        end
      end
    end
  end
end
