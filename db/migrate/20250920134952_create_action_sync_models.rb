class CreateActionSyncModels < ActiveRecord::Migration[8.0]
  def change
    create_table :action_sync_client_groups, id: :string do |t|
      t.string :schema_version, null: false
      t.integer :cvr_version, null: false, default: 0
      t.belongs_to :syncable, null: false, polymorphic: true, type: foreign_key_type
      t.timestamps
    end

    create_table :action_sync_clients, id: :string do |t|
      t.belongs_to :client_group, type: :string, foreign_key: { to_table: :action_sync_client_groups }, index: true, null: false
      t.integer :last_mutation_id, null: false, default: 0
      t.timestamps
    end

    create_table :action_sync_client_view_records, id: :string do |t|
      t.belongs_to :client_group, type: :string, foreign_key: { to_table: :action_sync_client_groups }, index: true, null: false
      t.timestamps
    end
  end

  private

  def foreign_key_type
    config = Rails.configuration.generators
    setting = config.options[config.orm][:primary_key_type]
    setting || :bigint
  end
end
