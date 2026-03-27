module Backoffice
  class SecretariatController < ApplicationController
    before_action :require_authentication

    def index
      @minutes_recent = Minute.order(session_date: :desc).limit(5)
      @correspondences_recent = Correspondence.order(created_at: :desc).limit(5)
      @pending_correspondences = Correspondence.where(status: %w[pending draft]).count
      @draft_minutes = Minute.where(status: "draft").count
    end
  end
end
