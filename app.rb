require 'dotenv'
Dotenv.load

require 'sinatra'
require 'httparty'

get '/' do
  'Hello world!'
end

post '/:flow' do
end
