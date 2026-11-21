require "test_helper"

class GroupsControllerTest < ActionDispatch::IntegrationTest
  test "management pages require sign in" do
    [ root_path, groups_path, group_path(groups(:livestream)), group_link_path(groups(:livestream), links(:stream)) ].each do |path|
      get path
      assert_redirected_to new_session_path, "expected #{path} to require sign in"
    end
  end

  test "index lists only the signed-in user's groups" do
    sign_in_as users(:owner)
    get groups_path

    assert_response :success
    assert_match "Livestream crew", response.body
    assert_match "Book club", response.body
    assert_no_match "Intruder", response.body
  end

  test "show" do
    sign_in_as users(:owner)
    get group_path(groups(:livestream))

    assert_response :success
    assert_match "ann@example.com", response.body
    assert_match "Live now", response.body
  end

  test "creates a group" do
    sign_in_as users(:owner)
    assert_difference -> { users(:owner).groups.count } do
      post groups_path, params: { group: { name: "New group", description: "Hi" } }
    end
    assert_redirected_to group_path(Group.last)
  end

  test "rejects a group without a name" do
    sign_in_as users(:owner)
    assert_no_difference -> { Group.count } do
      post groups_path, params: { group: { name: "" } }
    end
    assert_response :unprocessable_entity
  end

  test "ignores an attempt to assign the group to another user" do
    sign_in_as users(:owner)
    post groups_path, params: { group: { name: "Sneaky", user_id: users(:intruder).id } }
    assert_equal users(:owner), Group.find_by!(name: "Sneaky").user
  end

  test "updates and destroys a group" do
    sign_in_as users(:owner)
    patch group_path(groups(:book_club)), params: { group: { name: "Renamed" } }
    assert_equal "Renamed", groups(:book_club).reload.name

    assert_difference -> { Group.count }, -1 do
      delete group_path(groups(:book_club))
    end
    assert_redirected_to groups_path
  end

  test "cannot see or change another user's group" do
    sign_in_as users(:intruder)
    group = groups(:livestream)

    get group_path(group)
    assert_response :not_found
    get edit_group_path(group)
    assert_response :not_found
    patch group_path(group), params: { group: { name: "Hacked" } }
    assert_response :not_found
    delete group_path(group)
    assert_response :not_found

    assert_equal "Livestream crew", group.reload.name
  end
end
