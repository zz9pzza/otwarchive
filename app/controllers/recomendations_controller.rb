class RecomendationsController < ApplicationController
  layout false

  before_filter :users_only
  before_filter :load_user
  #before_filter :check_ownership

  def load_user
    @user = User.find_by_login(params[:user_id])
    @check_ownership_of = @user
  end

  def index
  end

end

