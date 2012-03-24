require "test/unit"
require "benchmark/ips"
require "stringio"

class TestBenchmarkIPS < Test::Unit::TestCase
  def setup
    @old_stdout = $stdout
    $stdout = StringIO.new
  end

  def teardown
    $stdout = @old_stdout
  end

  def test_ips
    reports = Benchmark.ips(1,1) do |x|
      x.report("sleep") { sleep(0.25) }
    end

    rep = reports.first

    assert_equal "sleep", rep.label
    assert_equal 4, rep.iterations
    assert_in_delta 4.0, rep.ips, 0.2
  end
end
