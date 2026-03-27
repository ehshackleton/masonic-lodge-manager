module Backoffice
  class WorkReviewsController < ApplicationController
    before_action :require_authentication
    before_action :authorize_works_module_access!
    before_action :set_masonic_work
    before_action :set_work_review, only: :destroy
    before_action only: :create do
      authorize_review_action!(:create_review)
    end
    before_action only: :destroy do
      authorize_review_action!(:destroy_review)
    end

    def create
      @work_review = @masonic_work.work_reviews.new(work_review_params)
      if @work_review.save
        audit_action("masonic_work.review.create", @masonic_work, review_id: @work_review.id, review_status: @work_review.status)
        redirect_to backoffice_masonic_work_path(@masonic_work), notice: "Revision registrada."
      else
        redirect_to backoffice_masonic_work_path(@masonic_work), alert: @work_review.errors.full_messages.to_sentence.presence || "No se pudo registrar la revision."
      end
    end

    def destroy
      review_id = @work_review.id
      @work_review.destroy
      audit_action("masonic_work.review.destroy", @masonic_work, review_id: review_id)
      redirect_to backoffice_masonic_work_path(@masonic_work), notice: "Revision eliminada."
    end

    private

    def set_masonic_work
      @masonic_work = MasonicWork.find(params[:masonic_work_id])
    end

    def set_work_review
      @work_review = @masonic_work.work_reviews.find(params[:id])
    end

    def work_review_params
      params.require(:work_review).permit(:reviewer_user_id, :reviewed_on, :status, :comments)
    end

    def audit_action(action, auditable, metadata = {})
      AuditLog.record!(
        user: current_user,
        action: action,
        auditable: auditable,
        metadata: metadata,
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
    end

    def authorize_review_action!(action)
      return if current_user&.can_manage_masonic_work_action?(action)

      AuditLog.record!(
        user: current_user,
        action: "permission.denied.work_review",
        auditable: @masonic_work,
        metadata: {
          denied_action: action.to_s,
          path: request.path,
          method: request.request_method
        },
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
      redirect_to backoffice_masonic_work_path(@masonic_work), alert: "No tienes permisos para gestionar revisiones."
    end

    def authorize_works_module_access!
      return if current_user&.can_access_module?(:works)

      AuditLog.record!(
        user: current_user,
        action: "permission.denied.works.module",
        auditable: current_user,
        metadata: { path: request.path, method: request.request_method },
        ip_address: request.remote_ip,
        user_agent: request.user_agent
      )
      redirect_to "/backoffice", alert: "No tienes permisos para acceder a Trabajos Masonicos."
    end
  end
end
