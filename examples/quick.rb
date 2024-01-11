#!/usr/bin/env ruby

require 'benchmark/ips'

h = {}

Benchmark.quick_compare(h, :size, :empty?, warmup: 1, time: 1)
