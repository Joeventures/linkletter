class CreateMembers < ActiveRecord::Migration[8.1]
  def change
    create_table :members do |t|
      t.references :group, null: false, foreign_key: true
      t.string :name, null: false
      t.string :email_address, null: false

      t.timestamps
    end
    add_index :members, [ :group_id, :email_address ], unique: true
  end
end
