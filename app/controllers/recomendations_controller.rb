class RecomendationsController < ApplicationController
  layout false
  layout 'application', :except => :index

  before_filter :users_only, :load_user, :check_ownership, :except => [:show_works_recomendations]

  def load_user
    @user = User.find_by_login(params[:user_id])
    @check_ownership_of = @user
  end

  def index
  end

end

