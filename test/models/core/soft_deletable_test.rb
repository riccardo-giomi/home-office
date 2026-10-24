require "test_helper"

describe Core::SoftDeletable do
  let(:item) { planner_items(:dentist) }

  # The fixtures hold trashed rows of their own. These examples count exactly
  # what they trash.
  before { Core::Entity.trashed.update_all(deleted_at: nil) }

  def trash_one(old: false)
    planner_items(:holiday).tap do |other|
      other.entity.update_columns(deleted_at: (old ? 40.days : 2.days).ago)
    end
  end

  describe "on the entity" do
    it "splits the table into kept and trashed, with no default scope" do
      trash_one
      _(Core::Entity.kept.pluck(:id) & Core::Entity.trashed.pluck(:id)).must_be :empty?
      _(Core::Entity.trashed.count).must_equal 1
      _(Core::Entity.kept.count + Core::Entity.trashed.count).must_equal Core::Entity.count
      _(Core::Entity.all.to_sql).wont_include "deleted_at"
      _(Planner::Item.all.to_sql).wont_include "deleted_at"
    end

    it "trashes without touching updated_at, and restores" do
      entity = item.entity
      before = entity.updated_at
      entity.trash
      _(entity.reload).must_be :trashed?
      _(entity.deleted_at).must_be_close_to Time.current, 5
      _(entity.updated_at).must_equal before
      entity.restore
      _(entity.reload).wont_be :trashed?
    end

    it "keeps what was trashed less than 30 days ago and purges older" do
      now = Time.current
      item.entity.update_columns(deleted_at: now - 30.days + 1.second)
      _(Core::Entity.purgeable(now)).wont_include item.entity
      item.entity.update_columns(deleted_at: now - 30.days - 1.second)
      _(Core::Entity.purgeable(now)).must_include item.entity
    end

    it "purges only the expired, says how many and takes their records along" do
      trash_one(old: true)
      planner_items(:rent_paid).entity.update_columns(deleted_at: 2.days.ago)
      kept = Core::Entity.kept.count
      items = Planner::Item.count
      _(Core::Entity.purge_expired).must_equal 1
      _(Planner::Item.count).must_equal items - 1
      _(Core::Entity.kept.count).must_equal kept
      _(Core::Entity.trashed.count).must_equal 1
      _(Core::Entity.purge_expired).must_equal 0
    end
  end

  describe "through the record" do
    it "partitions the items and hides a trashed one from kept" do
      trash_one
      _(Planner::Item.kept.pluck(:id) & Planner::Item.trashed.pluck(:id)).must_be :empty?
      _(Planner::Item.kept.count + Planner::Item.trashed.count).must_equal Planner::Item.count
      found = Planner::Item.includes(:entity).find(item.id)
      found.trash
      _(Planner::Item.kept).wont_include item
      _(Planner::Item.trashed).must_include item
      found.restore
      _(Planner::Item.kept).must_include item
    end

    it "trashes a row that no longer validates" do
      found = Planner::Item.includes(:entity).find(item.id)
      found.title = ""
      _(found).wont_be :valid?
      found.trash
      _(found.entity.reload).must_be :trashed?
    end

    it "does not read the trash state without the entity preloaded (strict loading)" do
      _ { Planner::Item.find(item.id).deleted_at }.must_raise ActiveRecord::StrictLoadingViolationError
    end
  end
end
