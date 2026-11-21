class Member < ApplicationRecord
  belongs_to :group
  has_many :personal_links, dependent: :destroy
  has_many :clicks, through: :personal_links

  normalizes :email_address, with: ->(e) { e.strip.downcase }
  normalizes :name, with: ->(n) { n.strip }

  validates :name, presence: true, length: { maximum: 120 }
  validates :email_address, presence: true, format: { with: URI::MailTo::EMAIL_REGEXP, allow_blank: true },
                            uniqueness: { scope: :group_id, message: "is already in this group" }
end
