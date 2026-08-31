module Backoffice
  class DashboardController < ApplicationController
    before_action :require_authentication

    def index
      lodge = current_lodge
      @dashboard_last_updated_at = Time.current
      @can_registry = current_user.can_access_module?(:registry)
      @can_treasury = current_user.can_access_module?(:treasury)
      @can_secretariat = current_user.can_access_module?(:secretariat)
      @can_works = current_user.can_access_module?(:works)
      @can_hospital = current_user.can_access_module?(:hospital)
      @can_administration = current_user.has_role?(:superadmin)

      @active_brothers_count = if @can_registry && lodge
                                 Brother.where(lodge_id: lodge.id, active: true, membership_status: "active").count
      else
                                 nil
      end
      @overdue_charges_count = if @can_treasury && lodge
                                 Charge.joins(:brother).where(brothers: { lodge_id: lodge.id }, status: %w[pending partial]).where("due_on < ?", Date.current).count
      else
                                 nil
      end
      @recent_payments_count = if @can_treasury && lodge
                                 Payment.joins(:brother).where(brothers: { lodge_id: lodge.id }).where("paid_on >= ?", Date.current - 30.days).count
      else
                                 nil
      end
      @pending_works_count = if @can_works && lodge
                               MasonicWork.where(lodge_id: lodge.id, status: %w[assigned draft in_review]).count
      else
                               nil
      end
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
