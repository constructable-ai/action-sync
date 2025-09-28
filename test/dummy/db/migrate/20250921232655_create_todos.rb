class CreateTodos < ActiveRecord::Migration[8.0]
  def change
    create_table :todos do |t|
      t.string :title
      t.references :user, null: false, foreign_key: true
      t.integer :version, default: 0
      t.timestamps
    end
  end
end
