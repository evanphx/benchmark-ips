# encoding: utf-8
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
end
