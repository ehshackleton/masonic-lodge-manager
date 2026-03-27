module Backoffice
  class DashboardController < ApplicationController
    def index; end
    def registry; render :index; end
    def treasury; render :index; end
    def secretariat; render :index; end
    def works; render :index; end
    def administration; render :index; end
  end
end
