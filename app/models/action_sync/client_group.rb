# == Schema Information
#
# Table name: action_sync_client_groups
#
#  id             :string           not null, primary key
#  cvr_version    :integer          default(0), not null
#  schema_version :string           not null
#  syncable_type  :string           not null
#  created_at     :datetime         not null
#  updated_at     :datetime         not null
#  syncable_id    :bigint           not null
#
# Indexes
#
#  index_action_sync_client_groups_on_syncable  (syncable_type,syncable_id)
#
module ActionSync
  class ClientGroup < ApplicationRecord
    has_many :clients, dependent: :destroy
    has_many :client_view_records, dependent: :destroy

    belongs_to :syncable, polymorphic: true
  end
end
