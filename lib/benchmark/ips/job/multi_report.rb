module Benchmark
  module IPS
    class Job
      class MultiReport
        # @returns out [Array<StdoutReport>] list of reports to send output
        attr_accessor :out

        def empty?
          @out.empty?
        end

        # @param report [StdoutReport] report to accept input?
        def <<(report)
          @out << report
        end

        # @param out [Array<StdoutReport>] list of reports to send output
        def initialize(out = [])
          @out = out
        end

        def start_warming
          @out.each { |o| o.start_warming }
        end

        def start_running
          @out.each { |o| o.start_running }
        end

        def warming(label, _warmup)
          @out.each { |o| o.warming(label, _warmup) }
        end

        def running(label, _warmup)
          @out.each { |o| o.running(label, _warmup) }
        end

        def warmup_stats(_warmup_time_us, timing)
          @out.each { |o| o.warmup_stats(_warmup_time_us, timing) }
        end

        def add_report(item, caller)
          @out.each { |o| o.add_report(item, caller) }
        end

        def footer
          @out.each { |o| o.footer }
        end
      end
    end
  end
end
