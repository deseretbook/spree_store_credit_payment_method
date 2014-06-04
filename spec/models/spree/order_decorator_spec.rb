require 'spec_helper'

shared_examples "check total store credit from payments" do
  context "with valid payments" do
    let(:order)           { payment.order }
    let!(:payment)        { create(:store_credit_payment) }
    let!(:second_payment) { create(:store_credit_payment, order: order) }

    subject { order }

    it "returns the sum of the payment amounts" do
      subject.total_applicable_store_credit.should eq (payment.amount + second_payment.amount)
    end
  end

  context "without valid payments" do
    let(:order) { create(:order) }

    subject { order }

    it "returns 0" do
      subject.total_applicable_store_credit.should be_zero
    end
  end
end

describe "Order" do
  describe "#add_store_credit_payments" do
  end

  describe "#covered_by_store_credit" do
    context "order doesn't have an associated user" do
      subject { create(:store_credits_order_without_user) }

      it "returns false" do
        subject.covered_by_store_credit.should be_false
      end
    end

    context "order has an associated user" do
      let(:user) { create(:user) }

      subject    { create(:order, user: user) }

      context "user has enough store credit to pay for the order" do
        before do
          user.stub(total_available_store_credit: 10.0)
          subject.stub(total: 5.0)
        end

        it "returns true" do
          subject.covered_by_store_credit.should be_true
        end
      end

      context "user does not have enough store credit to pay for the order" do
        before do
          user.stub(total_available_store_credit: 0.0)
          subject.stub(total: 5.0)
        end

        it "returns false" do
          subject.covered_by_store_credit.should be_false
        end
      end
    end
  end

  describe "#total_available_store_credit" do
    context "order does not have an associated user" do
      subject { create(:store_credits_order_without_user) }

      it "returns 0" do
        subject.total_available_store_credit.should be_zero
      end
    end

    context "order has an associated user" do
      let(:user)                   { create(:user) }
      let(:available_store_credit) { 25.0 }

      subject { create(:order, user: user) }

      before do
        user.stub(total_available_store_credit: available_store_credit)
      end

      it "returns the user's available store credit" do
        subject.total_available_store_credit.should eq available_store_credit
      end
    end
  end

  describe "#order_total_after_store_credit" do
    let(:order_total) { 100.0 }

    subject { create(:order, total: order_total) }

    before do
      subject.stub(total_applicable_store_credit: applicable_store_credit)
    end

    context "order's user has store credits" do
      let(:applicable_store_credit) { 10.0 }

      it "deducts the applicable store credit" do
        subject.order_total_after_store_credit.should eq (order_total - applicable_store_credit)
      end
    end

    context "order's user does not have any store credits" do
      let(:applicable_store_credit) { 0.0 }

      it "returns the order total" do
        subject.order_total_after_store_credit.should eq order_total
      end
    end
  end

  describe "#total_applicable_store_credit" do
    context "order is in the confirm state" do
      before { order.update_attributes(state: 'confirm') }
      include_examples "check total store credit from payments"
    end

    context "order is completed" do
      before { order.update_attributes(state: 'complete') }
      include_examples "check total store credit from payments"
    end

    context "order is in any state other than confirm or complete" do
      context "the associated user has store credits" do
        let(:store_credit) { create(:store_credit) }
        let(:order)        { create(:order, user: store_credit.user) }

        subject { order }

        context "the store credit is more than the order total" do
          let(:order_total) { store_credit.amount - 1 }

          before { order.update_attributes(total: order_total) }

          it "returns the order total" do
            subject.total_applicable_store_credit.should eq order_total
          end
        end

        context "the store credit is less than the order total" do
          let(:order_total) { store_credit.amount * 10 }

          before { order.update_attributes(total: order_total) }

          it "returns the store credit amount" do
            subject.total_applicable_store_credit.should eq store_credit.amount
          end
        end
      end

      context "the associated user does not have store credits" do
        let(:order) { create(:order) }

        subject { order }

        it "returns 0" do
          subject.total_applicable_store_credit.should be_zero
        end
      end

      context "the order does not have an associated user" do
        subject { create(:store_credits_order_without_user) }

        it "returns 0" do
          subject.total_applicable_store_credit.should be_zero
        end
      end
    end
  end

  describe "#display_total_applicable_store_credit" do
    let(:total_applicable_store_credit) { 10.00 }

    subject { create(:order) }

    before { subject.stub(total_applicable_store_credit: total_applicable_store_credit) }

    it "returns a money instance" do
      subject.display_total_applicable_store_credit.should be_a(Spree::Money)
    end

    it "returns a negative amount" do
      subject.display_total_applicable_store_credit.money.cents.should eq (total_applicable_store_credit * -100.0)
    end
  end

  describe "#display_order_total_after_store_credit" do
    let(:order_total_after_store_credit) { 10.00 }

    subject { create(:order) }

    before { subject.stub(order_total_after_store_credit: order_total_after_store_credit) }

    it "returns a money instance" do
      subject.display_order_total_after_store_credit.should be_a(Spree::Money)
    end

    it "returns the order_total_after_store_credit amount" do
      subject.display_order_total_after_store_credit.money.cents.should eq (order_total_after_store_credit * 100.0)
    end
  end

  describe "#display_total_available_store_credit" do
    let(:total_available_store_credit) { 10.00 }

    subject { create(:order) }

    before { subject.stub(total_available_store_credit: total_available_store_credit) }

    it "returns a money instance" do
      subject.display_total_available_store_credit.should be_a(Spree::Money)
    end

    it "returns the total_available_store_credit amount" do
      subject.display_total_available_store_credit.money.cents.should eq (total_available_store_credit * 100.0)
    end
  end

  describe "#display_store_credit_remaining_after_capture" do
    let(:total_available_store_credit)  { 10.00 }
    let(:total_applicable_store_credit) { 5.00 }

    subject { create(:order) }

    before do
      subject.stub(total_available_store_credit: total_available_store_credit,
                   total_applicable_store_credit: total_applicable_store_credit)
    end

    it "returns a money instance" do
      subject.display_store_credit_remaining_after_capture.should be_a(Spree::Money)
    end

    it "returns all of the user's available store credit minus what's applied to the order amount" do
      amount_remaining = total_available_store_credit - total_applicable_store_credit
      subject.display_store_credit_remaining_after_capture.money.cents.should eq (amount_remaining * 100.0)
    end
  end
end
