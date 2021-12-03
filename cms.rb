require "sinatra"
require "sinatra/reloader"
require "tilt/erubis"
require "redcarpet"
require "yaml"
require "bcrypt"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

root = File.expand_path("..", __FILE__)
users = YAML.load_file('users.yml')

def render_markdown(content)
  markdown = Redcarpet::Markdown.new(Redcarpet::Render::HTML)
  markdown.render(content)
end

def load_file_content(path)
  content = File.read(path)
  case File.extname(path)
  when ".txt"
    headers["Content-Type"] = "text/plain"
    content
  when ".md"
    erb render_markdown(content)
  end
end

def data_path
  if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/data", __FILE__)
  else
    File.expand_path("../data", __FILE__)
  end
end

def user_signed_in?
  credentials = load_user_credentials
  credentials.key?(session[:username])
end

def require_signed_in_user
  unless user_signed_in?
    session[:message] = "You must be signed in to do that."
    redirect "/"
  end
end

def load_user_credentials
  credentials_path = if ENV["RACK_ENV"] == "test"
    File.expand_path("../test/users.yml", __FILE__)
  else
    File.expand_path("../users.yml", __FILE__)
  end
  YAML.load_file(credentials_path)
end

def valid_credentials?(username, password)
  credentials = load_user_credentials

  if credentials.key?(username)
    bcrypt_password = BCrypt::Password.new(credentials[username])
    bcrypt_password == password
  else
    false
  end
end

get "/" do
  pattern = File.join(data_path, "*")
  @file_names = Dir.glob(pattern).map do |path|
    File.basename(path)
  end
  erb :index
end

get "/new" do
  require_signed_in_user

  erb :new
end

post "/create" do
  require_signed_in_user

  file_name = params[:file_name].strip

  if file_name.size == 0
    session[:message] = "A name is required."
    status 422
    erb :new
  elsif ![".txt", ".md"].include?(File.extname(file_name))
    session[:message] = "The file must be a .txt or .md file."
    status 422
    erb :new
  else
    file_path = File.join(data_path, file_name)

    File.write(file_path, "")
    session[:message] = "#{file_name} has been created."
    redirect "/"
  end
end

get "/users/signin" do
  erb :signin
end

post "/users/signin" do
  credentials = load_user_credentials
  username = params[:username]

  if valid_credentials?(username, params[:password])
    session[:username] = username
    session[:message] = "Welcome!"
    redirect "/"
  else
    session[:message] = "Invalid credentials."
    status 422
    erb :signin
  end
end

post "/users/signout" do
  session.delete(:username)
  session[:message] = "You have been signed out."
  redirect "/"
end

post "/:file_name/delete" do
  require_signed_in_user

  file_path = File.join(data_path, params[:file_name])

  File.delete(file_path)

  session[:message] = "#{params[:file_name]} has been deleted."
  redirect "/"
end

get "/:file_name" do
  file_path = File.join(data_path, params[:file_name])

  if File.exist?(file_path)
    load_file_content(file_path)
  else
    session[:message] = "#{params[:file_name]} does not exist."
    redirect "/"
  end
end

get "/:file_name/edit" do
  require_signed_in_user

  file_path = File.join(data_path, params[:file_name])

  @content = File.read(file_path)
  erb :edit
end

post "/:file_name" do
  require_signed_in_user

  file_path = File.join(data_path, params[:file_name])

  File.write(file_path, params[:content])

  session[:message] = "#{params[:file_name]} has been updated."
  redirect "/"
end