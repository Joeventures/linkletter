class Link < ApplicationRecord
  belongs_to :group
  has_many :personal_links, dependent: :destroy
  has_many :clicks, through: :personal_links

  normalizes :url, with: ->(u) { u.strip }

  validates :url, presence: true, length: { maximum: 2048 }
  validates :title, length: { maximum: 200 }
  validate :url_must_be_http

  # Creates a personal link for every group member who doesn't have one yet and
  # emails it to them. Safe to call repeatedly: members who already received
  # this link are skipped, so it doubles as "send to newly added members".
  def deliver_to_members
    group.members.where.not(id: personal_links.select(:member_id)).find_each do |member|
      personal_link = personal_links.create!(member: member)
      LinkMailer.with(personal_link: personal_link).personal_link.deliver_later
      personal_link.update!(sent_at: Time.current)
    end
    update!(sent_at: Time.current)
  end

  def unsent_members
    group.members.where.not(id: personal_links.select(:member_id))
  end

  def display_title
    title.presence || url
  end

  private
    # Only allow absolute http(s) URLs so a stored link can never become a
    # javascript:, data:, or relative redirect.
    def url_must_be_http
      return if url.blank?

      uri = URI.parse(url)
      unless uri.is_a?(URI::HTTP) && uri.host.present?
        errors.add(:url, "must be a full http:// or https:// address")
      end
    rescue URI::InvalidURIError
      errors.add(:url, "is not a valid URL")
    end
end
