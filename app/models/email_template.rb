# Renders the email a member receives for a personal link, using the group's
# Action Text template (or DEFAULT_BODY) and replacing {{placeholders}}.
#
# Safety: the template HTML is sanitized by Action Text when rendered, and every
# value substituted into it is HTML-escaped, so neither the template author nor a
# member's name can inject markup.
class EmailTemplate
  Rendered = Data.define(:subject, :html, :text)

  PLACEHOLDER = /\{\{\s*([a-z_]+)\s*\}\}/
  LINK_PLACEHOLDERS = %w[link link_url].freeze

  # Shown in the editor's help panel, in this order.
  PLACEHOLDERS = {
    "link" => "Their personal link as an “Open link” button",
    "link_url" => "Their personal link as a full web address",
    "first_name" => "The member's first name",
    "name" => "The member's full name",
    "title" => "The link's title (or “a link” if it has none)",
    "group" => "The group's name"
  }.freeze

  DEFAULT_SUBJECT = "{{title}}".freeze
  DEFAULT_BODY = <<~HTML.gsub(/>\s+</, "><").strip.freeze
    <div>Hi {{first_name}},</div>
    <div><br></div>
    <div>{{group}} has shared <strong>{{title}}</strong> with you.</div>
    <div><br></div>
    <div>{{link}}</div>
    <div><br></div>
    <div>This link is personal to you — please don't forward it.</div>
  HTML

  BUTTON_STYLE = "display:inline-block;padding:12px 20px;background:#0d6efd;color:#ffffff;" \
                 "text-decoration:none;border-radius:6px;font-weight:600;".freeze

  # True if the template HTML contains the personal link in any supported form.
  def self.includes_link?(html)
    fragment = Nokogiri::HTML5.fragment(html.to_s)
    fragment.css("a[href]").any? { |a| link_href?(a["href"]) } ||
      fragment.text.scan(PLACEHOLDER).flatten.intersect?(LINK_PLACEHOLDERS)
  end

  # Text linked to the personal link has its href set to "{{link}}" by the editor.
  def self.link_href?(href)
    CGI.unescape(href.to_s).strip.match?(/\A\{\{\s*link(_url)?\s*\}\}\z/)
  end

  def initialize(group)
    @group = group
  end

  def custom_body?
    @group.rich_text_email_template&.body.present?
  end

  def render(member_name:, link_title:, url:)
    values = {
      "name" => member_name.to_s,
      "first_name" => member_name.to_s.split.first.to_s,
      "title" => link_title.presence || "a link",
      "group" => @group.name.to_s,
      "url" => url
    }

    Rendered.new(
      subject: render_subject(link_title, values),
      html: render_html(values),
      text: render_text(values)
    )
  end

  private
    def content
      custom_body? ? @group.email_template.body : ActionText::Content.new(DEFAULT_BODY)
    end

    def render_subject(link_title, values)
      template = @group.email_subject.presence ||
                 (link_title.present? ? DEFAULT_SUBJECT : "A new link from {{group}}")
      substitute(template) { |key| values[key] unless LINK_PLACEHOLDERS.include?(key) }.squish
    end

    def render_html(values)
      url = values["url"]
      fragment = Nokogiri::HTML5.fragment(content.to_s) # sanitized by Action Text
      fragment.css("a[href]").each { |a| a["href"] = url if self.class.link_href?(a["href"]) }

      substitute(fragment.to_html) do |key|
        case key
        when "link" then %(<a href="#{ERB::Util.h(url)}" style="#{BUTTON_STYLE}">Open link</a>)
        when "link_url" then %(<a href="#{ERB::Util.h(url)}">#{ERB::Util.h(url)}</a>)
        else ERB::Util.h(values[key]) if values.key?(key)
        end
      end.html_safe
    end

    def render_text(values)
      # Plain text drops hrefs, so spell out the URL after any linked text.
      fragment = Nokogiri::HTML5.fragment(content.to_html)
      fragment.css("a[href]").each do |a|
        a.replace(Nokogiri::XML::Text.new("#{a.text} ({{link_url}})", fragment.document)) if self.class.link_href?(a["href"])
      end

      substitute(ActionText::Content.new(fragment.to_html).to_plain_text) do |key|
        LINK_PLACEHOLDERS.include?(key) ? values["url"] : values[key]
      end.strip
    end

    # Replaces each {{key}} with the block's result; unknown keys are left as typed.
    def substitute(string)
      string.gsub(PLACEHOLDER) { yield(Regexp.last_match(1)) || Regexp.last_match(0) }
    end
end
