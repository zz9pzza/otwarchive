class CommentMailer < ActionMailer::Base
  include Resque::Mailer # see README in this directory

  layout 'mailer'
  helper :mailer
  default :from => "Archive of Our Own " + "<#{ArchiveConfig.RETURN_ADDRESS}>"

  def prefered_locale_for_email(email)
    user=User.find_by_email(email)
    if user.nil? then
      return I18n.default_locale
    end
    return Locale.find(user.preference.prefered_locale).iso
  end

  # Sends email to an owner of the top-level commentable when a new comment is created
  def comment_notification(user_id, comment_id)
    user = User.find(user_id)
    @comment = Comment.find(comment_id)
    I18n.with_locale(Locale.find(user.preference.prefered_locale).iso) do
      tag = (@comment.ultimate_parent.is_a?(Tag) ? "#{t 'comment_mailer.the_tag'}" : "" )
      mail(
        :to => user.email,
        :subject => "#{t 'comment_comment_mailer.comment_notification.subject', app_name: ArchiveConfig.APP_SHORT_NAME, the_tag: tag, commentable:  @comment.ultimate_parent.commentable_name.gsub('&gt;', '>').gsub('&lt;', '<') }"
      )
    end
    ensure
     I18n.locale = I18n.default_locale
  end

  # Sends email to an owner of the top-level commentable when a comment is edited
  def edited_comment_notification(user_id, comment_id)
    user = User.find(user_id)
    @comment = Comment.find(comment_id)
    I18n.with_locale(Locale.find(user.preference.prefered_locale).iso) do
      tag = (@comment.ultimate_parent.is_a?(Tag) ? "#{t 'comment_mailer.the_tag'}" : "" )
      mail(
        :to => user.email,
        :subject => "#{t 'comment_mailer.edited_comment_notification.subject', app_name: ArchiveConfig.APP_SHORT_NAME, the_tag: tag, commentable:  @comment.ultimate_parent.commentable_name.gsub('&gt;', '>').gsub('&lt;', '<') }"
      )
    end
    ensure
     I18n.locale = I18n.default_locale
  end

  # Sends email to commenter when a reply is posted to their comment
  # This may be a non-user of the archive
  def comment_reply_notification(your_comment_id, comment_id)
    @your_comment = Comment.find(your_comment_id)
    @comment = Comment.find(comment_id)
    I18n.with_locale(prefered_locale_for_email(@your_comment.comment_owner_email)) do
      tag = (@comment.ultimate_parent.is_a?(Tag) ? "#{t 'comment_mailer.the_tag'}" : "" )
      mail(
        :to => @your_comment.comment_owner_email,
        :subject => "#{t 'comment_mailer.comment_reply.subject', app_name: ArchiveConfig.APP_SHORT_NAME, the_tag: tag, commentable:  @comment.ultimate_parent.commentable_name.gsub('&gt;', '>').gsub('&lt;', '<') }"
      )
    end
    ensure
     I18n.locale = I18n.default_locale
  end

  # Sends email to commenter when a reply to their comment is edited
  # This may be a non-user of the archive
  def edited_comment_reply_notification(your_comment_id, edited_comment_id)
    @your_comment = Comment.find(your_comment_id)
    @comment = Comment.find(edited_comment_id)
    I18n.with_locale(prefered_locale_for_email(@your_comment.comment_owner_email)) do
      tag = (@comment.ultimate_parent.is_a?(Tag) ? "#{t 'comment_mailer.the_tag'}" : "" )
      mail(
        :to => @your_comment.comment_owner_email,
        :subject => "#{t 'comment_mailer.edited_reply.subject', app_name: ArchiveConfig.APP_SHORT_NAME, the_tag: tag, commentable:  @comment.ultimate_parent.commentable_name.gsub('&gt;', '>').gsub('&lt;', '<') }"
      )
    end
    ensure
     I18n.locale = I18n.default_locale
  end

  # Sends email to the poster of a comment
  def comment_sent_notification(comment_id)
    @comment = Comment.find(comment_id)
    @noreply = true # don't give reply link to your own comment
    I18n.with_locale(prefered_locale_for_email(@comment.comment_owner_email)) do
      tag = (@comment.ultimate_parent.is_a?(Tag) ? "#{t 'comment_mailer.the_tag'}" : "" )
      mail(
        :to => @comment.comment_owner_email,
        :subject => "#{t 'comment_mailer.comment_sent.subject', app_name: ArchiveConfig.APP_SHORT_NAME, the_tag: tag, commentable:  @comment.ultimate_parent.commentable_name.gsub('&gt;', '>').gsub('&lt;', '<') }"
      )
    end
    ensure
     I18n.locale = I18n.default_locale
  end

end
