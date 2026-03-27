module Backoffice
  class BrotherDegreeHistoriesController < ApplicationController
    before_action :require_authentication
    before_action :set_brother

    def create
      history = @brother.brother_degree_histories.new(history_params)

      if history.save
        @brother.update(current_degree_id: history.degree_id) if history.degree_id.present?
        redirect_to backoffice_brother_path(@brother), notice: "Historial de grado agregado."
      else
        redirect_to backoffice_brother_path(@brother), alert: history.errors.full_messages.to_sentence
      end
    end

    def destroy
      history = @brother.brother_degree_histories.find(params[:id])
      history.destroy
      redirect_to backoffice_brother_path(@brother), notice: "Registro de grado eliminado."
    end

    private

    def set_brother
      @brother = Brother.find(params[:brother_id])
    end

    def history_params
      params.require(:brother_degree_history).permit(:degree_id, :ceremony_date, :notes)
    end
  end
end
