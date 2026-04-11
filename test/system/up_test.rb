require "application_system_test_case"

class UpTest < ApplicationSystemTestCase
  test "health endpoint is reachable" do
    visit "/up"
    assert_match(/background-color:\s*green/i, page.body)
  end
end
