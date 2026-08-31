# frozen_string_literal: true

require "test_helper"
require "webmock/minitest"

class WorkspaceImportGmailCorrespondencesTest < ActiveSupport::TestCase
  setup do
    WebMock.disable_net_connect!(allow_localhost: true)
    ENV["GOOGLE_CLIENT_ID"] = "test-client-id"
    ENV["GOOGLE_CLIENT_SECRET"] = "test-client-secret"

    @lodge = Lodge.create!(name: "Amenti Test", number: "31")
    @connection = WorkspaceConnection.create!(
      lodge: @lodge,
      provider: "google",
      status: "connected",
      account_email: "amentidiez31@example.com"
    )
    @connection.access_token = "access-token"
    @connection.refresh_token = "refresh-token"
    @connection.expires_at = 1.hour.from_now
    @connection.save!
  end

  teardown do
    WebMock.reset!
    ENV.delete("GOOGLE_CLIENT_ID")
    ENV.delete("GOOGLE_CLIENT_SECRET")
  end

  test "imports new gmail messages as draft correspondences without duplicates" do
    stub_request(:get, %r{\Ahttps://gmail\.googleapis\.com/gmail/v1/users/me/messages\?})
      .to_return(
        status: 200,
        body: { messages: [ { id: "msg-1" }, { id: "msg-2" } ] }.to_json,
        headers: { "Content-Type" => "application/json" }
      )

    stub_request(:get, %r{\Ahttps://gmail\.googleapis\.com/gmail/v1/users/me/messages/msg-1})
      .to_return(status: 200, body: gmail_message_payload("msg-1", "Asunto uno", "remitente@example.com").to_json,
                 headers: { "Content-Type" => "application/json" })
    stub_request(:get, %r{\Ahttps://gmail\.googleapis\.com/gmail/v1/users/me/messages/msg-2})
      .to_return(status: 200, body: gmail_message_payload("msg-2", "Asunto dos", "otro@example.com").to_json,
                 headers: { "Content-Type" => "application/json" })

    result = Workspace::ImportGmailCorrespondences.new(lodge: @lodge, connection: @connection).call
    assert_equal 2, result[:imported]
    assert_equal 0, result[:skipped]
    assert_equal 2, Correspondence.where(lodge: @lodge).count
    assert Correspondence.where(lodge: @lodge).all?(&:status_draft?)
    assert_equal 2, WorkspaceLink.gmail_messages.where(lodge: @lodge).count

    result2 = Workspace::ImportGmailCorrespondences.new(lodge: @lodge, connection: @connection).call
    assert_equal 0, result2[:imported]
    assert_equal 2, result2[:skipped]
    assert_equal 2, Correspondence.where(lodge: @lodge).count
  end

  private

  def gmail_message_payload(id, subject, from)
    {
      id: id,
      threadId: "thread-#{id}",
      snippet: "snippet",
      payload: {
        headers: [
          { name: "Subject", value: subject },
          { name: "From", value: "Nombre <#{from}>" },
          { name: "Date", value: "Mon, 31 Aug 2026 12:00:00 +0000" }
        ]
      }
    }
  end
end
