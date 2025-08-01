# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Adding to an existing order" do
  let(:facility) { product.facility }
  let(:order) { create(:purchased_order, product:, ordered_at: 1.week.ago) }
  let(:user) { create(:user, :staff, facility:) }
  let!(:other_account) { create(:nufs_account, :with_account_owner, owner: order.user, description: "Other Account") }

  before do
    login_as user
  end

  describe "submitting blank product" do
    let(:product) { create(:setup_item, :with_facility_account) }
    let(:second_facility) { cross_product.facility }
    let!(:cross_product) { create(:setup_item, :with_facility_account) }

    it "renders errors and populates products select correctly" do
      visit facility_order_path(facility, order)

      expect(page).to(
        have_select("Product", options: ["", product.name])
      )

      select second_facility.name, from: Facility.model_name.human
      click_button "Add To Order"

      expect(page).to have_content("Product can't be blank")
      expect(page).to(
        have_select("Product", options: ["", cross_product.name])
      )
    end
  end

  describe "adding an item" do
    let(:product) { create(:setup_item, :with_facility_account) }

    before do
      visit facility_order_path(facility, order)
      fill_in "add_to_order_form[quantity]", with: "2"
      select product.name, from: "add_to_order_form[product_id]"
      fill_in "Note", with: "My Note"
    end

    describe "adding it as New" do
      before do
        click_button "Add To Order"
      end

      it "has a new order detail" do
        expect(order.reload.order_details.count).to eq(2)
        expect(order.order_details.last.note).to eq("My Note")
      end

      it "sets the ordered_at to now" do
        expect(order.order_details.order(:id).last.ordered_at).to be_within(1.second).of(Time.current)
      end
    end

    describe "adding it as Complete with a backdate" do
      let(:fulfilled_at_string) { I18n.l(1.day.ago.to_date, format: :usa) }

      before do
        select "Complete", from: "Order Status"
        fill_in "add_to_order_form[fulfilled_at]", with: fulfilled_at_string
        click_button "Add To Order"
      end

      it "has a new order detail with the right status and fulfilled_at" do
        expect(order.reload.order_details.count).to eq(2)
        new_order_detail = order.order_details.order(:id).last
        expect(new_order_detail).to be_complete
        expect(I18n.l(new_order_detail.fulfilled_at.to_date, format: :usa)).to eq(fulfilled_at_string)
        expect(I18n.l(new_order_detail.ordered_at.to_date, format: :usa)).to eq(fulfilled_at_string)
      end
    end

    describe "adding it to another account" do
      describe "while the original account is still active" do
        before do
          select other_account.to_s, from: "Payment Source"
          click_button "Add To Order"
        end

        it "creates the order detail with the new account" do
          click_link(order.reload.order_details.last.to_s)
          expect(page).to have_select("Payment Source", selected: other_account.to_s)
        end
      end

      describe "when the original account is expired" do
        before do
          order.account.update!(expires_at: 1.day.ago)
          page.refresh
        end

        it "is blank and cannot be added" do
          expect(page).to have_select("Payment Source", selected: nil)
          expect(page).to have_content("is suspended or expired")
          click_button "Add To Order"
          expect(page).to have_content("Payment Source can't be blank")
        end
      end
    end

    describe "and it does not have pricing set up yet" do
      let(:product) { super().tap { |p| p.price_policies.destroy_all } }

      it "gets purchased with an ordered_at" do
        click_button "Add To Order"
        expect(order.reload.order_details.count).to eq(2)
        new_order_detail = order.order_details.order(:id).last

        expect(new_order_detail.ordered_at).to be_present
      end
    end
  end

  describe "adding a backdated service with an order form" do
    let(:product) { create(:setup_service, :with_facility_account, :with_order_form) }
    let(:fulfilled_at_string) { I18n.l(1.day.ago.to_date, format: :usa) }

    before do
      visit facility_order_path(facility, order)

      fill_in "add_to_order_form[quantity]", with: "1"
      select product.name, from: "add_to_order_form[product_id]"
      select "Complete", from: "Order Status"
      fill_in "add_to_order_form[fulfilled_at]", with: fulfilled_at_string
      click_button "Add To Order"
    end

    it "does not have an ordered_at yet" do
      expect(order.reload.order_details.count).to be(1)
      expect(OrderDetail.order(:id).last.ordered_at).to be_blank
    end

    it "requires a file to be uploaded before adding to the order" do
      expect(page).to have_content("Your order includes one or more incomplete items.")
    end

    describe "after uploading the file" do
      before do
        within("#merge-order-missing-order-info-reminder") do
          click_link "Upload Order Form"
        end
        attach_file "stored_file[file]", Rails.root.join("spec", "files", "template1.txt")
        click_button "Upload"
      end

      it "sets the expected attributes", :aggregate_failures do
        expect(order.reload.order_details.count).to be(2)

        new_order_detail = order.order_details.order(:id).last

        expect(new_order_detail).to be_complete
        expect(I18n.l(new_order_detail.fulfilled_at.to_date, format: :usa)).to eq(fulfilled_at_string)
        expect(I18n.l(new_order_detail.ordered_at.to_date, format: :usa)).to eq(fulfilled_at_string)

        expect(page).to have_content("0 Uploaded"), count: 2
      end
    end
  end

  describe "adding an instrument reservation", :js do
    describe "from same facility" do
      let(:product) { create(:setup_item, :with_facility_account) }
      let!(:instrument) { create(:setup_instrument, facility:) }

      before do
        visit facility_order_path(facility, order)
        fill_in "add_to_order_form[quantity]", with: "1"
        select_from_chosen instrument.name, from: "add_to_order_form[product_id]", scroll_to: :center
        click_button "Add To Order"
      end

      it "requires a reservation to be set up before adding to the order" do
        expect(page).to have_content("Your order includes one or more incomplete items.")

        within("#merge-order-missing-order-info-reminder") do
          click_link "Make a Reservation"
        end
        click_button "Create"

        expect(page).to have_content("The reservation was successfully created")
        expect(order.reload.order_details.count).to be(2)
        expect(order.order_details.last.product).to eq(instrument)
      end

      it "brings you back to the facility order path on 'Cancel'" do
        within("#merge-order-missing-order-info-reminder") do
          click_link "Make a Reservation"
        end
        click_link "Cancel"

        expect(current_path).to eq(facility_order_path(facility, order))
        expect(page).to have_link("Make a Reservation")
      end
    end

    describe "from same facility (with feature flag on)", :js do
      let(:product) { create(:setup_item, :with_facility_account) }
      let!(:instrument) { create(:setup_instrument, facility:) }
      let(:user) { create(:user, :facility_administrator, facility:) }

      before do
        visit facility_order_path(facility, order)
        fill_in "add_to_order_form[quantity]", with: "1"
        select_from_chosen instrument.name, from: "add_to_order_form[product_id]", scroll_to: :center
        click_button "Add To Order"
      end

      it "is accessible" do
        expect(page).to be_axe_clean
      end

      it "requires a reservation to be set up before adding to the order" do
        expect(page).to have_content("Your order includes one or more incomplete items.")
        within("#merge-order-missing-order-info-reminder") do
          click_link "Make a Reservation"
        end
        click_button "Create"

        expect(page).to have_content("The reservation was successfully created")
        expect(order.reload.order_details.count).to be(2)
        expect(order.order_details.last.product).to eq(instrument)
      end

      it "brings you back to the facility order path on 'Cancel'" do
        within("#merge-order-missing-order-info-reminder") do
          click_link "Make a Reservation"
        end
        click_link "Cancel"

        expect(current_path).to eq(facility_order_path(facility, order))
        expect(page).to have_link("Make a Reservation")
      end
    end

    describe "when the instrument has daily booking pricing mode" do
      let(:product) do
        create(
          :setup_item,
          :with_facility_account
        )
      end
      let!(:instrument) do
        create(
          :setup_instrument,
          :always_available,
          facility:,
          pricing_mode: Instrument::Pricing::SCHEDULE_DAILY
        )
      end
      let(:order_detail) do
        create(
          :order_detail,
          order:,
          product: instrument,
          created_by_user: user,
        )
      end
      let(:success_message) { "The reservation was successfully created" }
      let(:reservation_path) do
        new_order_order_detail_reservation_path(order, order_detail)
      end

      include_examples(
        "new daily reservation",
        after_submit: proc do
          expect(Reservation.last.product).to eq(instrument)
        end
      )
    end
  end

  describe "adding a timed service" do
    let(:product) { create(:setup_timed_service, :with_facility_account) }

    before do
      visit facility_order_path(facility, order)
      select product.name, from: "add_to_order_form[product_id]"
      fill_in "add_to_order_form[duration]", with: "31"
      click_button "Add To Order"
    end

    it "has a new order detail with the proper quantity" do
      expect(order.reload.order_details.count).to be(2)
      expect(order.order_details.last.product).to eq(product)
      expect(order.order_details.last.quantity).to eq(31)
    end
  end
end
