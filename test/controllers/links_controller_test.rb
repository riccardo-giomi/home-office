require "test_helper"

class LinksControllerTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }
  let(:holiday) { planner_items(:holiday) }
  let(:rent) { planner_items(:rent_paid) }

  before do
    admin.update!(locale: "en")
    sign_in_as admin
  end

  describe "POST create" do
    it "links two records and announces the other end" do
      assert_difference "Core::Link.count", 1 do
        post links_path, params: {entity_id: holiday.id, other_id: rent.id}
      end
      assert_redirected_to planner_event_path(holiday)
      assert flash[:notice].start_with?("Linked to ")
      link = Core::Link.order(:id).last
      _([link.first_entity_id, link.second_entity_id]).must_equal [holiday.id, rent.id].sort
      _(link.user_id).must_equal admin.id
    end

    it "answers a Turbo request with a refresh of the page behind" do
      post links_path, params: {entity_id: holiday.id, other_id: rent.id}, as: :turbo_stream
      assert_equal "text/vnd.turbo-stream.html", response.media_type
      assert_select "turbo-stream[action=refresh]:not([request-id])", 1
    end

    it "says so, and adds nothing, when the pair is there already" do
      post links_path, params: {entity_id: holiday.id, other_id: rent.id}
      assert_no_difference "Core::Link.count" do
        post links_path, params: {entity_id: rent.id, other_id: holiday.id}
      end
      assert flash[:notice].start_with?("Already linked to ")
    end

    it "refuses a link to itself, with a message and no error page" do
      assert_no_difference "Core::Link.count" do
        post links_path, params: {entity_id: holiday.id, other_id: holiday.id}
      end
      assert_equal "You cannot link a record to itself.", flash[:alert]
    end

    it "refuses a trashed record at either end" do
      assert_no_difference "Core::Link.count" do
        post links_path, params: {entity_id: holiday.id, other_id: planner_items(:trashed_event).id}
        post links_path, params: {entity_id: planner_items(:trashed_event).id, other_id: holiday.id}
      end
      assert_response :not_found
    end

    it "answers 404 for another user's record at either end, and links nothing" do
      foreign = planner_items(:other_users_event)
      assert_no_difference "Core::Link.count" do
        post links_path, params: {entity_id: holiday.id, other_id: foreign.id}
        assert_response :not_found
        post links_path, params: {entity_id: foreign.id, other_id: holiday.id}
        assert_response :not_found
        post links_path, params: {entity_id: holiday.id, other_id: 0}
        assert_response :not_found
      end
    end
  end

  describe "PATCH update" do
    let(:link) { core_links(:dentist_and_pay_rent) }
    let(:dentist) { planner_items(:dentist) }

    it "replaces the other end" do
      patch link_path(link), params: {entity_id: dentist.id, other_id: holiday.id}
      _(link.reload.other_id(dentist.id)).must_equal holiday.id
      assert flash[:notice].start_with?("Link changed")
    end

    it "says so when the new pair exists, and changes nothing" do
      patch link_path(link), params: {entity_id: dentist.id, other_id: planner_items(:water_plants_todo).id}
      _(link.reload.other_id(dentist.id)).must_equal planner_items(:pay_rent_task).id
      assert flash[:notice].start_with?("Already linked to ")
    end

    it "answers 404 for another user's link, or one that is not on this record" do
      patch link_path(core_links(:other_users_pair)), params: {entity_id: dentist.id, other_id: holiday.id}
      assert_response :not_found
      patch link_path(core_links(:pay_rent_and_buy_stamps)), params: {entity_id: dentist.id, other_id: holiday.id}
      assert_response :not_found
    end
  end

  describe "DELETE destroy" do
    it "removes the link at once, naming the other end" do
      link = core_links(:dentist_and_pay_rent)
      assert_difference "Core::Link.count", -1 do
        delete link_path(link), params: {entity_id: planner_items(:dentist).id}
      end
      assert flash[:notice].start_with?("Link to Pay the rent removed")
    end

    it "removes a link to a record in the trash" do
      assert_difference "Core::Link.count", -1 do
        delete link_path(core_links(:dentist_and_trashed_task)), params: {entity_id: planner_items(:dentist).id}
      end
    end

    it "answers 404 for another user's link and leaves it" do
      assert_no_difference "Core::Link.count" do
        delete link_path(core_links(:other_users_pair)), params: {entity_id: planner_items(:dentist).id}
      end
      assert_response :not_found
    end
  end

  describe "GET new (the picker)" do
    it "offers each kind as a tab and lists the records of the first" do
      get new_link_path(entity_id: holiday.id)
      assert_response :success
      assert_select "turbo-frame#links-section-picker"
      assert_select "turbo-frame#links-section-picker a[aria-current=true]", text: /Events/
      assert_select "turbo-frame#links-section-picker a", text: /Tasks/
      assert_select "turbo-frame#links-section-picker a", text: /Todos/
    end

    it "shows each kind" do
      %w[event task todo].each do |key|
        get new_link_path(entity_id: holiday.id, kind: key)
        assert_response :success
        assert_select "a[aria-current=true]"
      end
    end

    it "falls back to the first kind for a word it does not know" do
      get new_link_path(entity_id: holiday.id, kind: "Kernel")
      assert_response :success
      assert_select "a[aria-current=true]", text: /Events/
    end

    it "searches by title, never lists the record itself, and marks what is linked" do
      get new_link_path(entity_id: planner_items(:dentist).id, kind: "task", q: "rent")
      assert_select "li", text: /Pay the rent/
      assert_select "li", text: /Already linked/
      assert_select "li", text: /Buy stamps/, count: 0
      get new_link_path(entity_id: planner_items(:dentist).id, kind: "event", q: "dentist")
      assert_select "li", text: /Dentist/, count: 0
    end

    it "does not list trashed or other users' records" do
      get new_link_path(entity_id: holiday.id, kind: "task")
      assert_select "li", text: /#{planner_items(:trashed_task).title}/, count: 0
      assert_select "li", text: /#{planner_items(:other_users_task).title}/, count: 0
    end

    it "changes the other end of a link: its buttons patch that link" do
      link = core_links(:dentist_and_pay_rent)
      get new_link_path(entity_id: planner_items(:dentist).id, kind: "event", change: link.id)
      assert_select "form[action='#{link_path(link)}'] input[name=_method][value=patch]"
    end

    it "answers 404 for another user's record or link" do
      get new_link_path(entity_id: planner_items(:other_users_event).id)
      assert_response :not_found
      get new_link_path(entity_id: holiday.id, change: core_links(:other_users_pair).id)
      assert_response :not_found
    end

    it "closes with an empty frame" do
      get new_link_path(entity_id: holiday.id, close: 1)
      assert_select "turbo-frame#links-section-picker", 1
      assert_select "turbo-frame#links-section-picker *", 0
    end

    it "wants a signed-in user" do
      delete session_path
      get new_link_path(entity_id: holiday.id)
      assert_redirected_to new_session_path
    end
  end
end
