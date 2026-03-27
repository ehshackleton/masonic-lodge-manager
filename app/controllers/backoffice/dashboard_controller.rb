module Backoffice
  class DashboardController < ApplicationController
    before_action :require_authentication

    def index
      @active_brothers_count = Brother.where(active: true, membership_status: "active").count
      @overdue_charges_count = Charge.where(status: %w[pending partial]).where("due_on < ?", Date.current).count
      @recent_payments_count = Payment.where("paid_on >= ?", Date.current - 30.days).count
      @pending_works_count = MasonicWork.where(status: %w[assigned draft in_review]).count
      @dashboard_last_updated_at = Time.current
    end
    def registry; render :index; end
    def treasury
      redirect_to "/backoffice/tesoreria"
    end
    def secretariat
      redirect_to "/backoffice/secretaria"
    end
    def works
      redirect_to "/backoffice/masonic_works"
    end
    def administration; render :index; end
  end
end
