class Click < ApplicationRecord
  belongs_to :personal_link

  scope :humans, -> { where(bot: false) }

  def browser_summary
    [ browser_name, browser_version.presence&.split(".")&.first ].compact.join(" ")
  end
end
