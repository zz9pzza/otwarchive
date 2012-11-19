class PreferencesController < ApplicationController
  before_filter :load_user
  before_filter :check_ownership
  skip_before_filter :store_location

  
  # Ensure that the current user is authorized to view and change this information
  def load_user
    @user = User.find_by_login(params[:user_id])
    @check_ownership_of = @user
  end
  
  def index
    @user = User.find_by_login(params[:user_id])
    @preference = @user.preference || Preference.create(:user_id => @user.id)
    @available_skins = (current_user.skins.site_skins + Skin.approved_skins.site_skins).uniq
  end

  def update
    @user = User.find_by_login(params[:user_id])
    @preference = @user.preference
    @available_skins = (current_user.skins.site_skins + Skin.approved_skins.site_skins).uniq
    flash_message = ""

    if params[:preference][:skin_id].present?
      # unset session skin if user changed their skin
      session[:site_skin] = nil
    end

    # Has the device email address changed if so set the email address to unconfirmed and 
    # Send out an confirmation email
    if params[:preference][:download_email_address] != @user.preference.download_email_address
       params[:resend_device_confirmation_email]=1
       flash_message = flash_message + ts("Device e-mail address changed. ")
    end

    if params[:resend_device_confirmation_email].present?
       flash_message = flash_message + ts(" Sending new confirmation email. ")
    else
       if params[:confirmationcode].present?
          if params[:confirmationcode] == @user.preference.download_activation_key
            @user.preference.download_activated = 1
            flash_message = flash_message + ts("Email address confirmed. ")
          else
            @user.preference.download_activated = 0
            flash_message = flash_message + ts("Confirmation code incorrect. ")
          end
       end
    end
 	

    # Don't save away things that do not exist.
    params[:preference].delete :download_activated

    #Store things awaya and save it
    @user.preference.attributes = params[:preference]
    if @user.preference.save
      setflash; flash[:notice] = flash_message+ ts('Your preferences were successfully updated.')
      redirect_back_or_default(user_preferences_path(@user))
    else
      setflash; flash[:error] = flash_message+ts('Sorry, something went wrong. Please try that again.')
      render :action => :index
    end
  end
end
