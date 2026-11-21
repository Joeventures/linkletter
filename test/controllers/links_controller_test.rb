require "test_helper"

class LinksControllerTest < ActionDispatch::IntegrationTest
  include ActionMailer::TestHelper

  setup { @group = groups(:livestream) }

  test "new" do
    sign_in_as users(:owner)
    get new_group_link_path(@group)
    assert_response :success
  end

  test "creating a link with send_now emails every member" do
    sign_in_as users(:owner)

    assert_difference -> { PersonalLink.count }, 2 do
      assert_enqueued_emails 2 do
        post group_links_path(@group), params: { link: { url: "https://www.youtube.com/live/new", title: "Go" }, send_now: "1" }
      end
    end

    link = Link.find_by!(url: "https://www.youtube.com/live/new")
    assert_redirected_to group_link_path(@group, link)
    assert_match "emailed to 2 members", flash[:notice]
    assert_not_nil link.sent_at
  end

  test "creating a link without send_now does not email anyone" do
    sign_in_as users(:owner)

    assert_no_enqueued_emails do
      post group_links_path(@group), params: { link: { url: "https://example.com/later" } }
    end
    assert_empty Link.find_by!(url: "https://example.com/later").personal_links
  end

  test "rejects an unsafe url" do
    sign_in_as users(:owner)

    assert_no_difference -> { Link.count } do
      post group_links_path(@group), params: { link: { url: "javascript:alert(1)" }, send_now: "1" }
    end
    assert_response :unprocessable_entity
    assert_match "must be a full http", response.body
  end

  test "show lists recipients, unsent members and clicks" do
    personal_links(:ann_stream).clicks.create!(ip_address: "203.0.113.50", browser_name: "Firefox", browser_version: "130.0")
    sign_in_as users(:owner)

    get group_link_path(@group, links(:stream))

    assert_response :success
    assert_match personal_links(:ann_stream).token, response.body
    assert_match "203.0.113.50", response.body
    assert_match "Firefox 130", response.body
    assert_match "Email 1 member who hasn", response.body # Bob hasn't received it
  end

  test "deliver emails only members who haven't received the link" do
    sign_in_as users(:owner)

    assert_enqueued_emails 1 do
      post deliver_group_link_path(@group, links(:stream))
    end
    assert_redirected_to group_link_path(@group, links(:stream))
    assert links(:stream).personal_links.exists?(member: members(:bob))
  end

  test "destroying a link disables its personal links" do
    sign_in_as users(:owner)
    token = personal_links(:ann_stream).token

    delete group_link_path(@group, links(:stream))
    assert_redirected_to group_path(@group)

    get personal_redirect_path(token)
    assert_response :not_found
  end

  test "cannot see, send, or delete another user's link" do
    sign_in_as users(:intruder)

    get group_link_path(@group, links(:stream))
    assert_response :not_found
    post group_links_path(@group), params: { link: { url: "https://evil.example.com" }, send_now: "1" }
    assert_response :not_found
    post deliver_group_link_path(@group, links(:stream))
    assert_response :not_found
    delete group_link_path(@group, links(:stream))
    assert_response :not_found

    assert Link.exists?(links(:stream).id)
    assert_no_enqueued_emails
  end

  test "cannot reach another user's link through one's own group" do
    sign_in_as users(:owner)
    get group_link_path(@group, links(:intruders_link))
    assert_response :not_found
  end
end
