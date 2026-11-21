class CreateClicks < ActiveRecord::Migration[8.1]
  def change
    create_table :clicks do |t|
      t.references :personal_link, null: false, foreign_key: true
      t.string :ip_address
      t.text :user_agent
      t.string :browser_name
      t.string :browser_version
      t.string :platform
      t.string :device_type
      t.text :referrer
      t.string :accept_language
      t.boolean :bot, null: false, default: false

      t.datetime :created_at, null: false
    end
  end
end
