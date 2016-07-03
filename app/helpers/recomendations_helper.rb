module RecomendationsHelper

  def show_hide_recomendations_link(work, options={})
    options[:link_type] ||= "show"
    options[:show_count] ||= false

    link_action = options[:link_type] == "hide" || params[:show_recomendations] ?
                    :hide_works_recomendations :
                    :show_works_recomendations
    
    link_text = ( options[:link_type] == "hide" || params[:show_recomendations] ?
                        ts("Hide Recomendations") :
                        ts("Recomendations"))
    
    link_to(
        link_text,
        url_for(:controller => :recomendations,
                :action => link_action,
                :work  => work.id,
                :view_full_work => params[:view_full_work]),
                :remote => true)
  end

end
