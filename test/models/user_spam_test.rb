require "test_helper"

class UserSpamTest < ActiveSupport::TestCase
  def new_user(**attrs)
    User.new({ first_name: "Ada", last_name: "Okafor", email: "ada#{SecureRandom.hex(3)}@example.com",
               password: "password123", password_confirmation: "password123" }.merge(attrs))
  end

  test "ordinary names are fine, including accents and hyphens" do
    assert new_user(first_name: "José-María", last_name: "O'Neil").valid?
    assert new_user(first_name: "Oluwadárè", last_name: "Adébáyọ̀").valid?
  end

  test "rejects adverts and links in names" do
    assert_not new_user(first_name: "* * * <a href=\"https://google.com\">$3,222 credit available</a> * * *").valid?
    assert_not new_user(last_name: "visit www.example.com").valid?
    assert_not new_user(first_name: "A" * 41).valid?
  end

  test "rejects throwaway email domains, including subdomains" do
    assert_not new_user(email: "2ry~e95v0d4d2y@merepost.com").valid?
    assert_not new_user(email: "bgg@fextemp.com").valid?
    assert_not new_user(email: "x@mail.mailinator.com").valid?
    assert new_user(email: "someone@gmail.com").valid?
  end

  test "existing users with old names can still be saved" do
    user = users(:taylor)
    user.update_column(:first_name, "$$$ spam")
    assert user.reload.update(credits_remaining: 3), "only new sign-ups are checked for throwaway email"
  end
end
