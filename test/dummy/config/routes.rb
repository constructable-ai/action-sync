Rails.application.routes.draw do
  resource :session
  resources :passwords, param: :token
  mount ActionSync::Engine => "/action_sync"
end
