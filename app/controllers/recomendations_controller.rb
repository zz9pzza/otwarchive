class RecomendationsController < ApplicationController
  layout false
  layout 'application', :except => :index

  before_filter :users_only, :load_user, :check_ownership, :except => [:show_works_recomendations]

  def load_user
    @user = User.find_by_login(params[:user_id])
    @check_ownership_of = @user
  end

  def index
    @liked = Hash.new(0) 
    @recs = Hash.new(0)
    bookmarks = @user.bookmark_ids
    kudos = Kudo.where(pseud_id: Pseud.where(user_id: @user.id).value_of(:id)).value_of(:commentable_id) 
    (kudos << bookmarks).each do |work| 
      @liked[work] +=1
    end
    @liked.keys.each do |work|
      work_rec = Work.find_recomended_works(work,@user.id)
    end
  end

end

