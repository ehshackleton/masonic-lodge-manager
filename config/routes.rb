Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root to: "public/home#index"
  get "/sobre-nosotros", to: "public/about#index"
  get "/contacto", to: "public/contact#index"
  get "/sobre-el-sistema", to: "public/system#index"
  get "/iniciar-sesion", to: "public/sessions#new"
  post "/iniciar-sesion", to: "public/sessions#create"
  delete "/cerrar-sesion", to: "public/sessions#destroy"

  namespace :backoffice do
    root to: "dashboard#index"
    get "/cuadro-logial", to: redirect("/backoffice/brothers")
    get "/tesoreria", to: "treasury#index"
    post "/tesoreria/settings", to: "treasury#update_settings"
    post "/tesoreria/generate-charges", to: "treasury#generate_charges"
    post "/tesoreria/payments", to: "treasury#create_payment"
    post "/tesoreria/closures", to: "treasury#create_closure"
    delete "/tesoreria/closures/:id", to: "treasury#destroy_closure"
    get "/tesoreria/export/excel", to: "treasury#export_excel"
    get "/tesoreria/export/pdf", to: "treasury#export_pdf"
    get "/tesoreria/export/morosidad/excel", to: "treasury#export_delinquency_excel"
    get "/tesoreria/export/morosidad/pdf", to: "treasury#export_delinquency_pdf"
    get "/secretaria", to: "secretariat#index"
    get "/trabajos", to: redirect("/backoffice/masonic_works")
    get "/administracion", to: "administration#index"
    patch "/administracion/usuarios/:id/roles", to: "administration#update_user_roles", as: :administration_user_roles
    patch "/administracion/usuarios/:id/roles-plantilla", to: "administration#apply_role_template", as: :administration_user_role_template
    resources :brothers do
      member do
        delete "documents/:attachment_id", to: "brothers#purge_document", as: :purge_document
      end

      resources :brother_degree_histories, only: %i[create destroy]
      resources :brother_office_assignments, only: %i[create destroy]
    end
    resources :minutes do
      collection do
        get :export_excel
        get :export_pdf
      end
      member do
        patch :submit_review
        patch :approve
        patch :publish
      end
    end

    resources :correspondences do
      collection do
        get :export_excel
        get :export_pdf
      end
      member do
        patch :submit_review
        patch :approve
        patch :publish
      end
    end

    resources :masonic_works do
      collection do
        get :export_excel
        get :export_pdf
        get :export_reviews_excel
        get :export_reviews_pdf
        get :export_dashboard_pdf
      end
      member do
        patch :submit_review
        patch :approve
        patch :mark_presented
        patch :archive
      end
      resources :work_reviews, only: %i[create destroy]
    end
  end
end
