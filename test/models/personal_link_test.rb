require "test_helper"

class PersonalLinkTest < ActiveSupport::TestCase
  IPHONE_UA = "Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Mobile/15E148 Safari/604.1".freeze

  test "generates a long base58 token" do
    personal_link = links(:stream).personal_links.create!(member: members(:bob))
    assert_match RedirectsController::TOKEN_FORMAT, personal_link.token
  end

  test "tokens are unique" do
    tokens = Array.new(2) { |i| links(:unsent).personal_links.create!(member: [ members(:ann), members(:bob) ][i]).token }
    assert_equal 2, tokens.uniq.size
  end

  test "a member gets only one personal link per link" do
    duplicate = links(:stream).personal_links.build(member: members(:ann))
    assert_not duplicate.valid?
  end

  test "member must belong to the link's group" do
    personal_link = links(:stream).personal_links.build(member: members(:cy))
    assert_not personal_link.valid?
    assert_includes personal_link.errors[:member], "must belong to the link's group"
  end

  test "record_click! stores request details and updates totals" do
    personal_link = personal_links(:ann_stream)
    request = fake_request(user_agent: IPHONE_UA, ip: "203.0.113.9", language: "en-US,en;q=0.9", referer: "https://mail.example.com/")

    click = personal_link.record_click!(request)

    assert_equal "203.0.113.9", click.ip_address
    assert_equal IPHONE_UA, click.user_agent
    assert_equal "Safari", click.browser_name
    assert_equal "17.0", click.browser_version
    assert_equal "iOS (iPhone)", click.platform
    assert_equal "mobile", click.device_type
    assert_equal "en-US,en;q=0.9", click.accept_language
    assert_equal "https://mail.example.com/", click.referrer
    assert_not click.bot
    assert_equal "Safari 17", click.browser_summary

    personal_link.reload
    assert_equal 1, personal_link.clicks_count
    assert_equal personal_link.first_clicked_at, personal_link.last_clicked_at
  end

  test "record_click! keeps the first click time and advances the last" do
    personal_link = personal_links(:ann_stream)

    travel_to 2.hours.ago do
      personal_link.record_click!(fake_request)
    end
    personal_link.record_click!(fake_request)

    personal_link.reload
    assert_equal 2, personal_link.clicks_count
    assert_operator personal_link.first_clicked_at, :<, personal_link.last_clicked_at
  end

  test "record_click! flags bots" do
    click = personal_links(:ann_stream).record_click!(fake_request(user_agent: "Googlebot/2.1 (+http://www.google.com/bot.html)"))
    assert click.bot
    assert_empty Click.humans.where(id: click.id)
  end

  test "record_click! tolerates a missing user agent" do
    click = personal_links(:ann_stream).record_click!(fake_request(user_agent: nil))
    assert click.persisted?
    assert_equal "", click.user_agent
  end

  test "record_click! truncates oversized headers instead of failing" do
    click = personal_links(:ann_stream).record_click!(fake_request(user_agent: "A" * 5000, language: "x" * 3000))
    assert_equal 1000, click.user_agent.bytesize
    assert_equal 255, click.accept_language.bytesize
  end

  test "record_click! truncates multibyte headers by bytes without splitting characters" do
    click = personal_links(:ann_stream).record_click!(fake_request(user_agent: "\u{1F600}" * 1000, language: "\u00E9" * 1000))
    assert_operator click.user_agent.bytesize, :<=, 1000
    assert_operator click.accept_language.bytesize, :<=, 255
    assert click.user_agent.valid_encoding?
    assert click.accept_language.valid_encoding?
  end

  private
    def fake_request(user_agent: IPHONE_UA, ip: "198.51.100.7", language: nil, referer: nil)
      env = { "REMOTE_ADDR" => ip }
      env["HTTP_USER_AGENT"] = user_agent if user_agent
      env["HTTP_ACCEPT_LANGUAGE"] = language if language
      env["HTTP_REFERER"] = referer if referer
      ActionDispatch::Request.new(Rack::MockRequest.env_for("/", env))
    end
end
