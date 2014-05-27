require "minitest/autorun"
require "benchmark/ips"
require "stringio"

class TestBenchmarkIPS < Minitest::Test
  def setup
    @old_stdout = $stdout
    $stdout = StringIO.new
  end

  def teardown
    $stdout = @old_stdout
  end

  def test_ips
    reports = Benchmark.ips(1,1) do |x|
      x.report("sleep 0.25") { sleep(0.25) }
      x.report("sleep 0.05") { sleep(0.05) }
      x.compare!
    end

    rep1 = reports[0]
    rep2 = reports[1]

    assert_equal "sleep 0.25", rep1.label
    assert_equal 4, rep1.iterations
    assert_in_delta 4.0, rep1.ips, 0.2

    assert_equal "sleep 0.05", rep2.label
    assert_equal 20, rep2.iterations
    assert_in_delta 20.0, rep2.ips, 0.5
  end
end
