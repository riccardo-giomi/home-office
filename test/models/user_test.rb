require "test_helper"

describe User do
  def build(**attributes)
    User.new({email_address: "new@example.com", password: TEST_PASSWORD}.merge(attributes))
  end

  it "normalizes the email address" do
    _(build(email_address: "  New@Example.COM ").email_address).must_equal "new@example.com"
  end

  it "requires a valid email address" do
    _(build(email_address: "nope")).wont_be :valid?
    _(build(email_address: "")).wont_be :valid?
  end

  it "requires a unique email address, ignoring case and spaces" do
    _(build(email_address: " ADMIN@example.com")).wont_be :valid?
  end

  it "requires a password of at least 12 characters on create" do
    _(build(password: "short")).wont_be :valid?
    _(build(password: "x" * 12)).must_be :valid?
  end

  it "keeps the password when updating without one" do
    user = users(:member)
    digest = user.password_digest
    user.update!(email_address: "renamed@example.com")
    _(user.reload.password_digest).must_equal digest
  end

  it "defaults to the user role and rejects unknown roles" do
    _(build.role).must_equal "user"
    _(build(role: "boss")).wont_be :valid?
  end

  it "does not let the only admin be demoted" do
    users(:other_admin).update!(role: :user)
    admin = users(:admin)
    _(admin.update(role: :user)).must_equal false
    _(admin.errors[:role]).wont_be :empty?
  end

  it "lets one of two admins be demoted" do
    _(users(:other_admin).update(role: :user)).must_equal true
  end

  it "translates Rails validation messages into Italian" do
    user = build(email_address: "")
    user.valid?
    I18n.with_locale(:it) do
      _(user.errors.full_messages.join).wont_match(/can't be blank|is invalid/)
    end
  end
end
