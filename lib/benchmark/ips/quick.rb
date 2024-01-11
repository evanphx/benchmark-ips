module Benchmark
  module IPS
    # Quickly compare multiple methods on the same method.
    # @param obj The object to call the methods on
    # @param methods The list of methods to call as Symbols
    #
    # Keyword arguments are detected as well, with the following
    # available:
    #
    # @param warmup How many seconds to warm up the benchmark process
    # @param time How many seconds to benchmark each method
    def quick_compare(obj, *methods)
      if methods.last.kind_of? Hash
        opts = methods.pop
      else
        opts = {}
      end

      Benchmark.ips do |x|
        x.compare!
        x.warmup = opts[:warmup] if opts[:warmup]
        x.time = opts[:time] if opts[:time]

        methods.each do |name|
          x.report(name) do |x|
            x.times { obj.__send__ name }
          end
        end
      end
    end
  end
end
