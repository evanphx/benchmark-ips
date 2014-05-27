# encoding: utf-8
require 'benchmark/timing'
require 'benchmark/compare'
require 'benchmark/ips_report'
require 'benchmark/ips_job'

module Benchmark
  module IPS
    VERSION = "1.1.0"

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

      job.run_warmup

      $stdout.puts "-------------------------------------------------" unless quiet

      job.run

      $stdout.sync = sync

      if job.compare?
        Benchmark.compare(*job.reports.list)
      end

      return job.reports.list
    end
  end

  extend Benchmark::IPS
end
