# encoding: utf-8
require 'benchmark/timing'
require 'benchmark/compare'
require 'benchmark/ips/report'
require 'benchmark/ips/job'

# Performance benchmarking library
module Benchmark
  # Benchmark in iterations per second, no more guessing!
  # @see https://github.com/evanphx/benchmark-ips
  module IPS

    # Benchmark-ips Gem version.
    VERSION = "2.0.0"

    # CODENAME of current version.
    CODENAME = "Springtime Hummingbird Dance"

    # Measure code in block, each code's benchmarked result will display in
    # iteration per second with standard deviation in given time.
    # @param time [Integer] Specify how long should benchmark your code in seconds.
    # @param warmup [Integer] Specify how long should Warmup time run in seconds.
    # @return [Report]
    def ips(time=nil, warmup=nil)
      suite = nil

      sync, $stdout.sync = $stdout.sync, true

      if defined? Benchmark::Suite and Suite.current
        suite = Benchmark::Suite.current
      end

      quiet = suite && !suite.quiet?

      job = Job.new({:suite => suite,
                     :quiet => quiet
      })

      job_opts = {}
      job_opts[:time] = time unless time.nil?
      job_opts[:warmup] = warmup unless warmup.nil?

      job.config job_opts

      yield job

      $stdout.puts "Calculating -------------------------------------" unless quiet

      job.run_warmup

      $stdout.puts "-------------------------------------------------" unless quiet

      job.run

      $stdout.sync = sync

      if job.compare?
        job.run_comparison
      end

      return job.full_report
    end
  end

  extend Benchmark::IPS # make ips available as module-level method
end
