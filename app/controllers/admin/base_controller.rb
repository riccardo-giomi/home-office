class Admin::BaseController < ApplicationController
  before_action :require_admin

  private

  def require_admin
    redirect_to root_path, alert: t("admin.forbidden") unless Current.user.admin?
  end
end
