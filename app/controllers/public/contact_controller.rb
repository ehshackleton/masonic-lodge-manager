module Public
  class ContactController < ApplicationController
    def index
      @contact_message = ContactMessage.new
    end

    def create
      # Honeypot: bots that fill "website" are discarded silently.
      if params.dig(:contact_message, :website).present?
        redirect_to contacto_path, notice: "Mensaje recibido. Gracias por escribirnos."
        return
      end

      @contact_message = ContactMessage.new(contact_message_params)

      if @contact_message.save
        redirect_to contacto_path, notice: "Mensaje recibido. Gracias por escribirnos."
      else
        flash.now[:alert] = "No pudimos enviar el mensaje. Revise los campos e intente nuevamente."
        render :index, status: :unprocessable_entity
      end
    end

    private

    def contact_message_params
      params.require(:contact_message).permit(:name, :email, :phone, :subject, :message)
    end
  end
end
