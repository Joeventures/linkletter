class Group < ApplicationRecord
  belongs_to :user
  has_many :members, -> { order(:name) }, dependent: :destroy
  has_many :links, -> { order(created_at: :desc) }, dependent: :destroy

  has_rich_text :email_template

  normalizes :email_subject, with: ->(s) { s.squish }

  validates :name, presence: true, length: { maximum: 120 }
  validates :email_subject, length: { maximum: 200 }
  validate :email_template_must_include_link

  def email_renderer
    EmailTemplate.new(self)
  end

  private
    # Checked only when a custom template exists (the association is loaded
    # without building an empty rich text record).
    def email_template_must_include_link
      template = rich_text_email_template
      return if template.nil? || template.body.blank?
      return if EmailTemplate.includes_link?(template.body.to_html)

      errors.add(:email_template, "must include the personal link — use the “Insert link button” or “Link selected text” buttons, or type {{link}}")
    end
end
