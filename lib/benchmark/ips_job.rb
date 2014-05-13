module Benchmark
  class IPSJob

    VERSION = "1.1.0"

    MICROSECONDS_PER_100MS = 100_000
    MICROSECONDS_PER_SECOND = 1_000_000

    class Entry
      def initialize(label, action)
        @label = label

        if action.kind_of? String
          compile action
          @action = self
          @as_action = true
        else
          unless action.respond_to? :call
            raise ArgumentError, "invalid action, must respond to #call"
          end

          @action = action

          if action.respond_to? :arity and action.arity > 0
            @call_loop = true
          else
            @call_loop = false
          end

          @as_action = false
        end
      end

      attr_reader :label, :action

      def label_rjust
        if @label.size > 20
          "#{item.label}\n#{' ' * 20}"
        else
          @label.rjust(20)
        end
      end

      def as_action?
        @as_action
      end

      def call_times(times)
        return @action.call(times) if @call_loop

        act = @action

        i = 0
        while i < times
          act.call
          i += 1
        end
      end

      def compile(str)
        m = (class << self; self; end)
        code = <<-CODE
          def call_times(__total);
            __i = 0
            while __i < __total
              #{str};
              __i += 1
            end
          end
        CODE
        m.class_eval code
      end
    end

    attr_accessor :warmup, :time
    attr_reader :timing, :reports

    def initialize opts={}
      @suite = opts[:suite] || nil
      @quiet = opts[:quiet] || false
      @list = []
      @compare = false

      @timing = {}
      @reports = []

      # defaults
      @warmup = 2
      @time = 5
    end

    def config opts
      @warmup = opts[:warmup] if opts[:warmup]
      @time = opts[:time] if opts[:time]
    end

    # An array of 2-element arrays, consisting of label and block pairs.
    attr_reader :list

    # Boolean determining whether to run comparison utility
    attr_reader :compare

    def compare?
      @compare
    end

    def compare!
      @compare = true
    end

    #
    # Registers the given label and block pair in the job list.
    #
    def item(label="", str=nil, &blk) # :yield:
      if blk and str
        raise ArgumentError, "specify a block and a str, but not both"
      end

      action = str || blk
      raise ArgumentError, "no block or string" unless action

      @list.push Entry.new(label, action)
      self
    end
    alias_method :report, :item

    # calculate the cycles needed to run for approx 100ms
    # given the number of iterations to run the given time
    def cycles_per_100ms time_msec, iters
      cycles = ((MICROSECONDS_PER_100MS / time_msec) * iters).to_i
      cycles = 1 if cycles <= 0
      cycles
    end

    # calculate the difference in microseconds between
    # before and after
    def time_us before, after
      (after.to_f - before.to_f) * MICROSECONDS_PER_SECOND
    end

    # calculate the interations per second given the number
    # of cycles run and the time in microseconds that elapsed
    def iterations_per_sec cycles, time_us
      MICROSECONDS_PER_SECOND * (cycles.to_f / time_us.to_f)
    end

    def run_warmup
      @timing = {}
      @list.each do |item|
        @suite.warming item.label, @warmup if @suite

        unless @quiet
          $stdout.printf item.label_rjust
        end

        Timing.clean_env

        before = Time.now
        target = Time.now + @warmup

        warmup_iter = 0

        while Time.now < target
          item.call_times(1)
          warmup_iter += 1
        end

        after = Time.now

        warmup_time_us = time_us before, after

        @timing[item] = cycles_per_100ms warmup_time_us, warmup_iter

        $stdout.printf "%10d i/100ms\n", @timing[item] unless @quiet

        @suite.warmup_stats warmup_time_us, @timing[item] if @suite
      end
    end

    def run
      @reports = []

      @list.each do |item|
        @suite.running item.label, @time if @suite

        unless @quiet
          $stdout.print item.label_rjust
        end

        Timing.clean_env

        iter = 0

        target = Time.now + @time

        measurements_us = []

        # running this number of cycles should take around 100ms
        cycles = @timing[item]

        while Time.now < target
          before = Time.now
          item.call_times cycles
          after = Time.now

          # If for some reason the timing said this took no time (O_o)
          # then ignore the iteration entirely and start another.
          #
          iter_us = time_us before, after
          next if iter_us <= 0.0

          iter += cycles

          measurements_us << iter_us
        end

        measured_us = measurements_us.inject(0) { |a,i| a + i }

        all_ips = measurements_us.map { |time_us|
          iterations_per_sec cycles, time_us
        }

        avg_ips = Timing.mean(all_ips)
        sd_ips =  Timing.stddev(all_ips).round

        rep = create_report(item, measured_us, iter, avg_ips, sd_ips, cycles)

        $stdout.puts " #{rep.body}" unless @quiet

        @suite.add_report rep, caller(1).first if @suite

        @reports << rep
      end
    end

    def create_report(item, measured_us, iter, avg_ips, sd_ips, cycles)
      Benchmark::IPSReport.new(item.label, measured_us, iter, avg_ips, sd_ips, cycles)
    end

  end
end
