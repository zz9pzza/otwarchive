class TagsController < ApplicationController
  before_filter :load_collection
  before_filter :check_user_status, except: [:show, :index, :show_hidden, :search, :feed]
  before_filter :check_permission_to_wrangle, except: [:show, :index, :show_hidden, :search, :feed]
  before_filter :load_tag, only: [:edit, :update, :wrangle, :mass_update]
  before_filter :load_tag_and_subtags, only: [:show]

  cache_sweeper :tag_sweeper

  def load_tag
    @tag = Tag.find_by_name(params[:id])
    unless @tag && @tag.is_a?(Tag)
      raise ActiveRecord::RecordNotFound, "Couldn't find tag named '#{params[:id]}'"
    end
  end

  # improved performance for show page
  def load_tag_and_subtags
    @tag = Tag.includes(:direct_sub_tags).find_by_name(params[:id])
    unless @tag && @tag.is_a?(Tag)
      raise ActiveRecord::RecordNotFound, "Couldn't find tag named '#{params[:id]}'"
    end
  end

  def reindex
    work_ids = []
    unless logged_in_as_admin?
      flash[:error] = ts('Please log in as admin')
      redirect_to(request.env['HTTP_REFERER'] || root_path) && return
    end
    @tag = Tag.find_by_name(params[:id])
    work_ids = @tag.work_ids
    @tag.synonyms.each do |syn|
      work_ids.push syn.work_ids
    end
    work_ids.flatten!
    @tag.reindex_all_works(work_ids)
    flash[:notice] = ts('Tag sent to be reindexed')
    redirect_to(request.env['HTTP_REFERER'] || root_path) && return
  end

  # GET /tags
  def index
    if @collection
      @tags = Freeform.canonical.for_collections_with_count([@collection] + @collection.children)
    else
      no_fandom = Fandom.find_by_name(ArchiveConfig.FANDOM_NO_TAG_NAME)
      @tags = no_fandom.children.by_type('Freeform').first_class.limit(ArchiveConfig.TAGS_IN_CLOUD)
      # have to put canonical at the end so that it doesn't overwrite sort order for random and popular
      # and then sort again at the very end to make it alphabetic
      @tags = if params[:show] == 'random'
                @tags.random.canonical.sort
              else
                @tags.popular.canonical.sort
              end
    end
  end

  def search
    @page_subtitle = ts('Search Tags')
    if params[:query].present?
      options = params[:query].dup
      @query = options
      if @query[:name].present?
        @page_subtitle = ts("Tags Matching '%{query}'", query: @query[:name])
      end
      options[:page] = params[:page] || 1
      @tags = TagSearch.search(options)
    end
  end

  # if user is Admin or Tag Wrangler, show them details about the tag
  # if user is not logged in or a regular user, show them
  #   1. the works, if the tag had been wrangled and we can redirect them to works using it or its canonical merger
  #   2. the tag, the works and the bookmarks using it, if the tag is unwrangled (because we can't redirect them
  #       to the works controller)
  def show
    @page_subtitle = @tag.name
    if @tag.is_a?(Banned) && !logged_in_as_admin?
      flash[:error] = ts('Please log in as admin')
      redirect_to(tag_wranglings_path) && return
    end
    # if tag is NOT wrangled, prepare to show works and bookmarks that are using it
    if !@tag.canonical && !@tag.merger
      if logged_in? # current_user.is_a?User
        @works = @tag.works.visible_to_registered_user.paginate(page: params[:page])
      elsif logged_in_as_admin?
        @works = @tag.works.visible_to_owner.paginate(page: params[:page])
      else
        @works = @tag.works.visible_to_all.paginate(page: params[:page])
      end
      @bookmarks = @tag.bookmarks.visible.paginate(page: params[:page])
    end
    # cache the children, since it's a possibly massive query
    @tag_children = Rails.cache.fetch "views/tags/#{@tag.cache_key}/children" do
      children = {}
      (@tag.child_types - %w(SubTag)).each do |child_type|
        tags = @tag.send(child_type.underscore.pluralize).order('taggings_count_cache DESC').limit(ArchiveConfig.TAG_LIST_LIMIT + 1)
        children[child_type] = tags.to_a.uniq unless tags.blank?
      end
      children
    end
  end

  def feed
    # Construct a hash that can be cached. The hash contains
    # path: where to redirect to
    # work: The list of works
    # tag: the tag the feed is for
    hash = Rails.cache.fetch(Tag.tag_feeds_key(params[:id])) do
      path = nil
      works = nil 
      begin
        tag = Tag.find(params[:id])
      rescue ActiveRecord::RecordNotFound
        raise ActiveRecord::RecordNotFound, "Couldn't find tag with id '#{params[:id]}'"
      end
      tag = tag.merger if !tag.canonical? && tag.merger
      # F/F is currently a special case...
      if %w(Fandom Character Relationship).include?(tag.type.to_s) || tag.name == "F/F"
          works = tag.canonical? ? \
                    tag.filtered_works.visible_to_all.order("created_at DESC").limit(ArchiveConfig.FEED_ELEMENTS || 25).all : \
                    tag.works.visible_to_all.order("created_at DESC").limit(ArchiveConfig.FEED_ELEMENTS || 25).all
      else
        path = tag_works_path(tag_id: tag.to_param)
      end
      { path: path, works: works, tag: tag }
    end
    redirect = hash[:path]
    @works = hash[:works]
    @tag = hash[:tag]
    unless redirect.nil? 
      redirect_to redirect and return
    end

    respond_to do |format|
      format.html
      format.atom
    end
  end

  def show_hidden
    unless params[:creation_id].blank? || params[:creation_type].blank? || params[:tag_type].blank?
      raise "Redshirt: Attempted to constantize invalid class initialize show_hidden #{params[:creation_type].classify}" unless %w(Series Work Chapter).include?(params[:creation_type].classify)
      model = begin
                params[:creation_type].classify.constantize
              rescue
                nil
              end
      @display_creation = model.find(params[:creation_id]) if model.is_a? Class
      # Tags aren't directly on series, so we need to handle them differently
      if params[:creation_type] == 'Series'
        if params[:tag_type] == 'warnings'
          @display_tags = @display_creation.works.visible.collect(&:warning_tags).flatten.compact.uniq.sort
        else
          @display_tags = @display_creation.works.visible.collect(&:freeform_tags).flatten.compact.uniq.sort
        end
      else
        if %w(warnings freeforms).include?(params[:tag_type])
          @display_tags = @display_creation.send(params[:tag_type])
        end
      end
      @display_category = @display_tags.first.class.name.downcase.pluralize
    end
    respond_to do |format|
      format.html do
        # This is just a quick fix to avoid script barf if JavaScript is disabled
        flash[:error] = ts('Sorry, you need to have JavaScript enabled for this.')
        if request.env['HTTP_REFERER']
          redirect_to(request.env['HTTP_REFERER'] || root_path)
        else
          # else branch needed to deal with bots, which don't have a referer
          redirect_to '/'
        end
      end
      format.js
    end
  end

  # GET /tags/new
  def new
    @tag = Tag.new

    respond_to do |format|
      format.html # new.html.erb
    end
  end

  # POST /tags
  def create
    type = tag_params[:type] if params[:tag]
    if type
      raise "Redshirt: Attempted to constantize invalid class initialize create #{type.classify}" unless Tag::TYPES.include?(type.classify)
      model = begin
                type.classify.constantize
              rescue
                nil
              end
      @tag = model.find_or_create_by_name(tag_params[:name]) if model.is_a? Class
    else
      flash[:error] = ts('Please provide a category.')
      @tag = Tag.new(name: tag_params[:name])
      render(action: 'new') && return
    end
    if @tag && @tag.valid?
      if (@tag.name != tag_params[:name]) && @tag.name.casecmp(tag_params[:name].downcase).zero? # only capitalization different
        @tag.update_attribute(:name, tag_params[:name]) # use the new capitalization
        flash[:notice] = ts('Tag was successfully modified.')
      else
        flash[:notice] = ts('Tag was successfully created.')
      end
      @tag.update_attribute(:canonical, tag_params[:canonical])
      redirect_to url_for(controller: 'tags', action: 'edit', id: @tag)
    else
      render(action: 'new') && return
    end
  end

  def edit
    @page_subtitle = ts('%{tag_name} - Edit', tag_name: @tag.name)

    if @tag.is_a?(Banned) && !logged_in_as_admin?
      flash[:error] = ts('Please log in as admin')

      redirect_to(tag_wranglings_path) && return
    end

    @counts = {}
    @uses = ['Works', 'Drafts', 'Bookmarks', 'Private Bookmarks', 'External Works', 'Taggings Count']
    @counts['Works'] = @tag.visible_works_count
    @counts['Drafts'] = @tag.works.unposted.count
    @counts['Bookmarks'] = @tag.visible_bookmarks_count
    @counts['Private Bookmarks'] = @tag.bookmarks.not_public.count
    @counts['External Works'] = @tag.visible_external_works_count
    @counts['Taggings Count'] = @tag.taggings_count

    @parents = @tag.parents.find(:all, order: :name).group_by { |tag| tag[:type] }
    @parents['MetaTag'] = @tag.direct_meta_tags.by_name
    @children = @tag.children.find(:all, order: :name).group_by { |tag| tag[:type] }
    @children['SubTag'] = @tag.direct_sub_tags.by_name
    @children['Merger'] = @tag.mergers.by_name

    if @tag.respond_to?(:wranglers)
      @wranglers = @tag.canonical ? @tag.wranglers : (@tag.merger ? @tag.merger.wranglers : [])
    elsif @tag.respond_to?(:fandoms) && !@tag.fandoms.empty?
      @wranglers = @tag.fandoms.collect(&:wranglers).flatten.uniq
    end
    @suggested_fandoms = @tag.suggested_fandoms - @tag.fandoms if @tag.respond_to?(:fandoms)
  end

  def update
    # update everything except for the synonym,
    # so that the associations are there to move when the synonym is created
    syn_string = params[:tag].delete(:syn_string)
    new_tag_type = params[:tag].delete(:type)
    fix_taggings_count = params[:tag].delete(:fix_taggings_count)

    # Limiting the conditions under which you can update the tag type
    if @tag.can_change_type? && %w(Fandom Character Relationship Freeform UnsortedTag).include?(new_tag_type)
      @tag = @tag.recategorize(new_tag_type)
    end

    unless params[:tag].empty?
      @tag.attributes = tag_params
    end

    @tag.syn_string = syn_string if @tag.errors.empty? && @tag.save

    if @tag.errors.empty? && @tag.save
      # check if a resetting of the taggings_count was requsted
      if fix_taggings_count.present?
        @tag.taggings_count = @tag.taggings.count
        @tag.save
      end
      flash[:notice] = ts('Tag was updated.')

      if params[:commit] == 'Wrangle'
        params[:page] = '1' if params[:page].blank?
        params[:sort_column] = 'name' unless valid_sort_column(params[:sort_column], 'tag')
        params[:sort_direction] = 'ASC' unless valid_sort_direction(params[:sort_direction])

        redirect_to url_for(controller: :tags, action: :wrangle, id: params[:id], show: params[:show], page: params[:page], sort_column: params[:sort_column], sort_direction: params[:sort_direction], status: params[:status])
      else
        redirect_to url_for(controller: :tags, action: :edit, id: @tag)
      end
    else
      @parents = @tag.parents.find(:all, order: :name).group_by { |tag| tag[:type] }
      @parents['MetaTag'] = @tag.direct_meta_tags.by_name
      @children = @tag.children.find(:all, order: :name).group_by { |tag| tag[:type] }
      @children['SubTag'] = @tag.direct_sub_tags.by_name
      @children['Merger'] = @tag.mergers.by_name

      render :edit
    end
  end

  def wrangle
    @page_subtitle = ts('%{tag_name} - Wrangle', tag_name: @tag.name)
    @counts = {}
    @tag.child_types.map { |t| t.underscore.pluralize.to_sym }.each do |tag_type|
      @counts[tag_type] = @tag.send(tag_type).count
    end

    if %w(fandoms characters relationships freeforms sub_tags mergers).include?(params[:show])
      params[:sort_column] = 'name' unless valid_sort_column(params[:sort_column], 'tag')
      params[:sort_direction] = 'ASC' unless valid_sort_direction(params[:sort_direction])
      sort = params[:sort_column] + ' ' + params[:sort_direction]
      # add a secondary sorting key when the main one is not discerning enough
      if sort.include?('suggested') || sort.include?('taggings_count_cache')
        sort += ', name ASC'
      end
      # this makes sure params[:status] is safe
      if %w(unfilterable canonical synonymous unwrangleable).include?(params[:status])
        @tags = @tag.send(params[:show]).order(sort).send(params[:status]).paginate(page: params[:page], per_page: ArchiveConfig.ITEMS_PER_PAGE)
      elsif params[:status] == 'unwrangled'
        @tags = @tag.same_work_tags.unwrangled.by_type(params[:show].singularize.camelize).order(sort).paginate(page: params[:page], per_page: ArchiveConfig.ITEMS_PER_PAGE)
      else
        @tags = @tag.send(params[:show]).find(:all, order: sort).paginate(page: params[:page], per_page: ArchiveConfig.ITEMS_PER_PAGE)
      end
    end
  end

  def mass_update
    params[:page] = '1' if params[:page].blank?
    params[:sort_column] = 'name' unless valid_sort_column(params[:sort_column], 'tag')
    params[:sort_direction] = 'ASC' unless valid_sort_direction(params[:sort_direction])
    options = { show: params[:show], page: params[:page], sort_column: params[:sort_column], sort_direction: params[:sort_direction], status: params[:status] }

    error_messages = []
    notice_messages = []

    # make tags canonical if allowed
    if params[:canonicals].present? && params[:canonicals].is_a?(Array)
      saved_canonicals = []
      not_saved_canonicals = []
      tags = Tag.where(id: params[:canonicals])

      tags.each do |tag_to_canonicalize|
        if tag_to_canonicalize.update_attributes(canonical: true)
          saved_canonicals << tag_to_canonicalize
        else
          not_saved_canonicals << tag_to_canonicalize
        end
      end

      error_messages << ts('The following tags couldn\'t be made canonical: %{tags_not_saved}', tags_not_saved: not_saved_canonicals.collect(&:name).join(', ')) unless not_saved_canonicals.empty?
      notice_messages << ts('The following tags were successfully made canonical: %{tags_saved}', tags_saved: saved_canonicals.collect(&:name).join(', ')) unless saved_canonicals.empty?
    end

    # remove associated tags
    if params[:remove_associated].present? && params[:remove_associated].is_a?(Array)
      saved_removed_associateds = []
      not_saved_removed_associateds = []
      tags = Tag.where(id: params[:remove_associated])

      tags.each do |tag_to_remove|
        if @tag.remove_association(tag_to_remove.id)
          saved_removed_associateds << tag_to_remove
        else
          not_saved_removed_associateds << tag_to_remove
        end
      end

      error_messages << ts('The following tags couldn\'t be removed: %{tags_not_saved}', tags_not_saved: not_saved_removed_associateds.collect(&:name).join(', ')) unless not_saved_removed_associateds.empty?
      notice_messages << ts('The following tags were successfully removed: %{tags_saved}', tags_saved: saved_removed_associateds.collect(&:name).join(', ')) unless saved_removed_associateds.empty?
    end

    # wrangle to fandom(s)
    if params[:fandom_string].blank? && params[:selected_tags].is_a?(Array) && !params[:selected_tags].empty?
      error_messages << ts('There were no Fandom tags!')
    end
    if params[:fandom_string].present? && params[:selected_tags].is_a?(Array) && !params[:selected_tags].empty?
      canonical_fandoms = []
      noncanonical_fandom_names = []
      fandom_names = params[:fandom_string].split(',').map(&:squish)

      fandom_names.each do |fandom_name|
        if (fandom = Fandom.find_by_name(fandom_name)).try(:canonical?)
          canonical_fandoms << fandom
        else
          noncanonical_fandom_names << fandom_name
        end
      end

      if canonical_fandoms.present?
        saved_to_fandoms = Tag.where(id: params[:selected_tags])

        saved_to_fandoms.each do |tag_to_wrangle|
          canonical_fandoms.each do |fandom|
            tag_to_wrangle.add_association(fandom)
          end
        end

        canonical_fandom_names = canonical_fandoms.collect(&:name)
        options[:fandom_string] = canonical_fandom_names.join(',')
        notice_messages << ts('The following tags were successfully wrangled to %{canonical_fandoms}: %{tags_saved}', canonical_fandoms: canonical_fandom_names.join(', '), tags_saved: saved_to_fandoms.collect(&:name).join(', ')) unless saved_to_fandoms.empty?
      end

      if noncanonical_fandom_names.present?
        error_messages << ts('The following names are not canonical fandoms: %{noncanonical_fandom_names}.', noncanonical_fandom_names: noncanonical_fandom_names.join(', '))
      end
    end

    flash[:notice] = notice_messages.join('<br />').html_safe unless notice_messages.empty?
    flash[:error] = error_messages.join('<br />').html_safe unless error_messages.empty?

    redirect_to url_for({ controller: :tags, action: :wrangle, id: params[:id] }.merge(options))
  end

  private

  def tag_params
    params.require(:tag).permit(
      :name, :fix_taggings_count, :type, :canonical, :unwrangleable, :adult,
      :fandom_string, :meta_tag_string, :syn_string, :sortable_name, :media_string,
      :character_string, :relationship_string, :freeform_string, :sub_tag_string,
      :merger_string,
      associations_to_remove: []
    )
  end
end
