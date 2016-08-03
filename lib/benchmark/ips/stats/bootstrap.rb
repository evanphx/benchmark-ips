module Benchmark
  module IPS
    module Stats

      class Bootstrap

        attr_reader :data

        def initialize(samples, confidence)
          dependencies
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

        def footer
          "with #{(@confidence.to_f * 100).round(1)}% confidence"
        end

        def dependencies
          require 'kalibera'
        rescue LoadError
          puts
          puts "Can't load the kalibera gem - this is required to use the :bootstrap stats options."
          puts "It's optional, so we don't formally depend on it and it isn't installed along with benchmark-ips."
          puts "You probably want to do something like 'gem install kalibera' to fix this."
          abort
        end

      end

    end
  end
end
