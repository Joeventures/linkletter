require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "normalizes email address" do
    user = User.new(email_address: "  Someone@Example.COM ")
    assert_equal "someone@example.com", user.email_address
  end

  test "requires a password of at least 12 characters" do
    user = User.new(email_address: "new@example.com", password: "short")
    assert_not user.valid?
    assert user.errors.of_kind?(:password, :too_short)

    user.password = "long-enough-password"
    assert user.valid?
  end

  test "requires a unique, well-formed email address" do
    assert_not User.new(email_address: "not-an-email", password: "long-enough-password").valid?
    assert_not User.new(email_address: users(:owner).email_address.upcase, password: "long-enough-password").valid?
  end

  test "destroying a user removes their groups" do
    assert_difference -> { Group.count }, -users(:owner).groups.count do
      users(:owner).destroy
    end
  end
end
