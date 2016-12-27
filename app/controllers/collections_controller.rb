class CollectionsController < ApplicationController

  before_filter :users_only, only: [:new, :edit, :create, :update]
  before_filter :load_collection_from_id, only: [:show, :edit, :update, :destroy, :confirm_delete]
  before_filter :collection_owners_only, only: [:edit, :update, :destroy, :confirm_delete]
  before_filter :check_user_status, only: [:new, :create, :edit, :update, :destroy]
  before_filter :validate_challenge_type
  cache_sweeper :collection_sweeper

  # Lazy fix to prevent passing unsafe values to eval via challenge_type
  # In both CollectionsController#create and CollectionsController#update there are a vulnerable usages of eval
  # For now just make sure the values passed to it are safe
  def validate_challenge_type
    if params[:challenge_type] and not ["", "GiftExchange", "PromptMeme"].include?(params[:challenge_type])
      return render status: :bad_request, text: "invalid challenge_type"
    end
  end

  def load_collection_from_id
    @collection = Collection.find_by_name(params[:id])
    unless @collection
        raise ActiveRecord::RecordNotFound, "Couldn't find collection named '#{params[:id]}'"
    end
  end

  def index
    if params[:work_id] && (@work = Work.find_by_id(params[:work_id]))
      @collections = @work.approved_collections.by_title.includes(:parent, :moderators, :children, :collection_preference, owners: [:user]).paginate(page: params[:page])
    elsif params[:collection_id] && (@collection = Collection.find_by_name(params[:collection_id]))
      @collections = @collection.children.by_title.includes(:parent, :moderators, :children, :collection_preference, owners: [:user]).paginate(page: params[:page])
    elsif params[:user_id] && (@user = User.find_by_login(params[:user_id]))
      @collections = @user.maintained_collections.by_title.includes(:parent, :moderators, :children, :collection_preference, owners: [:user]).paginate(page: params[:page])
      @page_subtitle = ts("created by ") + @user.login
    else
      if params[:user_id]
        flash.now[:error] = ts("We couldn't find a user by that name, sorry.")
      elsif params[:collection_id]
        flash.now[:error] = ts("We couldn't find a collection by that name.")
      elsif params[:work_id]
        flash.now[:error] = ts("We couldn't find that work.")
      end
      @sort_and_filter = true
      params[:collection_filters] ||= {}
      params[:sort_column] = "collections.created_at" if !valid_sort_column(params[:sort_column], 'collection')
      params[:sort_direction] = 'DESC' if !valid_sort_direction(params[:sort_direction])
      sort = params[:sort_column] + " " + params[:sort_direction]
      @collections = Collection.sorted_and_filtered(sort, params[:collection_filters], params[:page]).includes(:parent, :moderators, :children, :collection_preference, owners: [:user])
    end
  end

  # display challenges that are currently taking signups
  def list_challenges
    @page_subtitle = "Open Challenges"
    @hide_dashboard = true
    @challenge_collections = (Collection.signup_open("GiftExchange").limit(15) + Collection.signup_open("PromptMeme").limit(15))
  end

  def list_ge_challenges
    @page_subtitle = "Open Gift Exchange Challenges"
    @challenge_collections = Collection.signup_open("GiftExchange").limit(15)
  end

  def list_pm_challenges
    @page_subtitle = "Open Prompt Meme Challenges"
    @challenge_collections = Collection.signup_open("PromptMeme").limit(15)
  end

  def show
    @page_subtitle = @collection.title

    if @collection.collection_preference.show_random? || params[:show_random]
      # show a random selection of works/bookmarks
      @works = Work.in_collection(@collection).visible.random_order.limit(ArchiveConfig.NUMBER_OF_ITEMS_VISIBLE_IN_DASHBOARD).includes(:pseuds, :tags, :series, :language, :approved_collections)
      visible_bookmarks = @collection.approved_bookmarks.visible(order: 'RAND()').limit(ArchiveConfig.NUMBER_OF_ITEMS_VISIBLE_IN_DASHBOARD * 2)
    else
      # show recent
      @works = Work.in_collection(@collection).visible.ordered_by_date_desc.limit(ArchiveConfig.NUMBER_OF_ITEMS_VISIBLE_IN_DASHBOARD).includes(:pseuds, :tags, :series, :language, :approved_collections)
      # visible_bookmarks = @collection.approved_bookmarks.visible(order: 'bookmarks.created_at DESC')
      visible_bookmarks = Bookmark.in_collection(@collection).visible(order: 'bookmarks.created_at DESC').limit(ArchiveConfig.NUMBER_OF_ITEMS_VISIBLE_IN_DASHBOARD * 2)
    end
    # Having the number of items as a limit was finding the limited number of items, then visible ones within them
    @bookmarks = visible_bookmarks[0...ArchiveConfig.NUMBER_OF_ITEMS_VISIBLE_IN_DASHBOARD]

  end

  def new
    @hide_dashboard = true
    @collection = Collection.new
    if params[:collection_id] && (@collection_parent = Collection.find_by_name(params[:collection_id]))
      @collection.parent_name = @collection_parent.name
    end
  end

  def edit
  end

  def create
    @hide_dashboard = true
    @collection = Collection.new(collection_params)

    # add the owner
    owner_attributes = []
    (params[:owner_pseuds] || [current_user.default_pseud]).each do |pseud_id|
      pseud = Pseud.find(pseud_id)
      owner_attributes << {pseud: pseud, participant_role: CollectionParticipant::OWNER} if pseud
    end
    @collection.collection_participants.build(owner_attributes)

    if @collection.save
      flash[:notice] = ts('Collection was successfully created.')
      unless params[:challenge_type].blank?
        # This is a challenge collection
        # TODO: remove unsafe usage of eval, this is vulnerable and a security risk
        redirect_to eval("new_collection_#{params[:challenge_type].demodulize.tableize.singularize}_path(@collection)") and return
      else
        redirect_to(@collection)
      end
    else
      @challenge_type = params[:challenge_type]
      render action: "new"
    end
  end

  def update
    if @collection.update_attributes(collection_params)
      flash[:notice] = ts('Collection was successfully updated.')
      if params[:challenge_type].blank?
        if @collection.challenge
          # trying to destroy an existing challenge
          flash[:error] = ts("Note: if you want to delete an existing challenge, please do so on the challenge page.")
        end
      else
        if @collection.challenge
          if @collection.challenge.class.name != params[:challenge_type]
            flash[:error] = ts("Note: if you want to change the type of challenge, first please delete the existing challenge on the challenge page.")
          else
            # editing existing challenge
            # TODO: remove unsafe usage of eval, this is vulnerable and a security risk
            redirect_to eval("edit_collection_#{params[:challenge_type].demodulize.tableize.singularize}_path(@collection)") and return
          end
        else
          # adding a new challenge
          # TODO: remove unsafe usage of eval, this is vulnerable and a security risk
          redirect_to eval("new_collection_#{params[:challenge_type].demodulize.tableize.singularize}_path(@collection)") and return
        end
      end
      redirect_to(@collection)
    else
      render action: "edit"
    end
  end

  def confirm_delete
  end

  def destroy
    @hide_dashboard = true
    @collection = Collection.find_by_name(params[:id])
    begin
      @collection.destroy
      flash[:notice] = ts("Collection was successfully deleted.")
    rescue
      flash[:error] = ts("We couldn't delete that right now, sorry! Please try again later.")
    end
    redirect_to(collections_url)
  end

  private

  def collection_params
    params.require(:collection).permit(
      :name, :title, :email, :header_image_url, :description,
      :parent_name, :challenge_type, :icon, :icon_file_name,
      :icon_alt_text, :icon_comment_text,
      collection_profile_attributes: [
        :intro, :faq, :rules,
        :gift_notification, :assignment_notification
      ],
      collection_preference_attributes: [
        :closed, :unrevealed, :anonymous,
        :gift_exchange, :show_random, :prompt_meme, :email_notify
      ],
      collection_items_attributes: [
        :id, :collection_id, :item_id, :item_type, :user_approval_status,
        :collection_approval_status, :anonymous, :unrevealed, :_destroy
      ]
    )
  end

end
