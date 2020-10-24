require "sinatra"

set :environment, :production

get '/' do
  erb :ajax
end
