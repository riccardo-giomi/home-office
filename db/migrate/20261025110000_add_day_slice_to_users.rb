class AddDaySliceToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :day_start_hour, :integer, null: false, default: 7
    add_column :users, :day_end_hour, :integer, null: false, default: 21
    add_check_constraint :users, "day_start_hour BETWEEN 0 AND 23", name: "chk_users_day_start_hour"
    add_check_constraint :users, "day_end_hour BETWEEN 0 AND 23", name: "chk_users_day_end_hour"
    add_check_constraint :users, "day_start_hour <= day_end_hour", name: "chk_users_day_hours_order"
  end
end
