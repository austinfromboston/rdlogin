class UsersController < ApplicationController
  make_resourceful do
    actions :all
  end
  def show
    redirect_to users_path
  end
end
