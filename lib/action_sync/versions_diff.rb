module ActionSync
  class VersionsDiff
    def initialize(cached_versions:, current_versions:)
      @cached_versions = cached_versions
      @current_versions = current_versions
    end

    def puts(entity_type)
      @current_versions.versions(entity_type).each_with_object([]) do |(id, version), put_ids|
        put_ids << id if @cached_versions.version(entity_type, id) != version
        put_ids
      end || []
    end

    def dels(entity_type)
      @cached_versions.versions(entity_type).each_with_object([]) do |(id, _version), del_ids|
        del_ids << id if @current_versions.version(entity_type, id).nil?
        del_ids
      end || []
    end
  end
end
