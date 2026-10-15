# A stand-in record for previews and component tests: the components take any ActiveModel object,
# and this one has the shape of the sign-in and user forms without needing a table
class ExampleUser
  include ActiveModel::Model

  attr_accessor :email_address, :password, :role

  validates :email_address, presence: true
  validates :password, length: {minimum: 12}, allow_blank: true
end
