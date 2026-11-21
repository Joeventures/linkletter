class CreateLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :links do |t|
      t.references :group, null: false, foreign_key: true
      t.string :title
      t.string :url, null: false
      t.datetime :sent_at

      t.timestamps
    end
  end
end
