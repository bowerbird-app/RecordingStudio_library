# frozen_string_literal: true

require_relative "lib/recording_studio_library/version"

Gem::Specification.new do |spec|
  spec.name        = "recording_studio_library"
  spec.version     = RecordingStudioLibrary::VERSION
  spec.authors     = ["Bowerbird"]
  spec.homepage    = "https://github.com/bowerbird-app/RecordingStudio_library"
  spec.summary     = "Generic Recording Studio libraries and ordered placements"
  spec.description = "A Recording Studio addon that owns keyed libraries of items and ordered " \
                     "placements that point at them. Items stay their own recordable types."
  spec.license     = "MIT"
  spec.required_ruby_version = ">= 3.3.0"

  spec.metadata["homepage_uri"] = spec.homepage
  spec.metadata["source_code_uri"] = spec.homepage
  spec.metadata["changelog_uri"] = "#{spec.homepage}/blob/main/CHANGELOG.md"
  spec.metadata["rubygems_mfa_required"] = "true"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"].reject do |path|
      path == ".cursor" || path.start_with?(".cursor/")
    end
  end

  spec.add_dependency "flat_pack", ">= 0.1.216"
  spec.add_dependency "rails", "~> 8.1.0"
  spec.add_dependency "recording_studio", "~> 4.2"
end
