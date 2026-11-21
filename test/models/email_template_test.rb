require "test_helper"

class EmailTemplateTest < ActiveSupport::TestCase
  URL = "https://links.example.com/l/AnnStreamToken123456789abcdefghi".freeze

  def render(group, name: "Ann Lee", title: "Sunday stream", url: URL)
    group.email_renderer.render(member_name: name, link_title: title, url: url)
  end

  test "default email includes greeting, title, group and a button to the personal link" do
    email = render(groups(:livestream))

    assert_equal "Sunday stream", email.subject
    assert_includes email.html, "Hi Ann,"
    assert_includes email.html, "Livestream crew has shared <strong>Sunday stream</strong> with you."
    assert_includes email.html, %(<a href="#{URL}" style=)
    assert_includes email.html, ">Open link</a>"
    assert_equal "Hi Ann,\n\nLivestream crew has shared Sunday stream with you.\n\n#{URL}\n\nThis link is personal to you — please don't forward it.", email.text
  end

  test "default subject falls back to the group name when the link has no title" do
    email = render(groups(:livestream), title: nil)
    assert_equal "A new link from Livestream crew", email.subject
    assert_includes email.html, "<strong>a link</strong>"
  end

  test "custom template: linked text points at the personal link" do
    email = render(groups(:book_club))

    assert_includes email.html, "Hello Ann!"
    assert_includes email.html, %(<a href="#{URL}">join the call here</a>)
    assert_includes email.text, "join the call here (#{URL})"
    assert_not_includes email.html, "{{"
  end

  test "all placeholders, with optional spaces, and unknown ones left alone" do
    group = groups(:livestream)
    group.update!(email_template: "<div>{{ name }}|{{first_name}}|{{title}}|{{group}}|{{link_url}}|{{nope}}|{{link}}</div>",
                  email_subject: "{{first_name}}, {{title}} from {{group}} {{link}}")
    email = render(group)

    assert_includes email.html, %(Ann Lee|Ann|Sunday stream|Livestream crew|<a href="#{URL}">#{URL}</a>|{{nope}}|<a href="#{URL}" style=)
    assert_equal "Ann Lee|Ann|Sunday stream|Livestream crew|#{URL}|{{nope}}|#{URL}", email.text
    assert_equal "Ann, Sunday stream from Livestream crew {{link}}", email.subject, "the link can't go in a subject"
  end

  test "member names and titles are HTML-escaped" do
    email = render(groups(:livestream), name: %(<script>alert("x")</script> Bob), title: "<b>Hi</b>")

    assert_not_includes email.html, "<script>"
    assert_includes email.html, "&lt;script&gt;"
    assert_includes email.html, "&lt;b&gt;Hi&lt;/b&gt;"
    assert_includes email.text, %(Hi <script>alert("x")</script>,), "plain text is not HTML-escaped"
  end

  test "unsafe markup in the template is sanitized" do
    group = groups(:livestream)
    group.update!(email_template: %(<div>{{link}} <a href="javascript:alert(1)">x</a><script>bad()</script><img src="https://evil.example/t.gif" onerror="x()"></div>))
    html = render(group).html

    assert_not_includes html, "javascript:"
    assert_not_includes html, "<script"
    assert_not_includes html, "onerror"
  end

  test "includes_link? recognizes every way of adding the link" do
    assert EmailTemplate.includes_link?("<div>{{link}}</div>")
    assert EmailTemplate.includes_link?("<div>{{ link_url }}</div>")
    assert EmailTemplate.includes_link?(%(<a href="{{link}}">x</a>))
    assert EmailTemplate.includes_link?(%(<a href="%7B%7Blink%7D%7D">x</a>))
    assert_not EmailTemplate.includes_link?("<div>No link {{name}}</div>")
    assert_not EmailTemplate.includes_link?(%(<a href="https://youtube.com/live/x">direct</a>))
  end

  test "custom_body? is false for groups without a template" do
    assert_not groups(:livestream).email_renderer.custom_body?
    assert groups(:book_club).email_renderer.custom_body?
  end
end
