module Benchmark
  # Perform caclulations on Timing results.
  module Timing
    # Microseconds per second.
    MICROSECONDS_PER_SECOND = 1_000_000

    # Calculate (arithmetic) mean of given samples.
    # @param [Array] samples Samples to calculate mean.
    # @return [Float] Mean of given samples.
    def self.mean(samples)
      sum = samples.inject(0) { |acc, i| acc + i }
      sum / samples.size
    end

    # Calculate variance of given samples.
    # @param [Float] m Optional mean (Expected value).
    # @return [Float] Variance of given samples.
    def self.variance(samples, m=nil)
      m ||= mean(samples)

      total = samples.inject(0) { |acc, i| acc + ((i - m) ** 2) }

      total / samples.size
    end

    # Calculate standard deviation of given samples.
    # @param [Array] samples Samples to calculate standard deviation.
    # @param [Float] m Optional mean (Expected value).
    # @return [Float] standard deviation of given samples.
    def self.stddev(samples, m=nil)
      Math.sqrt variance(samples, m)
    end

    # Resample mean of given samples.
    # @param [Integer] resample_times Resample times, defaults to 100.
    # @return [Array] Resampled samples.
    def self.resample_mean(samples, resample_times=100)
      resamples = []

      resample_times.times do
        resample = samples.map { samples[rand(samples.size)] }
        resamples << Timing.mean(resample)
      end

      resamples
    end

    # Recycle used objects by starting Garbage Collector.
    def self.clean_env
      # rbx
      if GC.respond_to? :run
        GC.run(true)
      else
        GC.start
      end
    end

    begin
      Process.clock_gettime Process::CLOCK_MONOTONIC, :float_microsecond

      # Get a time that represents microseconds from some offset (which is not
      # necessarily the epoch!!!!)
      def self.now_us
        Process.clock_gettime Process::CLOCK_MONOTONIC, :float_microsecond
      end
    rescue NameError
      # Get a time that represents microseconds from some offset (which is not
      # necessarily the epoch!!!!)
      def self.now_us
        Time.now.to_f * 1_0000
      end
    end
  end
end
