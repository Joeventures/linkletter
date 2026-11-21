require "test_helper"

class MemberTest < ActiveSupport::TestCase
  test "normalizes name and email" do
    member = Member.new(name: "  Dee  ", email_address: " DEE@Example.com ")
    assert_equal "Dee", member.name
    assert_equal "dee@example.com", member.email_address
  end

  test "email must be unique within a group" do
    duplicate = groups(:livestream).members.build(name: "Ann again", email_address: "ANN@example.com")
    assert_not duplicate.valid?
    assert_includes duplicate.errors[:email_address], "is already in this group"
  end

  test "the same email may belong to different groups" do
    member = groups(:book_club).members.build(name: "Ann", email_address: "ann@example.com")
    assert member.valid?
  end

  test "blank email reports only one error" do
    member = groups(:livestream).members.build(name: "No email", email_address: "")
    assert_not member.valid?
    assert_equal [ "can't be blank" ], member.errors[:email_address]
  end

  test "rejects malformed email" do
    assert_not groups(:livestream).members.build(name: "X", email_address: "nope").valid?
  end
end
