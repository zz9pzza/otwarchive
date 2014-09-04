class KudoMailer < ActionMailer::Base
  include Resque::Mailer # see README in this directory

  layout 'mailer'
  helper :mailer
  default :from => "Archive of Our Own " + "<#{ArchiveConfig.RETURN_ADDRESS}>"

  def kudo_notification(user_id, kudo_id)
    begin
      user = User.find(user_id)
      kudo = Kudo.find(kudo_id)
      @pseud = kudo.pseud
      @commentable = kudo.commentable
    rescue ActiveRecord::RecordNotFound
      return
    end
    mail(
      :to => user.email,
      :subject => "[#{ArchiveConfig.APP_SHORT_NAME}] Kudos on " + @commentable.commentable_name.gsub("&gt;", ">").gsub("&lt;", "<")
    )
  end
  
  # send a batched-up notification 
  # user_kudos is a hash of arrays converted to JSON string format
  # [commentable_type]_[commentable_id] => [array of users who left kudos with the last entry being "# guests" if any]
  def batch_kudo_notification(user_id, user_kudos)
    begin
      @commentables = []
      @kudo_givers = {}
      user = User.find(user_id)
      kudos_hash = JSON.parse(user_kudos)
      kudos_hash.each_pair do |commentable_info, kudo_givers|
        commentable_type, commentable_id = commentable_info.split("_")
        commentable = commentable_type.constantize.find_by_id(commentable_id)
        next unless commentable
        @commentables << commentable
        @kudo_givers[commentable_info] = kudo_givers
      end
    rescue ActiveRecord::RecordNotFound
      return
    end
    mail(
      :to => user.email,
      :subject => "[#{ArchiveConfig.APP_SHORT_NAME}] You've got kudos!"
    )
  end

end
