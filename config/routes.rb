Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root to: "public/home#index"
  get "/sobre-nosotros", to: "public/about#index"
  get "/contacto", to: "public/contact#index"
  get "/sobre-el-sistema", to: "public/system#index"
  get "/iniciar-sesion", to: "public/sessions#new"

  namespace :backoffice do
    root to: "dashboard#index"
    get "/cuadro-logial", to: "dashboard#registry"
    get "/tesoreria", to: "dashboard#treasury"
    get "/secretaria", to: "dashboard#secretariat"
    get "/trabajos", to: "dashboard#works"
    get "/administracion", to: "dashboard#administration"
  end
end
