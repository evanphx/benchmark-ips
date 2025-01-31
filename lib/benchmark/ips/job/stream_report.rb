module Benchmark
  module IPS
    class Job
      class StreamReport
        def initialize(job, stream = $stdout)
          @last_item = nil
          @out = stream
          @job = job
        end

        def start_warming
          @out.puts RUBY_DESCRIPTION
          @out.puts "Warming up --------------------------------------"
        end

        def start_running
          @out.puts "Calculating -------------------------------------"
        end

        def warming(label, _warmup)
          @out.print label.to_s.rjust(@job.max_width)
        end
        alias_method :running, :warming

        def warmup_stats(_warmup_time_us, timing)
          case format
          when :human
            @out.printf "%s i/100ms\n", Helpers.scale(timing)
          else
            @out.printf "%10d i/100ms\n", timing
          end
        end

        def add_report(item, caller)
          @out.puts " #{item.body}"
          @last_item = item
        end

        def footer
          return unless @last_item
          footer = @last_item.stats.footer
          @out.puts footer.rjust(40) if footer
        end

        private

        # @return [Symbol] format used for benchmarking
        def format
          Benchmark::IPS.options[:format]
        end
      end
    end
  end
end
