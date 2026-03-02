require "sidekiq/web"

Rails.application.routes.draw do
  devise_for :users, controllers: {
    registrations: "users/registrations",
    omniauth_callbacks: "users/omniauth_callbacks"
  }

  # Mount Sidekiq web interface (protected by authentication)
  authenticate :user do
    mount Sidekiq::Web => "/sidekiq"
  end

  # Admin panel
  namespace :admin do
    root to: "dashboard#index"
    post "send_bulk_email", to: "dashboard#send_bulk_email", as: :send_bulk_email
    resources :users, only: [ :index, :show ] do
      member do
        patch :toggle_admin
        patch :toggle_disable
        post :gift_credits
      end
    end
    resources :conversations, only: [ :index, :show ] do
      member do
        post :reply
        patch :close
        patch :reopen
      end
    end
  end

  # Main AI features - protected by authentication
  authenticate :user do
    get "dashboard", to: "dashboard#index", as: :dashboard

    resource :settings, only: [ :show, :update ] do
      delete :destroy_account, on: :member
    end

    resource :referrals, only: [ :show ]

    resource :onboarding, only: [ :show, :update ], controller: "onboarding" do
      post :skip, on: :member
    end

    resources :resume_wizard, only: [:new, :create] do
      member do
        get :preview
        post :unlock
      end
    end

    resources :resumes do
      member do
        post :optimize
        post :ats_score
        get :keywords
        get :download
      end

      resource :builder, controller: "resume_builder", only: [ :edit, :update ] do
        get :preview
        post :add_section
        delete :remove_section
        patch :reorder
        get :download_pdf
      end

      resources :cover_letters, except: [ :index ] do
        member do
          post :generate_variations
          get :preview
          get :download
        end
      end
    end

    resources :cover_letters, only: [ :index ]

    resources :job_applications do
      member do
        patch :move
      end
    end

    resources :interview_preps, only: [ :index, :new, :create, :show, :destroy ]
    resources :linkedin_optimizations, only: [ :index, :new, :create, :show, :destroy ]

    resources :chat, only: [ :index, :show, :create ] do
      member do
        post :send_message
      end
    end

    resources :scraped_jobs, only: [ :index, :show, :update, :destroy ] do
      collection do
        post :scrape_now
        get :settings
        patch :update_settings
      end
    end

    # Billing and subscriptions
    resources :subscriptions, only: [ :new, :create, :show, :update, :destroy ] do
      member do
        post :cancel
        post :reactivate
      end
      collection do
        get :verify_subscription
      end
    end

    resources :billing, only: [ :index, :show ] do
      collection do
        get :history
        post :purchase_credits
        get :verify_payment
      end
    end
  end

  # Paystack webhooks (outside authentication)
  post "/webhooks/paystack", to: "webhooks#paystack"

  # API routes
  namespace :api do
    get "detect-country", to: "country_detection#detect"
    post "fetch-job-posting", to: "job_posting#fetch"
  end

  # Define your application routes per the DSL in https://guides.rubyonrails.org/routing.html

  # Reveal health status on /up that returns 200 if the app boots with no exceptions, otherwise 500.
  # Can be used by load balancers and uptime monitors to verify that the app is live.
  get "up" => "rails/health#show", as: :rails_health_check

  # Render dynamic PWA files from app/views/pwa/*
  get "service-worker" => "rails/pwa#service_worker", as: :pwa_service_worker
  get "manifest" => "rails/pwa#manifest", as: :pwa_manifest

  # Blog (public)
  resources :articles, only: [ :index, :show ], path: "blog"

  # Static pages
  get "terms", to: "pages#terms", as: :terms
  get "privacy", to: "pages#privacy", as: :privacy
  get "unsubscribe", to: "email_unsubscribes#show", as: :unsubscribe

  # Defines the root path route ("/")
  root "home#index"
end
