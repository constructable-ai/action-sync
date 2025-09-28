# == Schema Information
#
# Table name: action_sync_clients
#
#  id               :string           not null, primary key
#  created_at       :datetime         not null
#  updated_at       :datetime         not null
#  client_group_id  :string           not null
#  last_mutation_id :integer          default(0), not null
#
# Indexes
#
#  index_action_sync_clients_on_client_group_id  (client_group_id)
#
# Foreign Keys
#
#  client_group_id  (client_group_id => action_sync_client_groups.id)
#
module ActionSync
  class Client < ApplicationRecord
    belongs_to :client_group
  end
end
