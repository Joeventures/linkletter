require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  test "sign in page" do
    get new_session_path, headers: { "User-Agent" => MODERN_UA }
    assert_response :success
  end

  test "signs in with valid credentials" do
    sign_in_as users(:owner)
    assert cookies[:session_id].present?
  end

  test "rejects a wrong password" do
    post session_path, params: { email_address: users(:owner).email_address, password: "wrong-password!!" }
    assert_redirected_to new_session_path
    assert cookies[:session_id].blank?
  end

  test "signs out" do
    sign_in_as users(:owner)
    delete session_path
    assert_redirected_to new_session_path

    get root_path
    assert_redirected_to new_session_path
  end
end
