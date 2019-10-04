require 'spec_helper'
require 'pry'
require 'dotenv/load'

describe Lita::Services::MarketManager, lita: true do
  let(:robot) { Lita::Robot.new(registry) }
  let(:karmanager) do
    Lita::Services::Karmanager.new(Lita::Handlers::LunchReminder.new(robot).redis)
  end
  let(:lunch_assigner) do
    Lita::Services::LunchAssigner.new(Lita::Handlers::LunchReminder.new(robot).redis, karmanager)
  end
  let(:subject) do
    described_class.new(
      Lita::Handlers::LunchReminder.new(robot).redis,
      lunch_assigner,
      karmanager
    )
  end
  let(:fdom) { Lita::User.create(127, mention_name: 'fdom') }
  let(:andres) { Lita::User.create(137, mention_name: 'andres') }
  let(:oscar) { Lita::User.create(147, mention_name: 'oscar') }
  let(:fernanda) { Lita::User.create(157, mention_name: 'fernanda') }
  let(:order_id) { SecureRandom.uuid }
  let(:order_time) { Time.now }

  def add_limit_order(order_id, user, type, created_at)
    order = {
      id: order_id,
      user_id: user.id,
      type: type,
      created_at: created_at
    }.to_json
    subject.add_limit_order(order)
    order
  end

  def setup_lunchers
    [andres, fdom].each do |user|
      lunch_assigner.add_to_lunchers(user.mention_name)
      lunch_assigner.add_to_current_lunchers(user.mention_name)
    end

    lunch_assigner.add_to_winning_lunchers(andres.mention_name)
  end

  before do
    ENV['MAX_LUNCHERS'] = '20'
  end

  describe '#add_limit_order' do
    context 'first order added' do
      before do
        add_limit_order(order_id, fdom, 'ask', order_time)
      end

      it 'adds order to limit orders' do
        add_limit_order(order_id, fdom, 'ask', order_time)
        expect(subject.orders.last).not_to be_nil
      end

      it 'adds the correct limit order' do
        add_limit_order(order_id, fdom, 'ask', order_time)
        expect(subject.orders.last['id']).to eq(order_id)
      end
    end

    context 'with non empty orders' do
      before do
        add_limit_order(SecureRandom.uuid, andres, 'ask', Time.new(2018, 10, 2))
      end

      it 'adds limit order' do
        expect(subject.orders.last).not_to be_nil
      end

      it 'sorts orders by date' do
        add_limit_order(order_id, fdom, 'ask', order_time)
        expect(subject.orders.last['user_id']).to eq(fdom.id)
        expect(subject.orders.last['id']).to eq(order_id)
        expect(subject.orders.last['type']).to eq('ask')
        last_order_created_at = Time.parse(subject.orders.last['created_at']).strftime('%F %T %z')
        expect(last_order_created_at).to eq(order_time.strftime('%F %T %z'))
      end
    end

    context 'user already has an order' do
      let(:old_order_id) { SecureRandom.uuid }
      let(:new_order) { add_limit_order(SecureRandom.uuid, fdom, 'ask', Time.now) }
      before do
        add_limit_order(old_order_id, fdom, 'ask', order_time)
        allow(subject).to receive(:placed_limit_order?).with(fdom.id).and_return true
      end

      it "doesn't add order to list" do
        subject.add_limit_order(new_order)
        expect(subject.orders.size).to eq(1)
      end

      it "doesn't edit list" do
        add_limit_order(SecureRandom.uuid, fdom, 'ask', order_time)
        expect(subject.orders.first['id']).to eq(old_order_id)
      end

      it 'calls placed_limit_order?' do
        add_limit_order(SecureRandom.uuid, fdom, 'ask', order_time)
        expect(subject).to have_received(:placed_limit_order?).with(fdom.id)
      end

      it 'placed_limit_order? returns true' do
        add_limit_order(SecureRandom.uuid, fdom, 'ask', order_time)
        expect(subject.placed_limit_order?(fdom.id)).to eq(true)
      end
    end
  end

  describe '#placed_limit_order?' do
    context 'user already has an order' do
      before do
        add_limit_order(SecureRandom.uuid, fdom, 'ask', Time.now)
      end

      it { expect(subject.placed_limit_order?(fdom.id)).to be true }
    end

    context "user doesn't have an order" do
      before do
        add_limit_order(SecureRandom.uuid, andres, 'ask', Time.now)
      end

      it { expect(subject.placed_limit_order?(fdom.id)).to be false }
    end
  end

  describe '#orders' do
    context 'without orders' do
      it { expect(subject.orders.size).to eq(0) }
    end

    context 'with one order' do
      before do
        add_limit_order(SecureRandom.uuid, andres, 'ask', Time.now)
      end

      it { expect(subject.orders.size).to eq(1) }
    end

    context 'with more than one order' do
      before do
        add_limit_order(SecureRandom.uuid, andres, 'ask', Time.new(2018, 10, 5))
        add_limit_order(SecureRandom.uuid, fdom, 'ask', Time.new(2018, 10, 3))
        add_limit_order(SecureRandom.uuid, oscar, 'ask', Time.new(2018, 10, 4))
      end

      it { expect(subject.orders.size).to eq(3) }
      it 'sorts orders by date' do
        expect(subject.orders[0]['user_id']).to eq(fdom.id)
        expect(subject.orders[1]['user_id']).to eq(oscar.id)
        expect(subject.orders[2]['user_id']).to eq(andres.id)
      end
    end
  end

  describe '#ask_orders' do
    context 'without orders' do
      it { expect(subject.ask_orders.size).to eq(0) }
    end

    context 'with one order' do
      before do
        add_limit_order(SecureRandom.uuid, andres, 'ask', Time.now)
      end

      it { expect(subject.ask_orders.size).to eq(1) }
    end

    context 'with more than one order' do
      before do
        add_limit_order(SecureRandom.uuid, andres, 'ask', Time.new(2018, 10, 5))
        add_limit_order(SecureRandom.uuid, fdom, 'ask', Time.new(2018, 10, 3))
        add_limit_order(SecureRandom.uuid, oscar, 'ask', Time.new(2018, 10, 4))
      end

      it { expect(subject.orders.size).to eq(3) }
      it 'sorts orders by date' do
        expect(subject.ask_orders[0]['user_id']).to eq(fdom.id)
        expect(subject.ask_orders[1]['user_id']).to eq(oscar.id)
        expect(subject.ask_orders[2]['user_id']).to eq(andres.id)
      end
    end
  end

  describe '#bid_orders' do
    context 'without orders' do
      it { expect(subject.bid_orders.size).to eq(0) }
    end

    context 'with one order' do
      before do
        add_limit_order(SecureRandom.uuid, andres, 'bid', Time.now)
      end

      it { expect(subject.bid_orders.size).to eq(1) }
    end

    context 'with more than one order' do
      before do
        add_limit_order(SecureRandom.uuid, andres, 'bid', Time.new(2018, 10, 5))
        add_limit_order(SecureRandom.uuid, fdom, 'bid', Time.new(2018, 10, 3))
        add_limit_order(SecureRandom.uuid, oscar, 'bid', Time.new(2018, 10, 4))
      end

      it { expect(subject.orders.size).to eq(3) }
      it 'sorts orders by date' do
        expect(subject.bid_orders[0]['user_id']).to eq(fdom.id)
        expect(subject.bid_orders[1]['user_id']).to eq(oscar.id)
        expect(subject.bid_orders[2]['user_id']).to eq(andres.id)
      end
    end
  end

  describe '#reset_limit_orders' do
    before do
      add_limit_order(SecureRandom.uuid, andres, 'ask', Time.new(2018, 10, 5))
      add_limit_order(SecureRandom.uuid, fdom, 'ask', Time.new(2018, 10, 3))
      add_limit_order(SecureRandom.uuid, oscar, 'ask', Time.new(2018, 10, 4))
      subject.reset_limit_orders
    end

    it { expect(subject.orders.size).to eq(0) }
  end

  describe '#execute_transaction' do
    context 'exists one order' do
      it "doesn't execute the transaction" do
        add_limit_order(SecureRandom.uuid, andres, 'ask', Time.new(2018, 10, 5))
        subject.execute_transaction
        expect(subject.ask_orders.size).to eq(1)
      end
    end

    context 'exists two orders' do
      before do
        karmanager.set_karma(fdom.id, 100)
        karmanager.set_karma(andres.id, 100)
        setup_lunchers
      end

      it 'removes orders' do
        add_limit_order(SecureRandom.uuid, andres, 'ask', Time.new(2018, 10, 5))
        add_limit_order(SecureRandom.uuid, fdom, 'bid', Time.new(2018, 10, 3))
        subject.execute_transaction
        expect(subject.ask_orders.size).to eq(0)
        expect(subject.bid_orders.size).to eq(0)
      end

      it 'transfers karma from buyer to asker' do
        add_limit_order(SecureRandom.uuid, andres, 'ask', Time.new(2018, 10, 5))
        add_limit_order(SecureRandom.uuid, fdom, 'bid', Time.new(2018, 10, 3))
        karma_fdom = karmanager.get_karma(fdom.id)
        karma_andres = karmanager.get_karma(andres.id)
        subject.execute_transaction
        expect(karmanager.get_karma(fdom.id)).to eq(karma_fdom - 1)
        expect(karmanager.get_karma(andres.id)).to eq(karma_andres + 1)
      end

      it 'adds buyer to winning lunchers' do
        add_limit_order(SecureRandom.uuid, andres, 'ask', Time.new(2018, 10, 5))
        add_limit_order(SecureRandom.uuid, fdom, 'bid', Time.new(2018, 10, 3))
        subject.execute_transaction
        expect(lunch_assigner.winning_lunchers_list).to include(fdom.mention_name)
      end
    end

    context 'exists more than two orders' do
      before do
        add_limit_order(SecureRandom.uuid, andres, 'ask', Time.new(2018, 10, 1))
        add_limit_order(SecureRandom.uuid, oscar, 'ask', Time.new(2018, 10, 5))
        add_limit_order(SecureRandom.uuid, fdom, 'bid', Time.new(2018, 10, 3))
        setup_lunchers
      end

      it 'matchs the correct limit order' do
        orders = subject.execute_transaction
        expect(orders['ask']['user_id']).to eq(andres.id)
        expect(orders['bid']['user_id']).to eq(fdom.id)
      end

      it 'remove order from limit orders' do
        subject.execute_transaction
        expect(subject.ask_orders.size).to eq(1)
      end
    end
  end

  describe '#transaction_possible?' do
    context 'transaction possible' do
      it 'returns true' do
        add_limit_order(SecureRandom.uuid, oscar, 'ask', Time.new(2018, 10, 5))
        add_limit_order(SecureRandom.uuid, fdom, 'bid', Time.new(2018, 10, 3))
        expect(subject.transaction_possible?).to be(true)
      end
    end

    context 'transaction not possible' do
      it 'returns false' do
        add_limit_order(SecureRandom.uuid, oscar, 'ask', Time.new(2018, 10, 5))
        expect(subject.transaction_possible?).to be(false)
      end
    end
  end
end
