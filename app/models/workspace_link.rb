# frozen_string_literal: true

class WorkspaceLink < ApplicationRecord
  belongs_to :lodge
  belongs_to :linkable, polymorphic: true

  RESOURCE_TYPES = %w[gmail_message gmail_thread calendar_event drive_file].freeze

  validates :provider, :resource_type, :external_id, presence: true
  validates :resource_type, inclusion: { in: RESOURCE_TYPES }
  validates :external_id, uniqueness: { scope: [ :provider, :resource_type ] }

  scope :gmail_messages, -> { where(resource_type: "gmail_message") }
  scope :calendar_events, -> { where(resource_type: "calendar_event") }
  scope :drive_files, -> { where(resource_type: "drive_file") }

  def self.upsert_for!(lodge:, linkable:, resource_type:, external_id:, external_url: nil, metadata: {})
    link = find_or_initialize_by(provider: "google", resource_type: resource_type, external_id: external_id)
    link.lodge = lodge
    link.linkable = linkable
    link.external_url = external_url
    link.metadata = (link.metadata || {}).merge(metadata.stringify_keys)
    link.save!
    link
  end
end
