module Public
  class SessionsController < ApplicationController
    MAX_FAILED_ATTEMPTS = 5

    def new
      redirect_to "/backoffice" if user_signed_in?
    end

    def create
      user = User.find_by(email: session_params[:email].to_s.strip.downcase)

      if user&.locked?
        redirect_to "/iniciar-sesion", alert: "Cuenta bloqueada temporalmente. Contacte al administrador."
        return
      end

      if user&.authenticate(session_params[:password])
        user.update!(failed_attempts: 0, locked_at: nil, last_sign_in_at: Time.current)
        session[:user_id] = user.id
        redirect_to "/backoffice", notice: "Sesion iniciada correctamente."
      else
        register_failed_attempt(user) if user
        redirect_to "/iniciar-sesion", alert: "Correo o contrasena incorrectos."
      end
    end

    def destroy
      reset_session
      redirect_to "/", notice: "Sesion cerrada."
    end

    private

    def session_params
      params.permit(:email, :password)
    end

    def register_failed_attempt(user)
      attempts = user.failed_attempts.to_i + 1
      lock_time = attempts >= MAX_FAILED_ATTEMPTS ? Time.current : nil
      user.update(failed_attempts: attempts, locked_at: lock_time)
    end
  end
end
