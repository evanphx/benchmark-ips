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
    def compare(job, *entries)
      return if entries.size < 2

      sorted = entries.sort_by(&:ips).reverse
      best = sorted.shift
      had_overlaps = false

      $stdout.puts "\nComparison:"

      $stdout.printf "%20s: %10.1f i/s\n", best.label, best.ips

      sorted.each do |report|
        name = report.label.to_s
        
        $stdout.printf "%20s: %10.1f i/s - ", name, report.ips
        
        best_low = best.ips - best.ips_sd
        report_high = report.ips + report.ips_sd
        overlaps = report_high > best_low 
        
        if overlaps
          $stdout.print "same-ish: difference falls within error"
          had_overlaps = true
        else
          x = (best.ips.to_f / report.ips.to_f)
          $stdout.printf "%.2fx slower", x
        end
        
        $stdout.puts
      end

      $stdout.puts

      suggest_sd_mitigating_config job if had_overlaps
    end

    private
    def suggest_sd_mitigating_config job
      suggested_sample_duration = job.sample_duration * 4
      suggested_time = job.time * 2
      # we're growing sample duration more aggressively,
      # don't let them get out of whack too much
      if (suggested_time / suggested_sample_duration) < 20
        (suggested_time * 1.5).round
      end

      $stdout.print <<-MSG
-------------------------------------------------------------------------

Some reports were within standard deviation of each other. Because of that
benchmark-ips was unable to decide which of them is faster. It is quite
possible that with a slightly tweaked configuration benchmark-ips will
be able to provide more accurate results.

Please try re-running your benchmark with the following additional
configuration:

  Benchmark.ips do |x|
    x.sample_duration = #{suggested_sample_duration} # <--- new config
    x.time = #{suggested_time} # <--- new config
    # ...

Please note that running the benchmark with the new configuration
will take longer and might not result in a more accurate measurement.
In that case benchmark-ips will re-print this warning with an even
more aggressive configuration option suggestions. It is a good idea
to try to follow benchmark-ips's advice a couple of times (each time
re-running the benchmark with new options), letting it escalate
its configuration repeatedly (a good rule is to give up after 3-4
iterations).
MSG

      $stdout.puts
    end
  end

  extend Benchmark::Compare
end
