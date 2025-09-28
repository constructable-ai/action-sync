require_relative "lib/action_sync/version"

Gem::Specification.new do |spec|
  spec.name        = "action-sync"
  spec.version     = ActionSync::VERSION
  spec.authors     = [ "Zachary Wood" ]
  spec.email       = [ "zac.wood9@gmail.com" ]
  spec.license     = "MIT"
  spec.summary     = "Replicache implementation for Rails"

  spec.files = Dir.chdir(File.expand_path(__dir__)) do
    Dir["{app,config,db,lib}/**/*", "MIT-LICENSE", "Rakefile", "README.md"]
  end

  spec.add_dependency "rails", ">= 8.0.2.1"
end
