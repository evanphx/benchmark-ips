# encoding: utf-8
require 'benchmark/timing'
require 'benchmark/compare'
require 'benchmark/ips/report'
require 'benchmark/ips/job'

module Benchmark
  module IPS
    VERSION = "2.0.0"
    CODENAME = "Springtime Hummingbird Dance"

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

  extend Benchmark::IPS
end
