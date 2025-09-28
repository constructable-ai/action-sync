module ActionSync
  class VersionMap
    include Enumerable

    attr_reader :object_map

    def initialize
      @object_map = Hash.new { |hash, key| hash[key] = {} }
    end

    delegate :each, :to_json, to: :object_map

    def load_json(json_hash)
      json_hash.default_proc = proc { |hash, key| hash[key] = {} }
      @object_map = json_hash
    end

    def merge!(other_versions)
      object_map.merge!(other_versions.object_map)
    end

    def versions(entity_type)
      @object_map[entity_type]
    end

    def version(entity_type, entity_id)
      @object_map[entity_type][entity_id]
    end

    def insert_version(entity_type, entity_id, entity_version)
      @object_map[entity_type][entity_id] = entity_version
    end
  end
end
