module Benchmark
  module Timing
    def self.mean(samples)
      sum = samples.inject(0) { |acc, i| acc + i }
      sum / samples.size
    end

    def self.variance(samples, m=nil)
      m ||= mean(samples)

      total = samples.inject(0) { |acc, i| acc + ((i - m) ** 2) }

      total / samples.size
    end

    def self.stddev(samples, m=nil)
      Math.sqrt variance(samples, m)
    end

    def self.resample_mean(samples, resample_times=100)
      resamples = []

      resample_times.times do
        resample = samples.map { samples[rand(samples.size)] }
        resamples << Timing.mean(resample)
      end

      resamples
    end

    def self.clean_env
      # rbx
      if GC.respond_to? :run
        GC.run(true)
      else
        GC.start
      end
    end
  end
end
