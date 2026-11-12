require "test_helper"

class Users::RegistrationsControllerTest < ActionDispatch::IntegrationTest
  def sign_up(extra = {})
    post user_registration_path, params: {
      form_started_at: 1.minute.ago.to_i,
      user: { first_name: "Ada", last_name: "Okafor", email: "ada-new@example.com",
              password: "password123", password_confirmation: "password123" }
    }.deep_merge(extra)
  end

  test "a person can sign up" do
    assert_difference("User.count", 1) { sign_up }
  end

  test "the hidden honeypot field blocks bots" do
    assert_no_difference("User.count") { sign_up(website: "http://spam.example") }
  end

  test "submitting instantly blocks bots" do
    assert_no_difference("User.count") { sign_up(form_started_at: Time.current.to_i) }
  end

  test "spam names are refused" do
    assert_no_difference("User.count") { sign_up(user: { first_name: "$3,222 credit available" }) }
  end
end
