require 'spec_helper'
require 'pry'
require 'dotenv/load'

describe Lita::Services::MarketManager, lita: true do
  before do
    allow(Lita::Services::SpreadsheetManager).to receive(:new).and_return(sh_manager)
    allow(ENV).to receive(:fetch)
        .with('GOOGLE_SP_DB_KEY')
        .and_return('KEY')
    allow(sh_manager).to receive(:insert_new_row)
  end

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
  let(:order_time) { Time.now }
  let(:sh_manager) { double }

  def add_limit_order(user, type, created_at, price = 1)
    subject.add_limit_order(
      user: user, type: type, created_at: created_at, price: price
    )
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
    context 'without orders added' do
      before do
        add_limit_order(fdom, 'ask', order_time)
      end

      it 'adds order to limit orders' do
        expect(subject.orders.size).to eq(1)
      end

      it 'adds the correct limit order' do
        expect(subject.orders.last).to include(
          'user_id' => fdom.id,
          'type' => 'ask',
          'created_at' => order_time.strftime('%FT%T.%L%:z'),
          'id' => be_a(String),
          'price' => 1
        )
      end
    end

    context 'with previous orders added' do
      before do
        add_limit_order(andres, 'ask', Time.new(2018, 10, 2))
        add_limit_order(fdom, 'ask', order_time)
      end

      it 'sorts orders by date' do
        expect(subject.orders.first).to include(
          'user_id' => andres.id,
          'type' => 'ask',
          'created_at' => Time.new(2018, 10, 2).strftime('%FT%T.%L%:z'),
          'id' => be_a(String),
          'price' => 1
        )
        expect(subject.orders.last).to include(
          'user_id' => fdom.id,
          'type' => 'ask',
          'created_at' => order_time.strftime('%FT%T.%L%:z'),
          'id' => be_a(String),
          'price' => 1
        )
      end
    end

    context 'user already has an order' do
      before do
        allow(subject).to receive(:placed_limit_order?).with(fdom.id).and_return true
      end

      it 'calls placed_limit_order?' do
        add_limit_order(fdom, 'ask', order_time)
        expect(subject).to have_received(:placed_limit_order?).with(fdom.id)
      end

      it "doesn't add order to list" do
        add_limit_order(fdom, 'ask', order_time)
        expect(subject.orders.size).to eq(0)
      end
    end

    context 'with an explicit price' do
      before do
        add_limit_order(fdom, 'ask', order_time, 10)
      end

      it 'adds order to limit orders' do
        expect(subject.orders.size).to eq(1)
      end

      it 'adds the correct limit order' do
        expect(subject.orders.last).to include(
          'user_id' => fdom.id,
          'type' => 'ask',
          'created_at' => order_time.strftime('%FT%T.%L%:z'),
          'id' => be_a(String),
          'price' => 10
        )
      end
    end
  end

  describe '#placed_limit_order?' do
    context 'user already has an order' do
      before do
        add_limit_order(fdom, 'ask', Time.now)
      end

      it { expect(subject.placed_limit_order?(fdom.id)).to be true }
    end

    context "user doesn't have an order" do
      before do
        add_limit_order(andres, 'ask', Time.now)
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
        add_limit_order(andres, 'ask', Time.now)
      end

      it { expect(subject.orders.size).to eq(1) }
    end

    context 'with more than one order' do
      before do
        add_limit_order(andres, 'ask', Time.new(2018, 10, 5))
        add_limit_order(fdom, 'ask', Time.new(2018, 10, 3))
        add_limit_order(oscar, 'ask', Time.new(2018, 10, 4))
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
        add_limit_order(andres, 'ask', Time.now)
      end

      it { expect(subject.ask_orders.size).to eq(1) }
    end

    context 'with more than one order' do
      before do
        add_limit_order(andres, 'ask', Time.new(2018, 10, 5), 1)
        add_limit_order(fdom, 'ask', Time.new(2018, 10, 3), 3)
        add_limit_order(oscar, 'ask', Time.new(2018, 10, 4), 3)
      end

      it { expect(subject.orders.size).to eq(3) }

      it 'sorts orders by date' do
        expect(subject.ask_orders[0]['user_id']).to eq(andres.id)
        expect(subject.ask_orders[1]['user_id']).to eq(fdom.id)
        expect(subject.ask_orders[2]['user_id']).to eq(oscar.id)
      end
    end
  end

  describe '#bid_orders' do
    context 'without orders' do
      it { expect(subject.bid_orders.size).to eq(0) }
    end

    context 'with one order' do
      before do
        add_limit_order(andres, 'bid', Time.now)
      end

      it { expect(subject.bid_orders.size).to eq(1) }
    end

    context 'with more than one order' do
      before do
        add_limit_order(andres, 'bid', Time.new(2018, 10, 5), 2)
        add_limit_order(fdom, 'bid', Time.new(2018, 10, 3), 2)
        add_limit_order(oscar, 'bid', Time.new(2018, 10, 4), 1)
      end

      it { expect(subject.orders.size).to eq(3) }

      it 'sorts orders by date and price' do
        expect(subject.bid_orders[0]['user_id']).to eq(fdom.id)
        expect(subject.bid_orders[1]['user_id']).to eq(andres.id)
        expect(subject.bid_orders[2]['user_id']).to eq(oscar.id)
      end
    end
  end

  describe '#reset_limit_orders' do
    before do
      add_limit_order(andres, 'ask', Time.new(2018, 10, 5))
      add_limit_order(fdom, 'ask', Time.new(2018, 10, 3))
      add_limit_order(oscar, 'ask', Time.new(2018, 10, 4))
      subject.reset_limit_orders
    end

    it { expect(subject.orders.size).to eq(0) }
  end

  describe '#execute_transaction' do
    before do
      karmanager.set_karma(fdom.id, 100)
      karmanager.set_karma(andres.id, 100)
    end

    context 'with only one ask order' do
      it "doesn't execute the transaction" do
        add_limit_order(andres, 'ask', Time.new(2018, 10, 5))
        subject.execute_transaction
        expect(subject.ask_orders.size).to eq(1)
      end
    end

    context 'with ask and bid orders at the same price' do
      before do
        setup_lunchers
        add_limit_order(andres, 'ask', Time.new(2018, 10, 5))
        add_limit_order(fdom, 'bid', Time.new(2018, 10, 3))
      end

      it 'removes orders' do
        subject.execute_transaction
        expect(subject.ask_orders.size).to eq(0)
        expect(subject.bid_orders.size).to eq(0)
      end

      it 'transfers karma from buyer to asker' do
        original_karma_fdom = karmanager.get_karma(fdom.id)
        original_karma_andres = karmanager.get_karma(andres.id)
        subject.execute_transaction
        expect(karmanager.get_karma(fdom.id)).to eq(original_karma_fdom - 1)
        expect(karmanager.get_karma(andres.id)).to eq(original_karma_andres + 1)
      end

      it 'adds buyer to winning lunchers and remove seller' do
        subject.execute_transaction
        expect(lunch_assigner.winning_lunchers_list).to include(fdom.mention_name)
        expect(lunch_assigner.winning_lunchers_list).not_to include(andres.mention_name)
      end

      it 'uploads transaction' do
        subject.execute_transaction
        expect(sh_manager).to have_received(:insert_new_row).with([
          Time.now.strftime('%Y-%m-%d'),
          fdom.name,
          fdom.id,
          andres.name,
          andres.id,
          1
        ])
      end
    end

    context 'with more than two orders of the same type at the same price' do
      before do
        add_limit_order(andres, 'ask', Time.new(2018, 10, 1))
        add_limit_order(oscar, 'ask', Time.new(2018, 10, 5))
        add_limit_order(fdom, 'bid', Time.new(2018, 10, 3))
        setup_lunchers
      end

      it 'matches the older orders' do
        orders = subject.execute_transaction
        expect(orders['ask_order']['user_id']).to eq(andres.id)
        expect(orders['bid_order']['user_id']).to eq(fdom.id)
      end

      it 'remove the matched orders' do
        subject.execute_transaction
        expect(subject.ask_orders.size).to eq(1)
        expect(subject.bid_orders.size).to eq(0)
      end

      it 'transfers karma from buyer to asker' do
        original_karma_fdom = karmanager.get_karma(fdom.id)
        original_karma_andres = karmanager.get_karma(andres.id)
        subject.execute_transaction
        expect(karmanager.get_karma(fdom.id)).to eq(original_karma_fdom - 1)
        expect(karmanager.get_karma(andres.id)).to eq(original_karma_andres + 1)
      end
    end

    context 'with ask and bid order with prices higher than 1' do
      let(:first_tx_time) { Time.new(2018, 10, 4) }

      before do
        add_limit_order(oscar, 'bid', first_tx_time + 2.days, 1)
        add_limit_order(fernanda, 'bid', first_tx_time + 3.days, 1)
        add_limit_order(andres, 'ask', first_tx_time, ask_price)
        add_limit_order(fdom, 'bid', first_tx_time + 1.day, bid_price)
        setup_lunchers
      end

      context 'with ask price greater than bid price' do
        let(:ask_price) { 3 }
        let(:bid_price) { 2 }

        it 'does not execute a tx' do
          size_before_execution = subject.ask_orders.size
          subject.execute_transaction
          expect(subject.ask_orders.size).to eq(size_before_execution)
        end

        it 'does not transfer karma from buyer to seller' do
          original_karma_fdom = karmanager.get_karma(fdom.id)
          original_karma_andres = karmanager.get_karma(andres.id)
          subject.execute_transaction
          expect(karmanager.get_karma(fdom.id)).to eq(original_karma_fdom)
          expect(karmanager.get_karma(andres.id)).to eq(original_karma_andres)
        end
      end

      context 'with bid price grater than ask price' do
        let(:ask_price) { 2 }
        let(:bid_price) { 3 }

        it 'executes a tx at ask price' do
          tx = subject.execute_transaction
          expect(subject.ask_orders.size).to eq(0)
          expect(tx['price']).to eq(ask_price)
        end

        it 'transfers karma from buyer to seller' do
          original_karma_fdom = karmanager.get_karma(fdom.id)
          original_karma_andres = karmanager.get_karma(andres.id)
          subject.execute_transaction
          expect(karmanager.get_karma(fdom.id)).to eq(original_karma_fdom - ask_price)
          expect(karmanager.get_karma(andres.id)).to eq(original_karma_andres + ask_price)
        end
      end

      context 'with bid price equal to ask price' do
        let(:ask_price) { 3 }
        let(:bid_price) { 3 }

        it 'executes the tx at ask price' do
          tx = subject.execute_transaction
          expect(subject.ask_orders.size).to eq(0)
          expect(tx['price']).to eq(ask_price)
        end

        it 'transfers karma from buyer to seller' do
          original_karma_fdom = karmanager.get_karma(fdom.id)
          original_karma_andres = karmanager.get_karma(andres.id)
          subject.execute_transaction
          expect(karmanager.get_karma(fdom.id)).to eq(original_karma_fdom - ask_price)
          expect(karmanager.get_karma(andres.id)).to eq(original_karma_andres + ask_price)
        end
      end

      context 'with two equal ask orders but added at different time' do
        let(:ask_price) { 3 }
        let(:bid_price) { 3 }
        let(:other_user_1) { Lita::User.create(201, mention_name: 'pepito') }
        let(:other_user_2) { Lita::User.create(202, mention_name: 'pepito2') }
        let!(:other_orders) do
          [
            add_limit_order(other_user_1, 'ask', first_tx_time - 1.day, ask_price),
            add_limit_order(other_user_2, 'ask', first_tx_time + 1.day, ask_price)
          ]
        end
        let(:older_order) { other_orders.first }

        it 'executes the tx at ask price and with the oldest order' do
          original_ask_orders_size = subject.ask_orders.size
          tx = subject.execute_transaction
          expect(subject.ask_orders.size).to eq(original_ask_orders_size - 1)
          expect(tx['price']).to eq(ask_price)
          expect(tx['ask_order']['id']).to eq(older_order[:id])
        end

        it 'second execution matches the second oldest order' do
          subject.execute_transaction
          add_limit_order(other_user_1, 'bid', first_tx_time + 4.days, ask_price)
          tx = subject.execute_transaction
          expect(tx['ask_order']['user_id']).to eq(andres.id)
        end
      end
    end
  end

  describe '#transaction_possible?' do
    context 'transaction possible' do
      it 'returns true' do
        add_limit_order(oscar, 'ask', Time.new(2018, 10, 5))
        add_limit_order(fdom, 'bid', Time.new(2018, 10, 3))
        expect(subject.transaction_possible?).to be(true)
      end
    end

    context 'transaction not possible' do
      it 'returns false' do
        add_limit_order(oscar, 'ask', Time.new(2018, 10, 5))
        expect(subject.transaction_possible?).to be(false)
      end
    end
  end
end
