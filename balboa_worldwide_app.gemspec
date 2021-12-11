# frozen_string_literal: true

require_relative "lib/bwa/version"

Gem::Specification.new do |s|
  s.name = "balboa_worldwide_app"
  s.version = BWA::VERSION
  s.platform = Gem::Platform::RUBY
  s.authors = ["Cody Cutrer"]
  s.email = "cody@cutrer.com'"
  s.homepage = "https://github.com/ccutrer/bwa"
  s.summary = "Library for communication with Balboa Water Group's WiFi module or RS-485"
  s.license = "MIT"
  s.metadata = {
    "rubygems_mfa_required" => "true"
  }

  s.bindir = "exe"
  s.executables = Dir["exe/*"].map { |f| File.basename(f) }
  s.files = Dir["{exe,lib}/**/*"]

  s.required_ruby_version = ">= 2.5"

  s.add_dependency "ccutrer-serialport", "~> 1.0.0"
  s.add_dependency "digest-crc", "~> 0.4"
  s.add_dependency "mqtt-homeassistant", "~> 0.1", " >= 0.1.3"
  s.add_dependency "net-telnet-rfc2217", "~> 0.0.3"
  s.add_dependency "sd_notify", "~> 0.1.1"

  s.add_development_dependency "byebug", "~> 11.0"
  s.add_development_dependency "rake", "~> 13.0"
  s.add_development_dependency "rubocop", "~> 1.23"
  s.add_development_dependency "rubocop-performance", "~> 1.12"
  s.add_development_dependency "rubocop-rake", "~> 0.6"
end
