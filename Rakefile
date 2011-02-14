require "rubygems"
require "rake"
require "rake/clean"
require "rake/testtask"
require "rake/packagetask"
require "rake/gempackagetask"
require "rake/rdoctask"

task :default => :test

desc "Run unit tests"
Rake::TestTask.new("test") do |t|
  t.libs << "test"
  t.test_files = ["test/ts_all.rb"]
  t.verbose = true
end

desc 'generate API documentation in the docs/rdoc directory.'
Rake::RDocTask.new do |rd|
  rd.rdoc_dir = 'doc/rdocs'
  rd.main = 'README'
  rd.rdoc_files.include 'README', 'CHANGELOG', 'LICENSE', "lib/**/*\.rb"
 
  rd.options << '--inline-source'
  rd.options << '--line-numbers'
  rd.options << '--all'
  rd.options << '--fileboxes'
end