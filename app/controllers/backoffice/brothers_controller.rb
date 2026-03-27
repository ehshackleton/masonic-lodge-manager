module Backoffice
  class BrothersController < ApplicationController
    before_action :require_authentication
    before_action :set_brother, only: %i[show edit update destroy purge_document]
    before_action :load_select_options, only: %i[new edit create update]

    def index
      @q = params[:q].to_s.strip
      @status = params[:status].to_s.strip
      @degree_id = params[:degree_id].to_s.strip

      @brothers = Brother.includes(:current_degree, :lodge).ordered
      @brothers = apply_search(@brothers, @q)
      @brothers = @brothers.where(membership_status: @status) if @status.present?
      @brothers = @brothers.where(current_degree_id: @degree_id) if @degree_id.present?

      @degrees = Degree.order(rank_order: :asc)
    end

    def show
      @degree_histories = @brother.brother_degree_histories.includes(:degree).order(ceremony_date: :desc)
      @office_assignments = @brother.brother_office_assignments.includes(:office).order(start_date: :desc)
      @new_degree_history = @brother.brother_degree_histories.new
      @new_office_assignment = @brother.brother_office_assignments.new
      @degrees = Degree.order(rank_order: :asc)
      @offices = Office.order(:name)
    end

    def new
      @brother = Brother.new(
        lodge: default_lodge,
        active: true,
        membership_status: "active"
      )
    end

    def create
      @brother = Brother.new(brother_params)

      if @brother.save
        redirect_to backoffice_brother_path(@brother), notice: "Hermano creado correctamente."
      else
        render :new, status: :unprocessable_entity
      end
    end

    def edit; end

    def update
      if @brother.update(brother_params)
        attach_documents if params.dig(:brother, :documents).present?
        redirect_to backoffice_brother_path(@brother), notice: "Ficha del hermano actualizada."
      else
        render :edit, status: :unprocessable_entity
      end
    end

    def destroy
      @brother.update(active: false, membership_status: "inactive")
      redirect_to backoffice_brothers_path, notice: "Hermano desactivado."
    end

    def purge_document
      attachment = @brother.documents.attachments.find(params[:attachment_id])
      attachment.purge
      redirect_to backoffice_brother_path(@brother), notice: "Adjunto eliminado."
    end

    private

    def set_brother
      @brother = Brother.find(params[:id])
    end

    def load_select_options
      @lodges = Lodge.order(:name)
      @degrees = Degree.order(rank_order: :asc)
    end

    def default_lodge
      Lodge.first
    end

    def apply_search(scope, query)
      return scope if query.blank?

      pattern = "%#{query.downcase}%"
      scope.where(
        "LOWER(first_name) LIKE :q OR LOWER(last_name) LIKE :q OR LOWER(symbolic_name) LIKE :q OR LOWER(registry_number) LIKE :q OR LOWER(national_id) LIKE :q",
        q: pattern
      )
    end

    def brother_params
      params.require(:brother).permit(
        :lodge_id,
        :registry_number,
        :symbolic_name,
        :first_name,
        :last_name,
        :national_id,
        :birth_date,
        :marital_status,
        :profession,
        :employer,
        :email,
        :phone,
        :mobile_phone,
        :address,
        :city,
        :emergency_contact_name,
        :emergency_contact_phone,
        :spouse_name,
        :father_name,
        :mother_name,
        :initiation_date,
        :exaltation_date,
        :raising_date,
        :current_degree_id,
        :membership_status,
        :status_since,
        :notes_private,
        :deceased_at,
        :active,
        documents: []
      )
    end

    def attach_documents
      @brother.documents.attach(params[:brother][:documents])
    end
  end
end
