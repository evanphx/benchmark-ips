module Benchmark
  module IPS
    class JsonReport
      def initialize(json_path)
        @json_path = json_path
      end

      def run(job)
      end

      def post_run(report)
        File.open @json_path , "w" do |f|
          require "json"
          f.write JSON.pretty_generate(report.data)
        end
      end
    end
  end
end
