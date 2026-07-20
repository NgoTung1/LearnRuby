Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root 'weather#index'
  get 'register', to: 'registrations#new'
  post 'register', to: 'registrations#create'

  get 'login', to: 'sessions#new'
  post 'login', to: 'sessions#save'
  delete 'login', to: 'sessions#destroy'
end
