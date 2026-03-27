module Backoffice
  class BrotherOfficeAssignmentsController < ApplicationController
    before_action :require_authentication
    before_action :set_brother

    def create
      assignment = @brother.brother_office_assignments.new(assignment_params)

      if assignment.save
        redirect_to backoffice_brother_path(@brother), notice: "Cargo asignado correctamente."
      else
        redirect_to backoffice_brother_path(@brother), alert: assignment.errors.full_messages.to_sentence
      end
    end

    def destroy
      assignment = @brother.brother_office_assignments.find(params[:id])
      assignment.destroy
      redirect_to backoffice_brother_path(@brother), notice: "Asignacion de cargo eliminada."
    end

    private

    def set_brother
      @brother = Brother.find(params[:brother_id])
    end

    def assignment_params
      params.require(:brother_office_assignment).permit(:office_id, :start_date, :end_date, :notes)
    end
  end
end
