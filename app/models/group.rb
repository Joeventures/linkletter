class Group < ApplicationRecord
  belongs_to :user
  has_many :members, -> { order(:name) }, dependent: :destroy
  has_many :links, -> { order(created_at: :desc) }, dependent: :destroy

  validates :name, presence: true, length: { maximum: 120 }
end
