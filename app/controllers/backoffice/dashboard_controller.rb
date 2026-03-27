module Backoffice
  class DashboardController < ApplicationController
    before_action :require_authentication

    def index; end
    def registry; render :index; end
    def treasury
      redirect_to "/backoffice/tesoreria"
    end
    def secretariat
      redirect_to "/backoffice/secretaria"
    end
    def works; render :index; end
    def administration; render :index; end
  end
end
