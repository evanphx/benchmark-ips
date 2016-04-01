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

      # Determining whether to run comparison utility.
      # @return [Boolean] true if needs to run compare.
      attr_reader :compare

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

      # Instantiate the Benchmark::IPS::Job.
      # @option opts [Benchmark::Suite] (nil) :suite Specify Benchmark::Suite.
      # @option opts [Boolean] (false) :quiet Suppress the printing of information.
      def initialize opts={}
        @suite = opts[:suite] || nil
        @stdout = opts[:quiet] ? nil : StdoutReport.new
        @list = []
        @compare = false
        @json_path = false
        @held_path = nil
        @held_results = nil

        @timing = {}
        @full_report = Report.new

        # Default warmup and calculation time in seconds.
        @warmup = 2
        @time = 5
        @iterations = 1
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
      end

      # Return true if job needs to be compared.
      # @return [Boolean] Need to compare?
      def compare?
        @compare
      end

      # Set @compare to true.
      def compare!
        @compare = true
      end

      # Return true if results are held while multiple Ruby invocations
      # @return [Boolean] Need to hold results between multiple Ruby invocations?
      def hold?
        !!@held_path
      end

      # Set @hold to true.
      def hold!(held_path)
        @held_path = held_path
      end

      # Return true if job needs to generate json.
      # @return [Boolean] Need to generate json?
      def json?
        !!@json_path
      end

      # Set @json_path to given path, defaults to "data.json".
      def json!(path="data.json")
        @json_path = path
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
        cycles = 1 if cycles <= 0
        cycles
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
      
      def held_results?
        File.exist?(@held_path)
      end
      
      def load_held_results
        require "json"
        @held_results = Hash[File.open(@held_path).map { |line|
          result = JSON.parse(line)
          [result['item'], result]
        }]
      end
      
      def run
        @stdout.start_warming if @stdout
        @iterations.times do
          run_warmup
        end
        
        @stdout.start_running if @stdout
        
        held = nil
        
        @iterations.times do |n|
          held = run_benchmark
        end
        
        if held
          puts
          puts 'Pausing here -- run Ruby again to measure the next benchmark...'
        end
      end

      # Run warmup.
      def run_warmup
        @list.each do |item|
          next if hold? && @held_results && @held_results.key?(item.label)
          
          @suite.warming item.label, @warmup if @suite
          @stdout.warming item.label, @warmup if @stdout

          Timing.clean_env

          before = Timing.now_us
          target = before + (@warmup * MICROSECONDS_PER_SECOND)

          warmup_iter = 0

          while Timing.now_us < target
            item.call_times(1)
            warmup_iter += 1
          end

          after = Timing.now_us

          warmup_time_us = after - before

          @timing[item] = cycles_per_100ms warmup_time_us, warmup_iter

          @stdout.warmup_stats warmup_time_us, @timing[item] if @stdout
          @suite.warmup_stats warmup_time_us, @timing[item] if @suite
          
          break if hold?
        end
      end

      # Run calculation.
      def run_benchmark
        @list.each do |item|
          if hold? && @held_results && @held_results.key?(item.label)
           result = @held_results[item.label]
            create_report(item.label, result['measured_us'], result['iter'],
              result['avg_ips'], result['sd_ips'], result['cycles'])
            next
          end
          
          @suite.running item.label, @time if @suite
          @stdout.running item.label, @time if @stdout

          Timing.clean_env

          iter = 0

          measurements_us = []

          # Running this number of cycles should take around 100ms.
          cycles = @timing[item]

          target = Timing.now_us + (@time * MICROSECONDS_PER_SECOND)
          
          while Timing.now_us < target
            before = Timing.now_us
            item.call_times cycles
            after = Timing.now_us

            # If for some reason the timing said this took no time (O_o)
            # then ignore the iteration entirely and start another.
            iter_us = after - before
            next if iter_us <= 0.0

            iter += cycles

            measurements_us << iter_us
          end

          final_time = Timing.now_us

          measured_us = measurements_us.inject(0) { |a,i| a + i }

          all_ips = measurements_us.map { |time_us|
            iterations_per_sec cycles, time_us
          }

          avg_ips = Timing.mean(all_ips)
          sd_ips =  Timing.stddev(all_ips, avg_ips).round

          rep = create_report(item.label, measured_us, iter, avg_ips, sd_ips, cycles)

          if (final_time - target).abs >= (@time.to_f * MAX_TIME_SKEW)
            rep.show_total_time!
          end

          @stdout.add_report rep, caller(1).first if @stdout
          @suite.add_report rep, caller(1).first if @suite
          
          if hold? && item != @list.last
            File.open @held_path, "a" do |f|
              require "json"
              f.write JSON.generate({
                :item => item.label,
                :measured_us => measured_us,
                :iter => iter,
                :avg_ips => avg_ips,
                :sd_ips => sd_ips,
                :cycles => cycles
              })
              f.write "\n"
            end
            
            return true
          end
        end
        
        if hold? && @full_report.entries.size == @list.size
          File.delete @held_path if File.exist?(@held_path)
        end
        
        false
      end

      # Run comparison of entries in +@full_report+.
      def run_comparison
        @full_report.run_comparison if compare?
      end

      # Generate json from +@full_report+.
      def generate_json
        @full_report.generate_json @json_path if json?
      end

      # Create report by add entry to +@full_report+.
      # @param label [String] Report item label.
      # @param measured_us [Integer] Measured time in microsecond.
      # @param iter [Integer] Iterations.
      # @param avg_ips [Float] Average iterations per second.
      # @param sd_ips [Float] Standard deviation iterations per second.
      # @param cycles [Integer] Number of Cycles.
      # @return [Report::Entry] Entry with data.
      def create_report(label, measured_us, iter, avg_ips, sd_ips, cycles)
        @full_report.add_entry label, measured_us, iter, avg_ips, sd_ips, cycles
      end
    end
  end
end
