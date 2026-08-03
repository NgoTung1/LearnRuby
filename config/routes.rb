Rails.application.routes.draw do
  # For details on the DSL available within this file, see https://guides.rubyonrails.org/routing.html
  root 'weathers#index'
  get 'register', to: 'registrations#new'
  post 'register', to: 'registrations#create'
  get 'register/otp', to: 'otps#new', as: 'otp'
  post 'register/otp', to: 'otps#create', as: 'create_otp'
  post 'register/otp/resend', to: 'otps#resend', as: 'resend_otp'

  get 'login', to: 'sessions#new' 
  post 'login', to: 'sessions#save'
  delete 'login', to: 'sessions#destroy'
  get '/auth/:provider/callback', to: 'sessions#google_login'
  get '/auth/failure', to: redirect('/login')

  get 'favorite', to: 'favourites#new'


  get 'hisoty', to: 'histories#new'

end
