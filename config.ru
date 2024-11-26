require './app'

Sinatra::Application.set :bind, '0.0.0.0'
Sinatra::Application.set :port, ENV['PORT'] || 3000
run Sinatra::Application
