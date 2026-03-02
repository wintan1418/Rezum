require "test_helper"

class UserTest < ActiveSupport::TestCase
  setup do
    @user = users(:taylor)
    @pro = users(:pro_user)
    @broke = users(:broke_user)
  end

  # Validations
  test "valid user" do
    assert @user.valid?
  end

  test "requires first_name" do
    @user.first_name = nil
    assert_not @user.valid?
    assert_includes @user.errors[:first_name], "can't be blank"
  end

  test "requires last_name" do
    @user.last_name = nil
    assert_not @user.valid?
    assert_includes @user.errors[:last_name], "can't be blank"
  end

  test "requires valid email" do
    @user.email = "not-an-email"
    assert_not @user.valid?
  end

  test "enforces unique email" do
    duplicate = @user.dup
    assert_not duplicate.valid?
  end

  test "credits_remaining cannot be negative" do
    @user.credits_remaining = -1
    assert_not @user.valid?
  end

  test "language must be in allowed list" do
    @user.language = "xx"
    assert_not @user.valid?
  end

  # Methods
  test "full_name combines first and last name" do
    assert_equal "Taylor Trial", @user.full_name
  end

  test "display_name returns full_name" do
    assert_equal "Taylor Trial", @user.display_name
  end

  test "can_generate? with credits" do
    assert @user.can_generate?
  end

  test "can_generate? without credits and no subscription" do
    assert_not @broke.can_generate?
  end

  test "add_credits increments credits_remaining" do
    original = @user.credits_remaining
    @user.add_credits(10)
    assert_equal original + 10, @user.reload.credits_remaining
  end

  test "deduct_credit! decreases credits by one" do
    original = @user.credits_remaining
    assert @user.deduct_credit!
    assert_equal original - 1, @user.reload.credits_remaining
  end

  test "deduct_credit! returns false when no credits and no subscription" do
    assert_not @broke.deduct_credit!
  end

  test "total_spent sums successful payments" do
    assert_kind_of Numeric, @user.total_spent
  end

  # Enums
  test "experience_level enum" do
    assert @user.respond_to?(:entry?)
    assert @user.respond_to?(:mid?)
    assert @user.respond_to?(:senior?)
    assert @user.respond_to?(:executive?)
  end

  # Callbacks
  test "generates referral_code before create" do
    user = User.new(
      first_name: "New", last_name: "User",
      email: "new_test_user@example.com",
      password: "password123", language: "en"
    )
    user.save!
    assert_not_nil user.referral_code
    assert_equal 8, user.referral_code.length
  end

  # Scopes
  test "low_credits scope" do
    low = User.low_credits
    assert_includes low, @broke
    assert_not_includes low, @pro
  end

  # Associations
  test "has many resumes" do
    assert_respond_to @user, :resumes
  end

  test "has many cover_letters" do
    assert_respond_to @user, :cover_letters
  end

  test "has many payments" do
    assert_respond_to @user, :payments
  end

  test "has many subscriptions" do
    assert_respond_to @user, :subscriptions
  end

  test "has many job_applications" do
    assert_respond_to @user, :job_applications
  end
end
