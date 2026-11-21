require "test_helper"

class EmailTemplatesControllerTest < ActionDispatch::IntegrationTest
  setup { @group = groups(:livestream) }

  test "edit starts from the default email and shows link instructions" do
    sign_in_as users(:owner)
    get edit_group_email_template_path(@group), headers: { "User-Agent" => MODERN_UA }

    assert_response :success
    assert_select "trix-editor"
    assert_select "button", text: /Insert link button/
    assert_select "button", text: /Link selected text/
    assert_match "How to add the personal link", response.body
    assert_match "{{link}}", response.body
    assert_match ERB::Util.h("{{group}} has shared"), response.body # default body pre-filled
  end

  test "edit shows the saved custom template" do
    sign_in_as users(:owner)
    get edit_group_email_template_path(groups(:book_club)), headers: { "User-Agent" => MODERN_UA }
    assert_match ERB::Util.h("join the call here"), response.body
    assert_select "button", text: /Reset to the default email/
  end

  test "update saves the template and shows the preview" do
    sign_in_as users(:owner)
    patch group_email_template_path(@group), params: { group: { email_subject: "Watch: {{title}}", email_template: "<div>Hey {{first_name}} {{link}}</div>" } }

    assert_redirected_to group_email_template_path(@group)
    @group.reload
    assert_equal "Watch: {{title}}", @group.email_subject
    assert_includes @group.email_template.body.to_html, "Hey {{first_name}} {{link}}"

    follow_redirect!
    assert_match "Watch: Live now", response.body # subject rendered with the group's latest link title
    assert_match "Hey Ann", response.body
  end

  test "update without the personal link is rejected" do
    sign_in_as users(:owner)
    patch group_email_template_path(@group), params: { group: { email_template: "<div>Just https://www.youtube.com/live/abc</div>" } }

    assert_response :unprocessable_entity
    assert_match "must include the personal link", response.body
    assert_not @group.reload.email_renderer.custom_body?
  end

  test "preview works with the default email" do
    sign_in_as users(:owner)
    get group_email_template_path(@group)

    assert_response :success
    assert_match "Default email", response.body
    assert_match "Open link", response.body
  end

  test "reset returns to the default email" do
    group = groups(:book_club)
    group.update!(email_subject: "Custom")
    sign_in_as users(:owner)

    delete group_email_template_path(group)

    assert_redirected_to group_email_template_path(group)
    group.reload
    assert_not group.email_renderer.custom_body?
    assert_nil group.email_subject
  end

  test "cannot view or change another user's template" do
    sign_in_as users(:intruder)

    get group_email_template_path(@group)
    assert_response :not_found
    get edit_group_email_template_path(@group)
    assert_response :not_found
    patch group_email_template_path(@group), params: { group: { email_template: "<div>{{link}} hacked</div>" } }
    assert_response :not_found
    delete group_email_template_path(groups(:book_club))
    assert_response :not_found

    assert_not @group.reload.email_renderer.custom_body?
    assert groups(:book_club).reload.email_renderer.custom_body?
  end

  test "requires sign in" do
    get edit_group_email_template_path(@group)
    assert_redirected_to new_session_path
  end
end
