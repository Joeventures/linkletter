require "test_helper"

class MembersControllerTest < ActionDispatch::IntegrationTest
  setup { @group = groups(:livestream) }

  test "adds a member" do
    sign_in_as users(:owner)
    assert_difference -> { @group.members.count } do
      post group_members_path(@group), params: { member: { name: "Dee", email_address: "dee@example.com" } }
    end
    assert_redirected_to group_path(@group)
  end

  test "reports a duplicate member" do
    sign_in_as users(:owner)
    assert_no_difference -> { Member.count } do
      post group_members_path(@group), params: { member: { name: "Ann", email_address: "ann@example.com" } }
    end
    assert_match "already in this group", flash[:alert]
  end

  test "bulk imports members in several formats and skips bad lines" do
    sign_in_as users(:owner)
    text = <<~TEXT
      Dee, dee@example.com
      Ed <ed@example.com>
      "Fay Q" <fay@example.com>
      Gus\tgus@example.com
      hal@example.com

      junk line
      ann@example.com
    TEXT

    assert_difference -> { @group.members.count }, 5 do
      post import_group_members_path(@group), params: { members_text: text }
    end

    assert_equal "5 members added.", flash[:notice]
    assert_match "junk line", flash[:alert]
    assert_match "ann@example.com", flash[:alert]
    assert_equal({ "Dee" => "dee@example.com", "Ed" => "ed@example.com", "Fay Q" => "fay@example.com", "Gus" => "gus@example.com", "hal" => "hal@example.com" },
                 @group.members.where.not(id: [ members(:ann).id, members(:bob).id ]).pluck(:name, :email_address).to_h)
  end

  test "edits and removes a member" do
    sign_in_as users(:owner)
    get edit_group_member_path(@group, members(:bob))
    assert_response :success

    patch group_member_path(@group, members(:bob)), params: { member: { name: "Robert" } }
    assert_equal "Robert", members(:bob).reload.name

    assert_difference -> { Member.count }, -1 do
      delete group_member_path(@group, members(:bob))
    end
  end

  test "cannot add to, edit, or remove from another user's group" do
    sign_in_as users(:intruder)

    post group_members_path(@group), params: { member: { name: "Spy", email_address: "spy@example.com" } }
    assert_response :not_found
    post import_group_members_path(@group), params: { members_text: "Spy, spy@example.com" }
    assert_response :not_found
    patch group_member_path(@group, members(:ann)), params: { member: { email_address: "spy@example.com" } }
    assert_response :not_found
    delete group_member_path(@group, members(:ann))
    assert_response :not_found

    assert_equal "ann@example.com", members(:ann).reload.email_address
  end

  test "cannot reach another user's member through one's own group" do
    sign_in_as users(:owner)
    delete group_member_path(@group, members(:mallory))
    assert_response :not_found
    assert Member.exists?(members(:mallory).id)
  end
end
