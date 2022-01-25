# -*- ruby -*-

require "bundler/setup"
require "rake/testtask"
require "rubygems/package_task"
require "bundler/gem_tasks"

gemspec = Gem::Specification.load("benchmark-ips.gemspec")
Gem::PackageTask.new(gemspec).define

Rake::TestTask.new(:test)

task default: :test

# vim: syntax=ruby
