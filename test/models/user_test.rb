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

  describe "deactivating" do
    it "keeps deactivated users out of the active scope" do
      _(User.active).wont_include users(:retired)
      _(User.active).must_include users(:member)
      _(users(:retired)).must_be :deactivated?
      _(users(:member)).must_be :active?
    end

    it "marks the user, deletes their sessions and keeps their data" do
      member = users(:member)
      member.sessions.create!
      Planner::Todo.create!(user: member, title: "Mine")
      _(member.deactivate).must_equal true
      _(member.reload).must_be :deactivated?
      _(member.sessions.count).must_equal 0
      _(Planner::Todo.where(user: member).count).must_equal 1
    end

    it "refuses to deactivate the only active admin, and says why" do
      users(:other_admin).update!(role: :user)
      admin = users(:admin)
      _(admin.deactivate).must_equal false
      _(admin.errors[:base]).wont_be :empty?
      _(admin.reload).must_be :active?
    end

    it "does not count a deactivated admin as one who could take over" do
      other = users(:other_admin)
      other.deactivate
      _(users(:admin).deactivate).must_equal false
      _(users(:admin).update(role: :user)).must_equal false
    end

    it "lets one of two active admins be deactivated" do
      _(users(:other_admin).deactivate).must_equal true
    end

    it "refuses to deactivate someone already deactivated" do
      _(users(:retired).deactivate).must_equal false
      _(users(:retired).errors[:base]).wont_be :empty?
    end

    it "reactivates" do
      _(users(:retired).reactivate).must_equal true
      _(users(:retired).reload).must_be :active?
    end

    it "lets a deactivated admin be demoted, since they are not the one keeping the app administered" do
      other = users(:other_admin)
      other.deactivate
      other.reload
      _(other.update(role: :user)).must_equal true
    end
  end

  it "translates Rails validation messages into Italian" do
    user = build(email_address: "")
    user.valid?
    I18n.with_locale(:it) do
      _(user.errors.full_messages.join).wont_match(/can't be blank|is invalid/)
    end
  end
end
