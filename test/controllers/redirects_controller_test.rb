require "test_helper"

class RedirectsControllerTest < ActionDispatch::IntegrationTest
  setup { @personal_link = personal_links(:ann_stream) }

  test "redirects to the destination and records the click without signing in" do
    assert_difference -> { @personal_link.clicks.count } do
      get personal_redirect_path(@personal_link.token),
          headers: { "User-Agent" => MODERN_UA, "Accept-Language" => "en-GB" },
          env: { "REMOTE_ADDR" => "203.0.113.9" }
    end

    assert_redirected_to "https://www.youtube.com/live/abc123"
    click = @personal_link.clicks.first
    assert_equal "203.0.113.9", click.ip_address
    assert_equal "Chrome", click.browser_name
    assert_equal "en-GB", click.accept_language
    assert_equal 1, @personal_link.reload.clicks_count
  end

  test "sets privacy headers so the token is not leaked or cached" do
    get personal_redirect_path(@personal_link.token)

    assert_equal "no-referrer", response.headers["Referrer-Policy"]
    assert_equal "no-store", response.headers["Cache-Control"]
    assert_equal "noindex, nofollow", response.headers["X-Robots-Tag"]
  end

  test "still redirects old browsers that the management UI would block" do
    get personal_redirect_path(@personal_link.token), headers: { "User-Agent" => "Mozilla/4.0 (compatible; MSIE 8.0; Windows NT 6.1)" }
    assert_response :redirect
    assert_equal "Internet Explorer", @personal_link.clicks.first.browser_name
  end

  test "records bot clicks but flags them" do
    get personal_redirect_path(@personal_link.token), headers: { "User-Agent" => "Googlebot/2.1 (+http://www.google.com/bot.html)" }
    assert_response :redirect
    assert @personal_link.clicks.first.bot
  end

  test "unknown token is a 404" do
    assert_no_difference -> { Click.count } do
      get personal_redirect_path("NotARealTokenButRightShape123456")
    end
    assert_response :not_found
  end

  [ "short", "AnnStreamToken123456789abcdefgh0", "AnnStreamToken123456789abcdefghiX" ].each do |token|
    test "malformed token #{token.inspect} is a 404" do
      get personal_redirect_path(token)
      assert_response :not_found
    end
  end

  test "tokens are case sensitive" do
    get personal_redirect_path(@personal_link.token.swapcase)
    assert_response :not_found
  end

  test "redirects even if click tracking fails" do
    PersonalLink.class_eval { alias_method :original_record_click!, :record_click! }
    PersonalLink.define_method(:record_click!) { |_request| raise ActiveRecord::StatementInvalid, "boom" }

    get personal_redirect_path(@personal_link.token)
    assert_redirected_to "https://www.youtube.com/live/abc123"
  ensure
    PersonalLink.class_eval do
      alias_method :record_click!, :original_record_click!
      remove_method :original_record_click!
    end
  end
end
