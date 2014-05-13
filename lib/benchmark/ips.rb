# encoding: utf-8
require 'benchmark/timing'
require 'benchmark/compare'
require 'benchmark/ips_job'

module Benchmark
  class IPSReport

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

  module IPS
    VERSION = Benchmark::IPSJob::VERSION

    def ips(time=nil, warmup=nil)
      suite = nil

      sync, $stdout.sync = $stdout.sync, true

      if defined? Benchmark::Suite and Suite.current
        suite = Benchmark::Suite.current
      end

      quiet = suite && !suite.quiet?

      job = IPSJob.new({:suite => suite,
                        :quiet => quiet
      })

      job_opts = {}
      job_opts[:time] = time unless time.nil?
      job_opts[:warmup] = warmup unless warmup.nil?

      job.config job_opts

      yield job

      $stdout.puts "Calculating -------------------------------------" unless quiet

      timing = job.warmup

      $stdout.puts "-------------------------------------------------" unless quiet

      reports = job.run timing

      $stdout.sync = sync

      if job.compare?
        Benchmark.compare(*reports)
      end

      return reports
    end
  end

  extend Benchmark::IPS
end
