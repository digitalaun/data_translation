require 'rubygems'

SPEC = Gem::Specification.new do |s|
	s.name     = 'data_translation'
	s.version  = '1.1.0'
	s.author   = 'Scott Patterson'
	s.email    = 'scott.patterson@digitalaun.com'
	s.platform = Gem::Platform::RUBY
	s.summary  = 'Generic data mapping and translation expressed in Ruby.'
	s.description = 'Provides a means to write data translation maps in Ruby and transform data from a source object.'
	candidates = Dir.glob("{doc,lib,test}/**/*")
	s.files    = candidates.delete_if do |item|
	               item[0,1] == '.' || item.include?('rdoc')
	             end
	s.require_path     = 'lib'
	s.test_file        = 'test/ts_all.rb'
	s.has_rdoc         = true
	s.rdoc_options     << '--main' << 'README'
    s.extra_rdoc_files = ['README', 'LICENSE', 'CHANGELOG']
end
