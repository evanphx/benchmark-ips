#!/usr/bin/env ruby

require 'benchmark/ips'

def add
  1 + 1
end

def sub
  2 - 1
end

quick_compare(:add, :sub, warmup: 1, time: 1)

h = {}

h.quick_compare(:size, :empty?)
