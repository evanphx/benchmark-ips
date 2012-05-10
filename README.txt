= benchmark-ips

* http://github.com/evanphx/benchmark-ips

== DESCRIPTION:

A iterations per second enhancement to Benchmark

== FEATURES/PROBLEMS:

 * benchmark/ips - benchmarks a blocks iterations/second. For short snippits
   of code, ips automatically figures out how many times to run the code
   to get interesting data. No more guessing at random iteration counts!

== SYNOPSIS:

require 'benchmark/ips'

Benchmark.ips do |x|
  # Typical mode, runs the block as many times as it can
  x.report("addition") { 1 + 2 }

  # To reduce overhead, the number of iterations is passed in
  # and the block must run the code the specific number of times.
  # Used for when the workload is very small and any overhead
  # introduces incorrectable errors.
  x.report("addition2") do |times|
    i = 0
    while i < times
      1 + 2
      i += 1
    end
  end

  # To reduce overhead even more, grafts the code given into
  # the loop that performs the iterations internally to reduce
  # overhead. Typically not needed, use the |times| form instead.
  x.report("addition3", "1 + 2")
end

== REQUIREMENTS:

* None!

== INSTALL:

* gem install benchmark-ips

== DEVELOPERS:

After checking out the source, run:

  $ rake newb

This task will install any missing dependencies, run the tests/specs,
and generate the RDoc.

== LICENSE:

(The MIT License)

Copyright (c) 2012 Evan Phoenix

Permission is hereby granted, free of charge, to any person obtaining
a copy of this software and associated documentation files (the
'Software'), to deal in the Software without restriction, including
without limitation the rights to use, copy, modify, merge, publish,
distribute, sublicense, and/or sell copies of the Software, and to
permit persons to whom the Software is furnished to do so, subject to
the following conditions:

The above copyright notice and this permission notice shall be
included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED 'AS IS', WITHOUT WARRANTY OF ANY KIND,
EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
