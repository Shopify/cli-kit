# typed: true
require 'cli/kit'

require 'open3'
require 'English'

module CLI
  module Kit
    module System
      SUDO_PROMPT = CLI::UI.fmt("{{info:(sudo)}} Password: ")
      class << self
        extend(T::Sig)

        # Ask for sudo access with a message explaning the need for it
        # Will make subsequent commands capable of running with sudo for a period of time
        #
        # #### Parameters
        # - `msg`: A message telling the user why sudo is needed
        #
        # #### Usage
        # `ctx.sudo_reason("We need to do a thing")`
        #
        sig { params(msg: String).void }
        def sudo_reason(msg)
          # See if sudo has a cached password
          %x(env SUDO_ASKPASS=/usr/bin/false sudo -A true)
          return if $CHILD_STATUS.success?
          CLI::UI.with_frame_color(:blue) do
            puts(CLI::UI.fmt("{{i}} #{msg}"))
          end
        end

        # Execute a command in the user's environment
        # This is meant to be largely equivalent to backticks, only with the env passed in.
        # Captures the results of the command without output to the console.
        #
        # Example:
        #   out, stat = CLI::Kit::System.capture2('ls', 'a_folder')
        sig do
          params(
            args: String, # splat of arguments ('rm dir' or 'rm', 'dir')
            sudo: T.any(T::Boolean, String), # prompt for credentials and run as root?
            env: T::Hash[String, String], # process environment with which to execute
            kwargs: T.nilable(T::Hash[Symbol, T.untyped]), # additional args to pass to Open3.capture2
          ).returns([
            String, # output (STDOUT) of the command execution
            ::Process::Status, # ask it about #success?
          ])
        end
        def capture2(*args, sudo: false, env: T.unsafe(ENV), **kwargs)
          call_open3(args, sudo, env) do |argv|
            T.unsafe(Open3).capture2(env, *argv, **kwargs)
          end
        end

        # Execute a command in the user's environment
        # This is meant to be largely equivalent to backticks, only with the env passed in.
        # Captures the results of the command without output to the console
        #
        # Example:
        #   out_and_err, stat = CLI::Kit::System.capture2e('ls', 'a_folder')
        sig do
          params(
            args: String, # splat of arguments ('rm dir' or 'rm', 'dir')
            sudo: T.any(T::Boolean, String), # prompt for credentials and run as root?
            env: T::Hash[String, String], # process environment with which to execute
            kwargs: T.nilable(T::Hash[Symbol, T.untyped]), # additional args to pass to Open3.capture2e
          ).returns([
            String, # output (STDOUT merged with STDERR) of the command execution
            ::Process::Status, # ask it about #success?
          ])
        end
        def capture2e(*args, sudo: false, env: T.unsafe(ENV), **kwargs)
          call_open3(args, sudo, env) do |argv|
            T.unsafe(Open3).capture2e(env, *argv, **kwargs)
          end
        end

        # Execute a command in the user's environment
        # This is meant to be largely equivalent to backticks, only with the env passed in.
        # Captures the results of the command without output to the console
        #
        # #### Returns
        # - `output`: STDOUT of the command execution
        # - `error`: STDERR of the command execution
        # - `status`: boolean success status of the command execution
        #
        # #### Usage
        # `out, err, stat = CLI::Kit::System.capture3('ls', 'a_folder')`
        #
        sig do
          params(
            args: String, # splat of arguments ('rm dir' or 'rm', 'dir')
            sudo: T.any(T::Boolean, String), # prompt for credentials and run as root?
            env: T::Hash[String, String], # process environment with which to execute
            kwargs: T.nilable(T::Hash[Symbol, T.untyped]), # additional args to pass to Open3.capture3
          ).returns([
            String, # STDOUT of the command execution
            String, # STDERR of the command execution
            ::Process::Status, # ask it about #success?
          ])
        end
        def capture3(*args, sudo: false, env: T.unsafe(ENV), **kwargs)
          call_open3(args, sudo, env) do |argv|
            T.unsafe(Open3).capture3(env, *argv, **kwargs)
          end
        end

        # Execute a command in the user's environment. Outputs result of the
        # command without capturing it.
        #
        # Example:
        #   stat = CLI::Kit::System.system('ls', 'a_folder')
        sig do
          params(
            args: String, # splat of arguments ('rm dir' or 'rm', 'dir')
            sudo: T.any(T::Boolean, String), # prompt for credentials and run as root?
            env: T::Hash[String, String], # process environment with which to execute
            kwargs: T.nilable(T::Hash[Symbol, T.untyped]), # additional args to pass to Process.spawn
          ).returns([
            String, # STDOUT of the command execution
            String, # STDERR of the command execution
            ::Process::Status, # ask it about #success?
          ])
        end
        def system(*args, sudo: false, env: T.unsafe(ENV), **kwargs)
          args = apply_sudo(args, sudo)
          args = resolve_path(args, env)

          out_r, out_w = IO.pipe
          err_r, err_w = IO.pipe
          in_stream = STDIN.closed? ? :close : STDIN
          spawn_kwargs = kwargs.merge(0 => in_stream, out: out_w, err: err_w)
          pid = T.unsafe(Process).spawn(env, *args, **spawn_kwargs)
          out_w.close
          err_w.close

          handlers = if block_given?
            { out_r => ->(data) { yield(data.force_encoding(Encoding::UTF_8), '') },
              err_r => ->(data) { yield('', data.force_encoding(Encoding::UTF_8)) } }
          else
            { out_r => ->(data) { STDOUT.write(data) },
              err_r => ->(data) { STDOUT.write(data) } }
          end

          previous_trailing = Hash.new('')
          loop do
            ios = [err_r, out_r].reject(&:closed?)
            break if ios.empty?

            readers, = IO.select(ios)
            readers&.each do |io|
              begin
                data, trailing = split_partial_characters(io.readpartial(4096))
                handlers[io].call(previous_trailing[io] + data)
                previous_trailing[io] = trailing
              rescue IOError
                io.close
              end
            end
          end

          Process.wait(pid)
          $CHILD_STATUS
        end

        # Split off trailing partial UTF-8 Characters. UTF-8 Multibyte characters start with a 11xxxxxx byte that tells
        # how many following bytes are part of this character, followed by some number of 10xxxxxx bytes.  This simple
        # algorithm will split off a whole trailing multi-byte character.
        sig { params(data: String).returns(T::Array[String]) }
        def split_partial_characters(data)
          last_byte = data.getbyte(-1)
          return [''] if last_byte.nil?
          return [data, ''] if (last_byte & 0b1000_0000).zero?

          # UTF-8 is up to 6 characters per rune, so we could never want to trim more than that, and we want to avoid
          # allocating an array for the whole of data with bytes
          min_bound = -[6, data.bytesize].min
          final_bytes = must_byteslice(data, min_bound..-1).bytes
          partial_character_sub_index = final_bytes.rindex { |byte| byte & 0b1100_0000 == 0b1100_0000 }
          # Bail out for non UTF-8
          return [data, ''] unless partial_character_sub_index
          partial_character_index = min_bound + partial_character_sub_index

          [must_byteslice(data, 0...partial_character_index), must_byteslice(data, partial_character_index..-1)]
        end

        private

        sig { params(data: String, range: Range).returns(String) }
        def must_byteslice(data, range)
          d = data.byteslice(range)
          raise(ArgumentError, 'requested byteslice range is not in string') if d.nil?
          d
        end

        sig do
          type_parameters(:U).params(
            args: T::Array[String],
            sudo: T.any(T::Boolean, String),
            env: T::Hash[String, String],
            blk: T.proc.params(arg0: T::Array[String]).returns(T.type_parameter(:U))
          ).returns(T.type_parameter(:U))
        end
        def call_open3(args, sudo, env, &blk)
          args = apply_sudo(args, sudo)
          args = resolve_path(args, env)
          blk.call(args)
        rescue Errno::EINTR
          raise(Errno::EINTR, "command interrupted: #{args.join(' ')}")
        end

        sig do
          params(
            args: T::Array[String],
            sudo: T.any(T::Boolean, String),
          ).returns(T::Array[String])
        end
        def apply_sudo(args, sudo)
          args.unshift('sudo', '-S', '-p', SUDO_PROMPT, '--') if sudo
          sudo_reason(sudo) if sudo.is_a?(String)
          args
        end

        # Ruby resolves the program to execute using its own PATH, but we want it to
        # use the provided one, so we ensure ruby chooses to spawn a shell, which will
        # parse our command and properly spawn our target using the provided environment.
        #
        # This is important because dev clobbers its own environment such that ruby
        # means /usr/bin/ruby, but we want it to select the ruby targeted by the active
        # project.
        #
        # See https://github.com/Shopify/dev/pull/625 for more details.
        sig { params(args: T::Array[String], env: T::Hash[String, String]).returns(T::Array[String]) }
        def resolve_path(args, env)
          raise(ArgumentError, "at least one argument is required") if args.size.zero?
          # If only one argument was provided, make sure it's interpreted by a shell.
          arg0 = args.fetch(0)
          return ["true ; " + arg0] if args.size == 1
          return args if arg0.include?('/')

          paths = env.fetch('PATH', '').split(':')
          item = paths.detect do |f|
            command_path = "#{f}/#{args.first}"
            File.executable?(command_path) && File.file?(command_path)
          end

          args[0] = "#{item}/#{args.first}" if item
          args
        end
      end
    end
  end
end
