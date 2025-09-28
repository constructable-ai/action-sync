# == Schema Information
#
# Table name: action_sync_client_view_records
#
#  id              :string           not null, primary key
#  created_at      :datetime         not null
#  updated_at      :datetime         not null
#  client_group_id :string           not null
#
# Indexes
#
#  index_action_sync_client_view_records_on_client_group_id  (client_group_id)
#
# Foreign Keys
#
#  client_group_id  (client_group_id => action_sync_client_groups.id)
#
module ActionSync
  class ClientViewRecord < ApplicationRecord
    belongs_to :client_group
    has_one_attached :entity_versions_json, service: ActionSync.storage_service

    def version_map
      return VersionMap.new unless persisted?
      return VersionMap.new unless entity_versions_json.attached?

      @cached_versions ||= VersionMap.new.tap do |versions|
        versions.load_json(download_cached_versions) rescue nil
      end
    end

    def upload_cached_versions(version_map)
      entity_versions_json.attach(
        io: StringIO.new(version_map.to_json),
        filename: "action_sync_cvr_#{id}.json",
        content_type: "application/json",
      )
    end

    private
      def download_cached_versions
        JSON.parse(entity_versions_json.download)
      end
  end
end
