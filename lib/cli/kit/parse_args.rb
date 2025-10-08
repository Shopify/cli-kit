# typed: true

module CLI
  module Kit
    module ParseArgs
      # because sorbet type-checking takes the pedantic route that module doesn't include Kernel, therefore
      # this is necessary (even tho it's ~probably fine~)
      include Kernel

      # untyped is used in two places. The interpretation of dynamic values from the provided `opts`
      # and the resulting args[:opts] is pretty broad. There seems to be minimal value in expressing a
      # tighter subset of untyped.

      #: ((Array | String) args, Hash[Symbol, Array[untyped]] opts_defn) -> Hash[Symbol, untyped]
      def parse_args(args, opts_defn)
        start_opts, parser_config = opts_defn.reduce([{}, []]) do |(ini, pcfg), (n, cfg)|
          (vals, desc, short, klass) = cfg
          (init_val, def_val) = Array(vals)

          [
            init_val.nil? ? ini : ini.merge(n => init_val),
            pcfg + [[n, short, desc, def_val, klass]],
          ]
        end

        require('optparse')

        acc_opts = {}
        prsr = OptionParser.new do |opt_p|
          parser_config.each do |(n, short, desc, def_val, klass)|
            (_, mark) = short.split(' ')
            long = "--#{n.to_s.tr("_", "-")}" + (mark.nil? ? '' : " #{mark}")
            opt_args = klass.nil? ? [short, long, desc] : [short, long, klass, desc]

            unsafe_opt_p = opt_p #: as untyped
            unsafe_opt_p.on(*opt_args) do |v|
              acc_opts[n] = if acc_opts.key?(n)
                Array(acc_opts[n]) + Array(v || def_val)
              else
                v || def_val
              end
            end
          end
        end

        arg_v = (args.is_a?(Array) ? args : args.strip.split(/\s+/)).map(&:strip)
        sub = prsr.parse(arg_v)

        { opts: start_opts.merge(acc_opts) }.tap do |a|
          a[:sub] = sub if sub
        end
      end
    end
  end
end
