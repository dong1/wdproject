spec = Gem::Specification.new do |s|
  s.name = "cubrid"
  s.version = "0.6"
  s.authors = "NHN"
  s.email = "cubrid_ruby@nhncorp.com"
  s.homepage ="http://dev.naver.com/projects/cubrid-ruby"
  s.summary = "CUBRID API Module for Ruby"
  s.platform = Gem::Platform::RUBY
  s.required_ruby_version = Gem::Version::Requirement.new(">= 1.8.0")
  s.files = ["ext/extconf.rb", "ext/cubrid.c", "ext/cubrid.h", "ext/conn.c", "ext/stmt.c", "ext/oid.c", "ext/error.c"]
  s.require_path = "."
  s.autorequire = "cubrid"
  s.extensions = ["ext/extconf.rb"]
end
