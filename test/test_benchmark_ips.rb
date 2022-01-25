require "minitest/autorun"
require "benchmark/ips"
require "stringio"
require "tmpdir"

class TestBenchmarkIPS < Minitest::Test
  def setup
    @old_stdout = $stdout
    $stdout = StringIO.new
  end

  def teardown
    $stdout = @old_stdout
  end

  def test_kwargs
    Benchmark.ips(:time => 0.001, :warmup => 0.001, :quiet => false) do |x|
      x.report("sleep 0.25") { sleep(0.25) }
    end

    assert $stdout.string.size > 0
  end

  def test_warmup0
    $stdout = @old_stdout

    out, err = capture_io do
      Benchmark.ips(:time => 1, :warmup => 0, :quiet => false) do |x|
        x.report("sleep 0.25") { sleep(0.25) }
      end
    end

    refute_match(/Warming up -+/, out)
    assert_empty err
  end

  def test_output
    Benchmark.ips(1) do |x|
      x.report("operation") { 100 * 100 }
    end

    assert $stdout.string.size > 0
  end

  def test_quiet
    Benchmark.ips(nil, nil, true) do |x|
      x.config(:warmup => 0.001, :time => 0.001)
      x.report("operation") { 100 * 100 }
    end

    assert $stdout.string.size.zero?

    Benchmark.ips(:quiet => true) do |x|
      x.config(:warmup => 0.001, :time => 0.001)
      x.report("operation") { 100 * 100 }
    end

    assert $stdout.string.size.zero?

    Benchmark.ips do |x|
      x.config(:warmup => 0.001, :time => 0.001)
      x.quiet = true
      x.report("operation") { 100 * 100 }
    end

    assert $stdout.string.size.zero?
  end

  def test_quiet_option_override
    Benchmark.ips(quiet: true) do |x|
      x.config(:warmup => 0.001, :time => 0.001)
      x.quiet = false
      x.report("operation") { 100 * 100 }
    end

    assert $stdout.string.size > 0
    $stdout.truncate(0)

    Benchmark.ips(quiet: true) do |x|
      x.config(quiet: false, warmup: 0.001, time: 0.001)
      x.report("operation") { 100 * 100 }
    end

    assert $stdout.string.size > 0
    $stdout.truncate(0)

    Benchmark.ips(quiet: true, warmup: 0.001, time: 0.001) do |x|
      # Calling config should not make quiet option overridden when no specified
      x.config({})
      x.report("operation") { 100 * 100 }
    end

    assert $stdout.string.size.zero?
  end

  def test_ips
    report = Benchmark.ips do |x|
      x.config(:time => 1, :warmup => 1)
      x.report("sleep 0.25") { sleep(0.25) }
      x.report("sleep 0.05") { sleep(0.05) }
      x.compare!
    end

    rep1 = report.entries[0]
    rep2 = report.entries[1]

    assert_equal "sleep 0.25", rep1.label
    assert_equal 4, rep1.iterations
    assert_in_delta 4.0, rep1.ips, 0.2

    assert_equal "sleep 0.05", rep2.label
    assert_in_delta 20.0, rep2.iterations.to_f, 1.0
    assert_in_delta 20.0, rep2.ips, 2.0
  end

  def test_ips_alternate_config
    report = Benchmark.ips do |x|
      x.time = 1
      x.warmup = 1
      x.report("sleep 0.25") { sleep(0.25) }
    end

    rep = report.entries.first

    assert_equal "sleep 0.25", rep.label
    assert_equal 4, rep.iterations
    assert_in_delta 4.0, rep.ips, 0.4
  end

  def test_ips_old_config
    report = Benchmark.ips(1, 1) do |x|
      x.report("sleep 0.25") { sleep(0.25) }
    end

    rep = report.entries.first

    assert_equal "sleep 0.25", rep.label
    assert_equal 4, rep.iterations
    assert_in_delta 4.0, rep.ips, 0.2
  end

  def test_ips_config_suite
    suite = Struct.new(:calls) do
      def method_missing(method, *args)
        calls << method
      end
    end.new([])

    Benchmark.ips(0.1, 0.1) do |x|
      x.config(:suite => suite)
      x.report("job") {}
    end

    assert_equal [:warming, :warmup_stats, :running, :add_report], suite.calls
  end

  def test_ips_config_suite_by_accsr
    suite = Struct.new(:calls) do
      def method_missing(method, *args)
        calls << method
      end
    end.new([])

    Benchmark.ips(0.1, 0.1) do |x|
      x.suite = suite
      x.report("job") {}
    end

    assert_equal [:warming, :warmup_stats, :running, :add_report], suite.calls
  end

  def test_ips_defaults
    report = Benchmark.ips do |x|
      x.report("sleep 0.25") { sleep(0.25) }
    end

    rep = report.entries.first

    assert_equal "sleep 0.25", rep.label
    assert_equal 4*5, rep.iterations
    assert_in_delta 4.0, rep.ips, 0.2
  end

  def test_ips_report_using_symbol
    report = Benchmark.ips do |x|
      x.report(:sleep_a_quarter_second) { sleep(0.25) }
    end

    rep = report.entries.first

    assert_equal :sleep_a_quarter_second, rep.label
    assert_equal 4*5, rep.iterations
    assert_in_delta 4.0, rep.ips, 0.2
  end

  def test_ips_default_data
    report = Benchmark.ips do |x|
      x.config(:warmup => 0.001, :time => 0.001)
      x.report("sleep 0.25") { sleep(0.25) }
    end

    all_data = report.data

    assert all_data
    assert_equal "sleep 0.25", all_data[0][:name]
    assert all_data[0][:ips]
    assert all_data[0][:stddev]
  end

  def test_ips_empty
    report = Benchmark.ips do |_x|

    end

    all_data = report.data

    assert all_data
    assert_equal [], all_data
  end

  def test_json_output
    json_file = Tempfile.new("data.json")

    Benchmark.ips do |x|
      x.report("sleep 0.25") { sleep(0.25) }
      x.json! json_file.path
    end

    json_data = json_file.read
    assert json_data

    data = JSON.parse json_data
    assert data
    assert_equal 1, data.size
    assert_equal "sleep 0.25", data[0]["name"]
    assert data[0]["ips"]
    assert data[0]["stddev"]
  end

  def test_hold!
    temp_file_name = Dir::Tmpname.create(["benchmark-ips", ".tmp"]) { }

    Benchmark.ips(:time => 0.001, :warmup => 0.001) do |x|
      x.report("operation") { 100 * 100 }
      x.report("operation2") { 100 * 100 }
      x.hold! temp_file_name
    end

    assert File.exist?(temp_file_name)
    File.unlink(temp_file_name)
  end

  def test_small_warmup_and_time
    report = Benchmark.ips do |x|
      x.config(:warmup => 0.0000000001, :time => 0.001)
      x.report("addition") { 1 + 2 }
    end
    assert_operator report.entries[0].iterations, :>=, 1

    report = Benchmark.ips do |x|
      x.config(:warmup => 0, :time => 0.0000000001)
      x.report("addition") { 1 + 2 }
    end
    assert_equal 1, report.entries[0].iterations

    report = Benchmark.ips do |x|
      x.config(:warmup => 0.001, :time => 0.0000000001)
      x.report("addition") { 1 + 2 }
    end
    assert_operator report.entries[0].iterations, :>=, 1

    report = Benchmark.ips do |x|
      x.config(:warmup => 0.0000000001, :time => 0.0000000001)
      x.report("addition") { 1 + 2 }
    end
    assert_operator report.entries[0].iterations, :>=, 1

    report = Benchmark.ips do |x|
      x.config(:warmup => 0, :time => 0)
      x.report("addition") { 1 + 2 }
    end
    assert_equal 1, report.entries[0].iterations
  end
end
