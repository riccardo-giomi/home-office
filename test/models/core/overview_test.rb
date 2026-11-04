require "test_helper"

describe Core::Overview do
  let(:user) { users(:admin) }
  let(:other) { users(:member) }

  before { Current.reset }

  def broadcasts_during(owner, &) = capture_turbo_stream_broadcasts(Core::Overview.stream(owner.id), &).size

  it "has a stream for each user" do
    _(Core::Overview.stream(user.id)).wont_equal Core::Overview.stream(other.id)
  end

  it "sends a refresh on the stream of the user" do
    _(broadcasts_during(user) { Core::Overview.refresh(user.id) }).must_equal 1
  end

  it "sends the refresh only to the user it is for" do
    _(broadcasts_during(other) { Core::Overview.refresh(user.id) }).must_equal 0
  end

  it "sends one refresh for all the calls of a transaction" do
    count = broadcasts_during(user) { ActiveRecord::Base.transaction { 3.times { Core::Overview.refresh(user.id) } } }
    _(count).must_equal 1
  end

  it "sends nothing if the transaction is rolled back" do
    count = broadcasts_during(user) do
      ActiveRecord::Base.transaction do
        Core::Overview.refresh(user.id)
        raise ActiveRecord::Rollback
      end
    end
    _(count).must_equal 0
  end

  it "still sends after a rolled back transaction" do
    ActiveRecord::Base.transaction do
      Core::Overview.refresh(user.id)
      raise ActiveRecord::Rollback
    end
    _(broadcasts_during(user) { Core::Overview.refresh(user.id) }).must_equal 1
  end

  it "announces after the block and returns what the block returns" do
    result = nil
    count = broadcasts_during(user) { result = Core::Overview.announce(user.id) { 42 } }
    _(count).must_equal 1
    _(result).must_equal 42
  end

  it "announces nothing if the block raises" do
    count = broadcasts_during(user) do
      Core::Overview.announce(user.id) { raise "no" }
    rescue
      nil
    end
    _(count).must_equal 0
  end
end
