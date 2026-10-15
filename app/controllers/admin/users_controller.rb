class Admin::UsersController < Admin::BaseController
  before_action :set_user, only: %i[edit update]

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

  private

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
