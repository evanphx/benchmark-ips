require "minitest/autorun"
require "benchmark/ips"
require "stringio"

class TestReport < Minitest::Test
  class StdSuite
    attr_accessor :calls
    def initialize
      @calls = []
    end

    def warming(_a, _b) ; @calls << :warming ; end
    def warmup_stats(_a, _b) ; @calls << :warmup_stats ; end
    def running(_a, _b) ; @calls << :running ; end
    def add_report(_a, _b) ; @calls << :add_report ; end
  end

  class FullReport < StdSuite
    def start_warming ; @calls << :start_warming ; end
    def start_running ; @calls << :start_running ; end
    def footer ; @calls << :footer ; end
  end

  def setup
    @old_stdout = $stdout
    $stdout = StringIO.new
  end

  def teardown
    $stdout = @old_stdout
  end

  def test_ips_config_suite
    suite = StdSuite.new

    Benchmark.ips(0.1, 0.1) do |x|
      x.config(:suite => suite)
      x.report("job") {}
    end

    assert_equal [:warming, :warmup_stats, :running, :add_report], suite.calls
  end

  def test_ips_config_suite_by_accsr
    suite = StdSuite.new

    Benchmark.ips(0.1, 0.1) do |x|
      x.suite = suite
      x.report("job") {}
    end

    assert_equal [:warming, :warmup_stats, :running, :add_report], suite.calls
  end

  def test_quiet_false_default
    Benchmark.ips do |x|
      refute x.quiet
    end
  end

  def test_quiet_false_config
    Benchmark.ips(quiet: false) do |x|
      refute x.quiet
    end
  end

  def test_quiet_false_config_by_accsr
    Benchmark.ips do |x|
      x.quiet = false
      refute x.quiet
    end
  end

  def test_quiet_false_change
    Benchmark.ips(quiet: true) do |x|
      x.quiet = false
      refute x.quiet
    end
  end

  def test_quiet_false
    $stdout = @old_stdout

    out, err = capture_io do
      Benchmark.ips(:time => 1, :warmup => 0, :quiet => false) do |x|
        x.report("sleep 0.25") { sleep(0.25) }
      end
    end

    assert_match(/Calculating -+/, out)
    assert_empty err
  end

  # all reports are run after block is fully defined
  # so last value wins for all tests
  def test_quiet_false_change_mind
    $stdout = @old_stdout

    # all reports are run after block is defined
    # so changing the value does not matter. last value wins for all
    out, err = capture_io do
      Benchmark.ips(:time => 1, :warmup => 0, :quiet => true) do |x|
        x.report("sleep 0.25") { sleep(0.25) }
        x.quiet = false
      end
    end

    assert_match(/Calculating -+/, out)
    assert_empty err
  end

  def test_quiet_true_config
    Benchmark.ips(:quiet => true) do |x|
      assert x.quiet
    end
  end

  def test_quiet_true_by_accsr
    Benchmark.ips do |x|
      x.quiet = true
      assert x.quiet
    end
  end

  def test_quiet_true_change
    Benchmark.ips(:quiet => false) do |x|
      x.quiet = true
      assert x.quiet
    end
  end

  def test_quiet_true
    $stdout = @old_stdout

    out, err = capture_io do
      Benchmark.ips(:time => 1, :warmup => 0, :quiet => true) do |x|
        x.report("sleep 0.25") { sleep(0.25) }
      end
    end

    refute_match(/Calculating -+/, out)
    assert_empty err
  end

  # all reports are run after block is fully defined
  # so last value wins for all tests
  def test_quiet_true_change_mind
    $stdout = @old_stdout

    out, err = capture_io do
      Benchmark.ips(:time => 1, :warmup => 0, :quiet => false) do |x|
        x.report("sleep 0.25") { sleep(0.25) }
        x.quiet = true
      end
    end

    refute_match(/Calculating -+/, out)
    assert_empty err
  end

  def test_multi_report
    suite = Benchmark::IPS::Job::MultiReport.new
    suite << StdSuite.new
    suite << StdSuite.new

    Benchmark.ips(:time => 0.1, :warmup => 0.1, :quiet => true) do |x|
      x.suite = suite
      x.report("job") {}
    end

    suite.out.each do |rpt|
      assert_equal [:warming, :warmup_stats, :running, :add_report], rpt.calls
    end
  end
end
