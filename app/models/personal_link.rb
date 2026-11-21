class PersonalLink < ApplicationRecord
  belongs_to :link
  belongs_to :member
  has_many :clicks, -> { order(created_at: :desc) }, dependent: :destroy

  # 32 base58 characters ≈ 187 bits of entropy: not guessable or enumerable.
  has_secure_token :token, length: 32

  validates :member_id, uniqueness: { scope: :link_id }
  validate :member_belongs_to_links_group

  def record_click!(request)
    # Truncate by bytes: the browser gem raises on headers over 2048 bytes.
    user_agent = truncate_bytes(request.user_agent, 1000)
    accept_language = truncate_bytes(request.headers["Accept-Language"], 255)
    agent = Browser.new(user_agent, accept_language: accept_language)

    transaction do
      click = clicks.create!(
        ip_address: request.remote_ip,
        user_agent: user_agent,
        browser_name: agent.name,
        browser_version: agent.full_version,
        platform: agent.platform.name,
        device_type: device_type_for(agent),
        referrer: request.referer.to_s.first(2000).presence,
        accept_language: accept_language.presence,
        bot: agent.bot?
      )

      now = click.created_at
      self.class.where(id: id).update_all([
        "clicks_count = clicks_count + 1, last_clicked_at = ?, first_clicked_at = COALESCE(first_clicked_at, ?), updated_at = ?",
        now, now, now
      ])
      click
    end
  end

  private
    def truncate_bytes(value, bytes)
      value.to_s.byteslice(0, bytes).scrub("")
    end

    def device_type_for(agent)
      if agent.device.tablet? then "tablet"
      elsif agent.device.mobile? then "mobile"
      elsif agent.device.console? then "console"
      elsif agent.device.tv? then "tv"
      else "desktop"
      end
    end

    def member_belongs_to_links_group
      if member && link && member.group_id != link.group_id
        errors.add(:member, "must belong to the link's group")
      end
    end
end
