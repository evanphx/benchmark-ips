module Benchmark
  module IPS
    module Stats

      class Bootstrap

        attr_reader :data

        def initialize(samples, confidence)
          require 'kalibera'
          @iterations = 10_000
          @confidence = (confidence / 100.0).to_s
          @data = Kalibera::Data.new({[0] => samples}, [1, samples.size])
          interval = @data.bootstrap_confidence_interval(@iterations, @confidence)
          @median = interval.median
          @error = interval.error
        end

        def central_tendency
          @median
        end

        def error
          @error
        end

        def slowdown(baseline)
          low, slowdown, high = baseline.data.bootstrap_quotient(@data, @iterations, @confidence)
          error = Timing.mean([slowdown - low, high - slowdown])
          [slowdown, error]
        end

      end

    end
  end
end
