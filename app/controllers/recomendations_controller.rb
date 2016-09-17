class RecomendationsController < ApplicationController
  layout false
  layout 'application', :except => :index

  before_filter :users_only, :load_user, :check_ownership, :except => [:show_works_recomendations,:index]

  def load_user
    @user = User.find_by_login(params[:user_id])
    @check_ownership_of = @user
  end

  def index
   @favorite_tag = current_user.favorite_tags.collect { |t| t.tag_id }.include? Tag.find_by_name(params[:tag_id]).id
  end

  def index2
    @liked = Hash.new(0) 
    @recs = Hash.new(0)
    @favorite_tag = current_user.favorite_tags
    kudos = Kudo.where(pseud_id: Pseud.where(user_id: @user.id).value_of(:id)).value_of(:commentable_id) 
    (kudos << bookmarks).each do |work| 
      @liked[work] +=1
    end
    @liked.keys.each do |work|
      work_rec = Work.find_recomended_works(work,@user.id)
    end
  end

end

