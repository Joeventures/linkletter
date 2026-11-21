require "test_helper"

class LinkTest < ActiveSupport::TestCase
  include ActionMailer::TestHelper

  %w[
    https://www.youtube.com/live/abc123
    http://example.com/path?query=1
  ].each do |url|
    test "accepts #{url}" do
      assert groups(:livestream).links.build(url: url).valid?
    end
  end

  [
    "javascript:alert(1)",
    "data:text/html,<script>alert(1)</script>",
    "ftp://example.com/file",
    "/relative/path",
    "//example.com/protocol-relative",
    "https://",
    "not a url",
    "http://exa mple.com"
  ].each do |url|
    test "rejects #{url.inspect}" do
      link = groups(:livestream).links.build(url: url)
      assert_not link.valid?
      assert link.errors[:url].any?
    end
  end

  test "strips whitespace from url" do
    assert_equal "https://example.com", Link.new(url: "  https://example.com \n").url
  end

  test "display_title falls back to the url" do
    assert_equal "Live now", links(:stream).display_title
    assert_equal links(:intruders_link).url, links(:intruders_link).display_title
  end

  test "deliver_to_members creates a personal link for each member and emails them" do
    link = links(:unsent)

    assert_difference -> { link.personal_links.count }, 2 do
      assert_enqueued_emails 2 do
        link.deliver_to_members
      end
    end

    assert_equal [ members(:ann), members(:bob) ].sort_by(&:id), link.personal_links.map(&:member).sort_by(&:id)
    assert link.personal_links.all?(&:sent_at)
    assert_not_nil link.reload.sent_at
  end

  test "deliver_to_members only emails members who haven't received the link" do
    link = links(:stream) # Ann already has a personal link
    assert_equal [ members(:bob) ], link.unsent_members.to_a

    assert_enqueued_emails 1 do
      link.deliver_to_members
    end
    assert_empty link.unsent_members

    assert_no_enqueued_emails do
      link.deliver_to_members
    end
  end

  test "destroying a link removes personal links and clicks" do
    personal_links(:ann_stream).clicks.create!(ip_address: "203.0.113.1")

    assert_difference -> { PersonalLink.count } => -1, -> { Click.count } => -1 do
      links(:stream).destroy
    end
  end
end
