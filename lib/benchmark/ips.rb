# encoding: utf-8
require 'benchmark/timing'
require 'benchmark/compare'

module Benchmark

  class IPSReport
    VERSION = "1.1.0"

    def initialize(label, us, iters, ips, ips_sd, cycles)
      @label = label
      @microseconds = us
      @iterations = iters
      @ips = ips
      @ips_sd = ips_sd
      @measurement_cycle = cycles
    end

    attr_reader :label, :microseconds, :iterations, :ips, :ips_sd, :measurement_cycle

    def seconds
      @microseconds.to_f / 1_000_000.0
    end

    def stddev_percentage
      100.0 * (@ips_sd.to_f / @ips.to_f)
    end

    alias_method :runtime, :seconds

    def body
      left = "%10.1f (±%.1f%%) i/s" % [ips, stddev_percentage]
      left.ljust(20) + (" - %10d in %10.6fs" % [@iterations, runtime])
    end

    def header
      @label.rjust(20)
    end

    def to_s
      "#{header} #{body}"
    end

    def display
      $stdout.puts to_s
    end
  end

  class IPSJob
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

    def initialize
      @list = []
      @compare = false
    end

    attr_reader :compare

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

    # An array of 2-element arrays, consisting of label and block pairs.
    attr_reader :list
  end

  def ips(time=5, warmup=2)
    suite = nil

    sync, $stdout.sync = $stdout.sync, true

    if defined? Benchmark::Suite and Suite.current
      suite = Benchmark::Suite.current
    end

    quiet = suite && !suite.quiet?

    job = IPSJob.new
    yield job

    reports = []

    timing = {}

    $stdout.puts "Calculating -------------------------------------" unless quiet

    job.list.each do |item|
      suite.warming item.label, warmup if suite

      Timing.clean_env

      unless quiet
        if item.label.size > 20
          $stdout.print "#{item.label}\n#{' ' * 20}"
        else
          $stdout.print item.label.rjust(20)
        end
      end

      before = Time.now
      target = Time.now + warmup

      warmup_iter = 0

      while Time.now < target
        item.call_times(1)
        warmup_iter += 1
      end

      after = Time.now

      warmup_time = (after.to_f - before.to_f) * 1_000_000.0

      # calculate the time to run approx 100ms
      
      cycles_per_100ms = ((100_000 / warmup_time) * warmup_iter).to_i
      cycles_per_100ms = 1 if cycles_per_100ms <= 0

      timing[item] = cycles_per_100ms

      $stdout.printf "%10d i/100ms\n", cycles_per_100ms unless quiet

      suite.warmup_stats warmup_time, cycles_per_100ms if suite
    end

    $stdout.puts "-------------------------------------------------" unless quiet

    job.list.each do |item|
      unless quiet
        if item.label.size > 20
          $stdout.print "#{item.label}\n#{' ' * 20}"
        else
          $stdout.print item.label.rjust(20)
        end
      end

      Timing.clean_env

      suite.running item.label, time if suite

      iter = 0

      target = Time.now + time

      measurements = []

      cycles_per_100ms = timing[item]

      while Time.now < target
        before = Time.now
        item.call_times cycles_per_100ms
        after = Time.now

        # If for some reason the timing said this too no time (O_o)
        # then ignore the iteration entirely and start another.
        #
        m = ((after.to_f - before.to_f) * 1_000_000.0)
        next if m <= 0.0

        iter += cycles_per_100ms

        measurements << m
      end

      measured_us = measurements.inject(0) { |a,i| a + i }

      seconds = measured_us.to_f / 1_000_000.0

      all_ips = measurements.map { |i| cycles_per_100ms.to_f / (i.to_f / 1_000_000) }

      avg_ips = Timing.mean(all_ips)
      sd_ips =  Timing.stddev(all_ips).round

      rep = IPSReport.new(item.label, measured_us, iter, avg_ips, sd_ips, cycles_per_100ms)

      $stdout.puts " #{rep.body}" unless quiet

      suite.add_report rep, caller(1).first if suite

      reports << rep
    end

    $stdout.sync = sync

    if job.compare
      Benchmark.compare(*reports)
    end

    return reports
  end


  module_function :ips
end
