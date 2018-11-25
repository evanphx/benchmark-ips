# encoding: utf-8

module Benchmark
  # Functionality of performaing comparison between reports.
  #
  # Usage:
  #
  # Add +x.compare!+ to perform comparison between reports.
  #
  # Example:
  #   > Benchmark.ips do |x|
  #     x.report('Reduce using tag')     { [*1..10].reduce(:+) }
  #     x.report('Reduce using to_proc') { [*1..10].reduce(&:+) }
  #     x.compare!
  #   end
  #
  #   Calculating -------------------------------------
  #       Reduce using tag     19216 i/100ms
  #   Reduce using to_proc     17437 i/100ms
  #   -------------------------------------------------
  #       Reduce using tag   278950.0 (±8.5%) i/s -    1402768 in   5.065112s
  #   Reduce using to_proc   247295.4 (±8.0%) i/s -    1238027 in   5.037299s
  #
  #   Comparison:
  #       Reduce using tag:   278950.0 i/s
  #   Reduce using to_proc:   247295.4 i/s - 1.13x slower
  #
  # Besides regular Calculating report, this will also indicates which one is slower.
  module Compare

    # Compare between reports, prints out facts of each report:
    # runtime, comparative speed difference.
    # @param entries [Array<Report::Entry>] Reports to compare.
    def compare(*entries)
      return if entries.size < 2

      sorted = entries.sort_by{ |e| e.stats.central_tendency }.reverse

      best = sorted.shift

      $stdout.puts "\nComparison:"

      $stdout.printf "%20s: %10.1f i/s\n", best.label.to_s, best.stats.central_tendency

      sorted.each do |report|
        name = report.label.to_s

        $stdout.printf "%20s: %10.1f i/s - ", name, report.stats.central_tendency

        if report.stats.overlaps?(best.stats)
          $stdout.print "same-ish: difference falls within error"
        else
          slowdown, error = report.stats.slowdown(best.stats)
          $stdout.printf "%.2fx ", slowdown
          if error
            $stdout.printf " (± %.2f)", error
          end
          $stdout.print " slower"
        end

        $stdout.puts
      end

      footer = best.stats.footer
      $stdout.puts footer.rjust(40) if footer

      $stdout.puts
    end
  end

  extend Benchmark::Compare
end
