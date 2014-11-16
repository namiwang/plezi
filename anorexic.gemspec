# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'anorexic/version'

Gem::Specification.new do |spec|
  spec.name          = "anorexic"
  spec.version       = Anorexic::VERSION
  spec.authors       = ["Boaz Segev"]
  spec.email         = ["We try, we fail, we do, we are"]
  spec.summary       = %q{People who are serious about their framework, should write their own server.}
  spec.description   = %q{"People who are serious about their framework, should write their own server." - advance to next step in Ruby evolution, a framework with an integrated server, ready for seamless WebSockets and RESTful applications.}
  spec.homepage      = "http://boazsegev.github.io/anorexic/"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.7"
  spec.add_development_dependency "rake", "~> 10.0"

  spec.post_install_message = "deprecation warning!\nAnorexic dropped Rack support in favor of an internal server... (to allow protocol switching mid-stream, such as WebSockets).\nPLEASE REVIEW YOUR CODE."

end
