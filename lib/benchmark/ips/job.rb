module Benchmark
  module IPS
    # Benchmark jobs.
    class Job
      # Microseconds per 100 millisecond.
      MICROSECONDS_PER_100MS = 100_000
      # Microseconds per second.
      MICROSECONDS_PER_SECOND = Timing::MICROSECONDS_PER_SECOND
      # The percentage of the expected runtime to allow
      # before reporting a weird runtime
      MAX_TIME_SKEW = 0.05

      # Two-element arrays, consisting of label and block pairs.
      # @return [Array<Entry>] list of entries
      attr_reader :list

      # Determining whether to hold results between Ruby invocations
      # @return [Boolean]
      attr_accessor :hold

      # Report object containing information about the run.
      # @return [Report] the report object.
      attr_reader :full_report

      # Storing Iterations in time period.
      # @return [Hash]
      attr_reader :timing

      # Warmup time setter and getter (in seconds).
      # @return [Integer]
      attr_accessor :warmup

      # Calculation time setter and getter (in seconds).
      # @return [Integer]
      attr_accessor :time

      # Warmup and calculation iterations.
      # @return [Integer]
      attr_accessor :iterations

      # Statistics model.
      # @return [Object]
      attr_accessor :stats

      # Confidence.
      # @return [Integer]
      attr_accessor :confidence

      # Helper Modules
      # @return [Hash{Symbol=>Object}] Instance of helper class implementing `run`
      attr_accessor :helpers

      # Instantiate the Benchmark::IPS::Job.
      # @option opts [Benchmark::Suite] (nil) :suite Specify Benchmark::Suite.
      # @option opts [Boolean] (false) :quiet Suppress the printing of information.
      def initialize opts={}
        @suite = opts[:suite] || nil
        @stdout = opts[:quiet] ? nil : StdoutReport.new
        @list = []
        @run_single = false
        @helpers = {}
        @held_path = nil
        @held_results = nil

        @timing = Hash.new 1 # default to 1 in case warmup isn't run
        @full_report = Report.new

        # Default warmup and calculation time in seconds.
        @warmup = 2
        @time = 5
        @iterations = 1

        # Default statistical model
        @stats = :sd
        @confidence = 95
      end

      # Job configuration options, set +@warmup+ and +@time+.
      # @option opts [Integer] :warmup Warmup time.
      # @option opts [Integer] :time Calculation time.
      # @option iterations [Integer] :time Warmup and calculation iterations.
      def config opts
        @warmup = opts[:warmup] if opts[:warmup]
        @time = opts[:time] if opts[:time]
        @suite = opts[:suite] if opts[:suite]
        @iterations = opts[:iterations] if opts[:iterations]
        @stats = opts[:stats] if opts[:stats]
        @confidence = opts[:confidence] if opts[:confidence]
      end

      # Run comparison utility.
      def compare!
        require 'benchmark/compare'
        add_helper :compare, Benchmark::Compare.new
      end

      # Determining whether to run comparison utility.
      # @param [Boolean] value true if needs to run compare.
      def compare= value
        value ? compare! : @helpers.delete(:compare)
      end

      # Return true if results are held while multiple Ruby invocations
      # @return [Boolean] Need to hold results between multiple Ruby invocations?
      def hold?
        !!@held_path
      end

      # Hold after each iteration.
      # @param held_path [String] File name to store hold file.
      def hold!(held_path)
        @held_path = held_path
        @run_single = true
      end

      # Save interim results. Similar to hold, but all reports are run
      # The report label must change for each invocation.
      # One way to achieve this is to include the version in the label.
      # @param held_path [String] File name to store hold file.
      def save!(held_path)
        @held_path = held_path
        @run_single = false
      end

      # Return true if items are to be run one at a time.
      # For the traditional hold, this is true
      # @return [Boolean] Run just a single item?
      def run_single?
        @run_single
      end

      # Generate json to given path, defaults to "data.json".
      def json!(path="data.json")
        require 'benchmark/ips/json_report'
        add_helper :json, Benchmark::IPS::JsonReport.new(path)
      end

      # Registers the given label and block pair in the job list.
      # @param label [String] Label of benchmarked code.
      # @param str [String] Code to be benchmarked.
      # @param blk [Proc] Code to be benchmarked.
      # @raise [ArgumentError] Raises if str and blk are both present.
      # @raise [ArgumentError] Raises if str and blk are both absent.
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

      # Calculate the cycles needed to run for approx 100ms,
      # given the number of iterations to run the given time.
      # @param [Float] time_msec Each iteration's time in ms.
      # @param [Integer] iters Iterations.
      # @return [Integer] Cycles per 100ms.
      def cycles_per_100ms time_msec, iters
        cycles = ((MICROSECONDS_PER_100MS / time_msec) * iters).to_i
        cycles <= 0 ? 1 : cycles
      end

      # Calculate the time difference of before and after in microseconds.
      # @param [Time] before time.
      # @param [Time] after time.
      # @return [Float] Time difference of before and after.
      def time_us before, after
        (after.to_f - before.to_f) * MICROSECONDS_PER_SECOND
      end

      # Calculate the interations per second given the number
      # of cycles run and the time in microseconds that elapsed.
      # @param [Integer] cycles Cycles.
      # @param [Integer] time_us Time in microsecond.
      # @return [Float] Iteration per second.
      def iterations_per_sec cycles, time_us
        MICROSECONDS_PER_SECOND * (cycles.to_f / time_us.to_f)
      end

      def load_held_results
        return unless @held_path && File.exist?(@held_path)
        require "json"
        @held_results = {}
        JSON.load(IO.read(@held_path)).each do |result|
          @held_results[result['item']] = result
          create_report(result['item'], result['measured_us'], result['iter'],
                        create_stats(result['samples']), result['cycles'])
        end
      end

      def save_held_results
        return unless @held_path
        require "json"
        data = full_report.entries.map { |e|
          {
            'item' => e.label,
            'measured_us' => e.microseconds,
            'iter' => e.iterations,
            'samples' => e.samples,
            'cycles' => e.measurement_cycle
          }
        }
        IO.write(@held_path, JSON.generate(data) << "\n")
      end

      def all_results_have_been_run?
        @full_report.entries.size == @list.size
      end

      def clear_held_results
        File.delete @held_path if File.exist?(@held_path)
      end

      def add_helper(name, helper)
        @helpers[name] = helper
      end

      def pre_run
        load_held_results if hold? && held_results?

        if ENV['SHARE'] || ENV['SHARE_URL']
          require 'benchmark/ips/share'
          add_helper :share, Share.new(!!@helpers[:compare])
        end
      end

      def post_run
        @helpers.values.each { |helper| helper.post_run(full_report) }
      end

      def run
        if @warmup && @warmup != 0 then
          @stdout.start_warming if @stdout
          @iterations.times do
            run_warmup
          end
        end

        @stdout.start_running if @stdout

        @iterations.times do |n|
          run_benchmark
        end

        @stdout.footer if @stdout
      end

      # Run warmup.
      def run_warmup
        @list.each do |item|
          next if run_single? && @held_results && @held_results.key?(item.label)

          @suite.warming item.label, @warmup if @suite
          @stdout.warming item.label, @warmup if @stdout

          Timing.clean_env

          before = Timing.now
          target = Timing.add_second before, @warmup

          warmup_iter = 0

          while Timing.now < target
            item.call_times(1)
            warmup_iter += 1
          end

          after = Timing.now

          warmup_time_us = Timing.time_us(before, after)

          @timing[item] = cycles_per_100ms warmup_time_us, warmup_iter

          @stdout.warmup_stats warmup_time_us, @timing[item] if @stdout
          @suite.warmup_stats warmup_time_us, @timing[item] if @suite

          break if run_single?
        end
      end

      # Run calculation.
      def run_benchmark
        @list.each do |item|
          next if run_single? && @held_results && @held_results.key?(item.label)

          @suite.running item.label, @time if @suite
          @stdout.running item.label, @time if @stdout

          Timing.clean_env

          iter = 0

          measurements_us = []

          # Running this number of cycles should take around 100ms.
          cycles = @timing[item]

          target = Timing.add_second Timing.now, @time

          while (before = Timing.now) < target
            item.call_times cycles
            after = Timing.now

            # If for some reason the timing said this took no time (O_o)
            # then ignore the iteration entirely and start another.
            iter_us = Timing.time_us before, after
            next if iter_us <= 0.0

            iter += cycles

            measurements_us << iter_us
          end

          final_time = before

          measured_us = measurements_us.inject(:+)

          samples = measurements_us.map { |time_us|
            iterations_per_sec cycles, time_us
          }

          rep = create_report(item.label, measured_us, iter, create_stats(samples), cycles)

          if (final_time - target).abs >= (@time.to_f * MAX_TIME_SKEW)
            rep.show_total_time!
          end

          @stdout.add_report rep, caller(1).first if @stdout
          @suite.add_report rep, caller(1).first if @suite

          break if run_single?
        end
      end

      def create_stats(samples)
        case @stats
          when :sd
            Stats::SD.new(samples)
          when :bootstrap
            Stats::Bootstrap.new(samples, @confidence)
          else
            raise "unknown stats #{@stats}"
        end
      end

      # Create report by add entry to +@full_report+.
      # @param label [String] Report item label.
      # @param measured_us [Integer] Measured time in microsecond.
      # @param iter [Integer] Iterations.
      # @param samples [Array<Float>] Sampled iterations per second.
      # @param cycles [Integer] Number of Cycles.
      # @return [Report::Entry] Entry with data.
      def create_report(label, measured_us, iter, samples, cycles)
        @full_report.add_entry label, measured_us, iter, samples, cycles
      end
    end
  end
end
