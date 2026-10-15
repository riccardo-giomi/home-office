require "test_helper"

describe Core::Setup::AdminStep do
  def context(email: "boss@example.com", env: {"HOME_OFFICE_ADMIN_PASSWORD" => "a long enough password"}, password_reader: ->(_prompt) {}, input: StringIO.new)
    Core::Setup::Context.new(email:, input:, output: StringIO.new, env:, password_reader:)
  end

  before { User.delete_all }

  it "creates the first administrator from the environment password" do
    result = Core::Setup::AdminStep.new.call(context)
    assert_equal "admin", User.find_by!(email_address: "boss@example.com").role
    _(result).must_equal I18n.t("core.setup.admin.created", email: "boss@example.com")
  end

  it "is skipped when an administrator already exists, and changes nothing" do
    Core::Setup::AdminStep.new.call(context)
    assert_no_difference "User.count" do
      _(Core::Setup::AdminStep.new.call(context(email: "second@example.com"))).must_equal I18n.t("core.setup.admin.skipped")
    end
  end

  it "refuses a password that is too short and creates nobody" do
    error = _ { Core::Setup::AdminStep.new.call(context(env: {"HOME_OFFICE_ADMIN_PASSWORD" => "short"})) }.must_raise Core::Setup::Error
    _(error.message).must_match(/12/)
    _(User.count).must_equal 0
  end

  it "fails clearly with no password and no terminal" do
    error = _ { Core::Setup::AdminStep.new.call(context(env: {})) }.must_raise Core::Setup::Error
    _(error.message).must_equal I18n.t("core.setup.admin.no_password")
  end

  it "asks for the email when no argument was given and reads a typed password twice" do
    prompts = []
    reader = ->(prompt) { prompts << prompt && "typed in secret pw" }
    step_context = context(email: nil, env: {}, password_reader: reader, input: StringIO.new("boss@example.com\n"))
    Core::Setup::AdminStep.new.call(step_context)
    _(User.find_by(email_address: "boss@example.com")).wont_be_nil
    _(prompts).must_equal [I18n.t("core.setup.admin.password_prompt"), I18n.t("core.setup.admin.password_confirm_prompt")]
  end

  it "refuses a typed password that does not match its confirmation" do
    answers = ["typed in secret pw", "typed in other pw"]
    error = _ { Core::Setup::AdminStep.new.call(context(env: {}, password_reader: ->(_prompt) { answers.shift })) }.must_raise Core::Setup::Error
    _(error.message).must_equal I18n.t("core.setup.admin.password_mismatch")
    _(User.count).must_equal 0
  end
end
