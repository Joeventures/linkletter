Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token

  resources :groups do
    resources :members, only: %i[ create edit update destroy ] do
      post :import, on: :collection
    end
    resource :email_template, only: %i[ show edit update destroy ]
    resources :links, only: %i[ new create show destroy ] do
      post :deliver, on: :member
    end
  end

  # Public, per-person tracked redirect. Kept short because it appears in emails.
  get "l/:token" => "redirects#show", as: :personal_redirect

  get "up" => "rails/health#show", as: :rails_health_check

  root "groups#index"
end
