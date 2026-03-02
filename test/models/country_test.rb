require "test_helper"

class CountryTest < ActiveSupport::TestCase
  setup do
    @nigeria = countries(:nigeria)
    @us = countries(:united_states)
  end

  test "valid country" do
    assert @nigeria.valid?
  end

  test "code is primary key" do
    assert_equal "NG", @nigeria.code
    assert_equal "US", @us.code
  end

  test "returns correct currency" do
    assert_equal "NGN", @nigeria.currency
    assert_equal "USD", @us.currency
  end
end
