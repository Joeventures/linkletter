class CreatePersonalLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :personal_links do |t|
      t.references :link, null: false, foreign_key: true
      t.references :member, null: false, foreign_key: true
      t.string :token, null: false
      t.datetime :sent_at
      t.integer :clicks_count, null: false, default: 0
      t.datetime :first_clicked_at
      t.datetime :last_clicked_at

      t.timestamps
    end
    add_index :personal_links, :token, unique: true
    add_index :personal_links, [ :link_id, :member_id ], unique: true
  end
end
