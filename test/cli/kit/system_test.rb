require 'test_helper'
require 'timeout'

module CLI
  module Kit
    include CLI::Kit::Support::TestHelper

    class SystemTest < Minitest::Test
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
        out, _, stat = run_sh('sleep 30 & echo $!')
        elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started

        assert_predicate(stat, :success?)
        assert_match(/\A\d+\n\z/, out)
        assert_operator(elapsed, :<, 10)
      ensure
        begin
          Process.kill('TERM', out.to_i) if out&.match?(/\A\d+\n\z/)
        rescue Errno::ESRCH
          nil
        end
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
        _, _, stat = run_sh('exec >&- 2>&-; sleep 0.05')
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

      def test_system_closes_its_pipes_and_reaps_the_child_when_the_block_raises
        fds_before = open_fd_count
        child = nil
        assert_raises(RuntimeError) do
          run_sh('echo $$; sleep 0.2') do |o, _|
            child = o.to_i
            raise 'handler failed'
          end
        end

        assert_equal(fds_before, open_fd_count)
        assert(reaped_within?(child, 5), "child #{child} was left as a zombie")
      end

      def test_system_raises_an_io_error_from_the_block_while_the_child_runs
        assert_raises(IOError) do
          run_sh('echo out; sleep 0.2') { raise IOError, 'handler failed' }
        end
      end

      def test_system_raises_an_io_error_from_the_block_after_the_child_exits
        assert_raises(IOError) do
          run_sh('echo out', stall_after_spawn: 0.2) { raise IOError, 'handler failed' }
        end
      end

      private

      def open_fd_count
        Dir.children('/dev/fd').size
      end

      # kill(0) still succeeds on a zombie, so ESRCH means the child was reaped.
      def reaped_within?(pid, seconds)
        deadline = Process.clock_gettime(Process::CLOCK_MONOTONIC) + seconds
        loop do
          Process.kill(0, pid)
          return false if Process.clock_gettime(Process::CLOCK_MONOTONIC) > deadline

          sleep(0.05)
        end
      rescue Errno::ESRCH
        true
      end

      def run_sh(script, stall_after_spawn: nil, &on_output)
        skip('needs a POSIX shell') if CLI::Kit::System.os == :windows

        CLI::Kit::System.fake('sh', '-c', script, allow: true)
        out = +''
        err = +''
        stat = with_stall_after_spawn(stall_after_spawn) do
          System.system('sh', '-c', script) do |o, e|
            out << o
            err << e
            on_output&.call(o, e)
          end
        end
        [out, err, stat]
      end

      # Stands in for the calling thread losing the GVL between spawn and its first read.
      def with_stall_after_spawn(seconds)
        return yield unless seconds

        Process.singleton_class.class_eval do
          alias_method(:__spawn_without_stall, :spawn)
          define_method(:spawn) do |*args, **kwargs|
            __spawn_without_stall(*args, **kwargs).tap { sleep(seconds) }
          end
        end
        begin
          yield
        ensure
          Process.singleton_class.class_eval do
            alias_method(:spawn, :__spawn_without_stall)
            remove_method(:__spawn_without_stall)
          end
        end
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
