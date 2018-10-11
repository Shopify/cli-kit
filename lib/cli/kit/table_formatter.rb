require 'cli/kit'
require 'optionparser'

module CLI
  module Kit
    # TableFormatter should be used when you want to print tabular data.
    #
    # First, a usage example:
    #
    #     tf = TableFormatter.new(:pid, :ppid, :cmd)
    #     tfe = Struct.new(:pid, :ppid, :cmd)
    #     tf << tfe.new(1, 0, 'init')
    #     tf << tfe.new(2, 0, 'nginx')
    #     tf << tfe.new(4001, 0, 'nginx-worker')
    #     tf.parse_options(*ARGV)
    #     tf.render
    #
    # This will print:
    #
    #     PID   PPID  CMD
    #     1     0     init
    #     2     1     nginx
    #     4001  2     nginx-worker
    #
    # Note that the parse_options line supports -o (to select a subset of
    # columns) and -H (to prevent printing the header row). If ARGV was %w(-o
    # pid,ppid -H), the output would be:
    #
    #     1
    #     2
    #     4001
    #
    # In some cases, you already have an OptionParser, and don't want to use
    # this one. In those cases:
    #
    #
    #     tf = TableFormatter.new(:pid, :cmd, ppid: "parent")
    #
    #     myparser = OptionParser.new do |opts|
    #       opts.on('--other', 'whatever') { |*| }
    #       tf.add_options(opts)
    #     end
    #     myparser.parse!(ARGV)
    #     # ...
    #
    # This correctly sets the relevant options in the TableFormatter instance.
    #
    # Note that `TableFormatter#<<` doesn't take an Array; it takes an object
    # which must support a method for each column. In our examples, we use a
    # `Struct` to implement these, but if one or more of your columns is
    # expensive to generate and unlikely to be printed, this provides you an
    # easy way to lazy-generate it.
    #
    class TableFormatter
      # Instantiate a new `TableFormatter`, with a list of supported columns.
      # If `default` is provided, it will determine which columns are printed
      # by default, e.g.:
      #
      #     TableFormatter.new(:pid, :ppid, :cmd, default: [:pid, :ppid])
      #
      # In this case, only the pid and ppid columns will be printed by default,
      # but cmd will be available for selection with -o.
      def initialize(*columns, default: nil)
        @columns       = columns
        @rows          = []
        @print_columns = default || @columns.dup
        @print_header  = true
      end

      # add the -o and -H options to an `OptionParser` instance. Normally, you
      # will only need to call `parse_options`, but `add_options` is useful if
      # you also want to support other options that `TableFormatter` doesn't
      # know or care about.
      def add_options(opt_parser)
        opt_parser.on(
          '-oCOLUMNS', '--output=COLUMNS',
          'print only certain comma-separated columns, e.g. "pid,ppid"',
        ) do |v|
          cols = v.split(',').map(&:to_sym)
          extra_cols = cols - @columns
          if extra_cols.any?
            raise(Dev::Abort, "invalid column: #{extra_cols.join(', ')}")
          end
          @print_columns = cols
        end

        opt_parser.on('-H', '--no-header', "don't print the header row") do
          @print_header = false
        end
      end

      # Add a row to the table. The object passed must support each column as a
      # method.
      def <<(obj)
        @rows << obj
      end

      # Parse command-line options -o and -H, storing the result internally to the TableFormatter.
      def parse_options(*argv)
        opt_parser = OptionParser.new { |opts| add_options(opts) }
        opt_parser.parse!(argv)
        argv
      end

      # Having `<<`'d all the data, render the formatted table to output
      # (`to`). This is written in a slightly over-factored way in case it's
      # useful to override any part.
      def render(to: STDOUT, columns: @print_columns, header: @print_header)
        out = build_header(columns: columns, header: header)
        @rows.each { |row| out << build_row(row, columns: columns) }
        widths = calculate_widths(out)
        fmtstr = build_fmtstr(widths)
        write_output(fmtstr, out, to)
      end

      private

      def build_header(columns:, header:)
        if header
          [columns.map { |col| col.to_s.upcase }]
        else
          []
        end
      end

      def build_row(row_obj, columns:)
        columns.map { |col| row_obj.send(col).to_s }
      end

      def calculate_widths(out)
        widths = []

        out.each do |row|
          row.each.with_index do |cell, col_index|
            w = width(cell.to_s)
            curr = widths[col_index]
            widths[col_index] = w if curr.nil? || w > curr
          end
        end

        widths
      end

      def build_fmtstr(widths)
        widths.map.with_index do |w, i|
          i == widths.size - 1 ? "%s\n" : "%-#{w}s"
        end.join('  ')
      end

      def write_output(fmtstr, out, to)
        out.each do |row|
          to.write(format(fmtstr, *row))
        end
      end

      def width(str)
        str.size
      end
    end
  end
end
