ENV["RAILS_ENV"] ||= "test"
require_relative "../config/environment"
require "rails/test_help"

module ActiveSupport
  class TestCase
    parallelize(workers: :number_of_processors)

    fixtures :all
  end
end

module SignInHelper
  PASSWORD = "correct-horse-battery".freeze
  MODERN_UA = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/140.0.0.0 Safari/537.36".freeze

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: PASSWORD }
    assert_redirected_to root_url
  end
end

class ActionDispatch::IntegrationTest
  include SignInHelper
end
