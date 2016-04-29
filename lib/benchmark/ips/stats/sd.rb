module Benchmark
  module IPS
    module Stats
      
      class SD
        
        def initialize(samples)
          @mean = Timing.mean(samples)
          @error = Timing.stddev(samples, @mean).round
        end
        
        def central_tendency
          @mean
        end
        
        def error
          @error
        end
        
      end
    
    end
  end
end
