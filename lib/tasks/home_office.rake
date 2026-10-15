namespace :home_office do
  desc "Set up a fresh install: creates the first administrator (HOME_OFFICE_ADMIN_PASSWORD or a hidden prompt)"
  task :setup, [:email] => :environment do |_task, args|
    Core::Setup::Runner.new.call(email: args[:email])
  rescue Core::Setup::Error => error
    abort error.message
  end
end
