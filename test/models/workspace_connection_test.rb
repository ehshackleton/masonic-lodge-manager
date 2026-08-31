# frozen_string_literal: true

require "test_helper"

class WorkspaceConnectionTest < ActiveSupport::TestCase
  test "encrypts and decrypts oauth tokens" do
    lodge = Lodge.create!(name: "Token Lodge", number: "31")
    conn = WorkspaceConnection.create!(lodge: lodge, provider: "google", status: "disconnected")
    conn.access_token = "plain-access"
    conn.refresh_token = "plain-refresh"
    conn.save!

    reloaded = WorkspaceConnection.find(conn.id)
    assert_equal "plain-access", reloaded.access_token
    assert_equal "plain-refresh", reloaded.refresh_token
    assert_not_equal "plain-access", reloaded.access_token_ciphertext
    assert reloaded.access_token_ciphertext.present?
  end

  test "connected requires refresh token and connected status" do
    lodge = Lodge.create!(name: "Conn Lodge", number: "31")
    conn = WorkspaceConnection.create!(lodge: lodge, status: "connected")
    refute conn.connected?

    conn.refresh_token = "rt"
    conn.save!
    assert conn.connected?
  end
end
