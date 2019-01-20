require "sinatra"
require "sinatra/reloader" if development?
require "sinatra/content_for"
require "tilt/erubis"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

helpers do
  def all_complete?(list)
    !list[:todos].empty? && list[:todos].all? { |todo| todo[:completed] }
  end
  
  def list_class(list)
    return "complete" if all_complete?(list)
  end
  
  def todo_count(list)
    remaining = list[:todos].count { |todo| !todo[:completed] }
    total = list[:todos].count
    "#{remaining}/#{total}"
  end
  
  def percent_remaining(list)
    return 1 if list[:todos].empty?
    remaining, total = todo_count(list).split(/\//).map(&:to_i)
    remaining / total.to_f
  end
  
  def list_index_lookup(list_name)
    session[:lists].index { |list| list[:name] == list_name }
  end
  
  def todo_index_lookup(list, item_name)
    list[:todos].index { |item| item[:name] == item_name }
  end
end

before do
  session[:lists] ||= []
end

get "/" do
  redirect "/lists"
end

# View all of the lists
get "/lists" do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Render new list form
get "/lists/new" do
  erb :new_list, layout: :layout
end

def error_for_list_name(name) #return an error message if name is invalid. Return nil if valid.
  if !(1..100).cover? name.size
    session[:error] = "The list name must be between 1 and 100 characters."
  elsif session[:lists].any? { |list| list[:name] == name }
    session[:error] = "List name must be unique"
  end
end

def error_for_list_item(list_number, item) #return an error message if item is invalid. Return nil if valid.
  if !(1..100).cover? item.size
    session[:error] = "The list item must be between 1 and 100 characters."
  elsif session[:lists][list_number][:todos].any? { |todo| todo[:name] == item }
    session[:error] = "List item must be unique"
  end
end

# Create a new list
post "/lists" do
  list_name = params[:list_name].strip
  error = error_for_list_name(list_name)
  
  if error 
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << {name: list_name, todos: []}
    session[:success] = "The list has been created"
    redirect "/lists"
  end
end

get "/lists/:number" do
  @list_number = params[:number].to_i
  @todo_list = session[:lists][@list_number]
  
  erb :todos, layout: :layout
end

get "/edit_list/:number" do
  @list_number = params[:number].to_i
  @todo_list = session[:lists][@list_number]
  
  erb :edit_list, layout: :layout
end

post "/edit_list/:number" do
  @list_number = params[:number].to_i
  @todo_list = session[:lists][@list_number]
  
  new_name = params[:new_name].strip
  error = error_for_list_name(new_name)
  
  if error 
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @todo_list[:name] = new_name
    session[:success] = "The list has been created"
    redirect "/lists/#{params[:number]}"
  end
end

post "/lists/delete" do
  list_number = params[:list_number].to_i
  session[:lists].delete_at(list_number)
  session[:success] = "List has been deleted."
  
  redirect "/lists"
end

post "/lists/:number/list_item" do
  list_number = params[:number].to_i
  todo_list = session[:lists][list_number]
  list_item = params[:list_item].strip
  
  error = error_for_list_item(list_number, list_item)
  
  if error
    session[:error] = error
  else
    todo_list[:todos] << {name: list_item, completed: false}
    session[:success] = "The list item was added."
  end
  redirect "/lists/#{list_number}"
end

post "/lists/:list_number/list_item/:item_number/delete" do
  list_number = params[:list_number].to_i
  item_number = params[:item_number].to_i
  
  session[:lists][list_number][:todos].delete_at(item_number)
  session[:success] = "List item has been deleted."
  
  redirect "/lists/#{list_number}"
end

post "/lists/:list_number/list_item/:item_number/complete" do
  list_number = params[:list_number].to_i
  item_number = params[:item_number].to_i
  
  is_completed = params[:completed] == "true"
  
  session[:lists][list_number][:todos][item_number][:completed] = is_completed
  session[:success] = "Item has been updated!"
  
  redirect "/lists/#{list_number}"
end

post "/lists/:list_number/complete_all" do
  list_number = params[:list_number].to_i
  session[:lists][list_number][:todos].each do |todo|
    todo[:completed] = true
  end
  
  redirect "/lists/#{list_number}"
end