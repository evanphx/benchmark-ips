module Benchmark
  module IPS
    module Stats

      class Bootstrap

        def initialize(samples, confidence)
          require 'kalibera'
          data = Kalibera::Data.new({[0] => samples}, [1, samples.size])
          interval = data.bootstrap_confidence_interval(10000, (confidence / 100.0).to_s)
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
          baseline.central_tendency.to_f / central_tendency
        end

      end

    end
  end
end
