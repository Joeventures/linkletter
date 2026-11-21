require "test_helper"

class GroupTest < ActiveSupport::TestCase
  test "a custom email template must include the personal link" do
    group = groups(:livestream)
    group.email_template = "<div>Hi {{name}}, see https://www.youtube.com/live/abc</div>"

    assert_not group.valid?
    assert_match "must include the personal link", group.errors[:email_template].first
  end

  test "a template with the link is valid" do
    group = groups(:livestream)
    group.email_template = %(<div>Hi, <a href="{{link}}">watch</a></div>)
    assert group.valid?
  end

  test "saving a group without a template doesn't create an empty rich text" do
    assert_no_difference -> { ActionText::RichText.count } do
      groups(:livestream).update!(name: "Renamed")
    end
  end

  test "normalizes and limits the subject" do
    group = groups(:livestream)
    group.email_subject = "  Hello   {{first_name}} "
    assert_equal "Hello {{first_name}}", group.email_subject

    group.email_subject = "x" * 201
    assert_not group.valid?
  end

  test "destroying a group removes its template" do
    assert_difference -> { ActionText::RichText.count }, -1 do
      groups(:book_club).destroy
    end
  end
end
