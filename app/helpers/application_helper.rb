module ApplicationHelper
  def hard_delete_users? = Rails.configuration.x.hard_delete_users
end
