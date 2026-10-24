class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: %i[edit update destroy]
  before_action :require_hard_delete, only: :destroy

  def index
    @users = User.order(:email_address)
  end

  def new
    @user = User.new
  end

  def create
    @user = User.new(user_params)
    if @user.save
      redirect_to admin_users_path, notice: t(".created")
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @user.update(user_params)
      end_other_sessions(@user) if @user.saved_change_to_password_digest?
      redirect_to admin_users_path, notice: t(".updated")
    else
      render :edit, status: :unprocessable_content
    end
  end

  # Deletes the user for good.
  #
  # Everything the database cascades goes with the user. The option must be on
  # and the user deactivated first.
  def destroy
    if @user == Current.user || !@user.removable?
      redirect_to admin_users_path, alert: t(".not_removable")
    else
      @user.destroy!
      redirect_to admin_users_path, notice: t(".deleted", email: @user.email_address), status: :see_other
    end
  end

  private

  def require_hard_delete
    head :not_found unless Rails.configuration.x.hard_delete_users
  end

  def set_user
    @user = User.find(params[:id])
  end

  def user_params
    params.expect(user: [:email_address, :role, :password, :password_confirmation])
  end

  # A new password should log the user out everywhere, except the admin doing the change
  def end_other_sessions(user)
    user.sessions.where.not(id: Current.session.id).delete_all
  end
end
