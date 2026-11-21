require "test_helper"

class LinkMailerTest < ActionMailer::TestCase
  test "personal_link email contains the member's own tracked url" do
    personal_link = personal_links(:ann_stream)
    email = LinkMailer.with(personal_link: personal_link).personal_link

    assert_emails(1) { email.deliver_now }
    assert_equal [ "ann@example.com" ], email.to
    assert_equal "Live now", email.subject

    url = "http://example.com/l/#{personal_link.token}"
    assert_includes email.html_part.body.to_s, url
    assert_includes email.text_part.body.to_s, url
    assert_includes email.text_part.body.to_s, "Hi Ann"

    # The destination itself is never exposed, so every visit is tracked.
    assert_not_includes email.html_part.body.to_s, links(:stream).url
  end

  test "subject falls back to the group name when the link has no title" do
    links(:stream).update!(title: nil)
    email = LinkMailer.with(personal_link: personal_links(:ann_stream)).personal_link
    assert_equal "A new link from Livestream crew", email.subject
  end
end
