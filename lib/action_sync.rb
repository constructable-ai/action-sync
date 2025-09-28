require "action_sync/version"
require "action_sync/engine"
require "action_sync/error"

module ActionSync
  autoload :Nanoid, "action_sync/nanoid"
  autoload :Pull, "action_sync/pull"
  autoload :Push, "action_sync/push"
  autoload :Cookie, "action_sync/cookie"
  autoload :BaseSchema, "action_sync/base_schema"
  autoload :BaseMutation, "action_sync/base_mutation"
  autoload :VersionMap, "action_sync/version_map"
  autoload :VersionsDiff, "action_sync/versions_diff"
  autoload :MutationRegistry, "action_sync/mutation_registry"

  mattr_accessor :id_generator
  self.id_generator = -> { Nanoid.generate }

  mattr_accessor :storage_service
  self.storage_service = nil

  mattr_accessor :logger
  self.logger = Logger.new($stdout)

  def self.setup
    yield self
  end
end
