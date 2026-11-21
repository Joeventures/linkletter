class AddEmailSubjectToGroups < ActiveRecord::Migration[8.1]
  def change
    add_column :groups, :email_subject, :string
  end
end
