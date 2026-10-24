# Deactivation of users.
#
# Deactivating ends the access of users and keeps their data. Reactivating
# gives the access back.
class Admin::DeactivationsController < Admin::BaseController
  before_action :set_user

  def create
    if @user == Current.user
      redirect_to admin_users_path, alert: t(".self")
    elsif @user.deactivate
      redirect_to admin_users_path, notice: t(".deactivated", email: @user.email_address)
    else
      redirect_to admin_users_path, alert: @user.errors.full_messages.to_sentence
    end
  end

  def destroy
    if @user.active?
      redirect_to admin_users_path, alert: t(".not_deactivated")
    else
      @user.reactivate
      redirect_to admin_users_path, notice: t(".reactivated", email: @user.email_address)
    end
  end

  private

  def set_user
    @user = User.find(params[:user_id])
  end
end
