require "test_helper"

# SQLite cannot check across tables without triggers: an entity whose record is missing is found here
describe "entities and their records" do
  it "have no entity without its record" do
    Rails.application.eager_load!
    _(Core::EntityRecord.record_classes).wont_be_empty
    Core::EntityRecord.record_classes.each do |record_class|
      strays = Core::Entity.where(record_type: record_class.name).where.not(id: record_class.select(:id))
      _(strays.pluck(:id)).must_be_empty
    end
  end
end
