require 'spec_helper'

describe Lita::Handlers::Api::Market, lita_handler: true do
  let(:karmanager) { double }
  let(:assigner) { double }
  let(:market) { double }
  let(:user) { double }
  let(:order_id) { SecureRandom.uuid }
  let(:time) { Time.now }
  let(:limit_order) { { id: order_id, user_id: 127, type: 'ask', created_at: time } }
  let(:market_order) { { user_id: '127' } }
  let(:winning_list) { [user] }

  def add_limit_order(order_id, user, type, created_at)
    order = {
      id: order_id,
      user_id: user.id,
      type: type,
      created_at: created_at
    }.to_json
    market.add_limit_order(order)
    order
  end

  it { is_expected.to route_http(:get, 'market/limit_orders') }
  it { is_expected.to route_http(:get, 'market/execute_transaction') }
  it { is_expected.to route_http(:post, 'market/limit_orders') }

  before do
    ENV['MAX_LUNCHERS'] = '20'
    allow(assigner).to receive(:winning_lunchers_list).and_return('pedro')
    allow(user).to receive(:mention_name).and_return('pedro')
    allow(user).to receive(:id).and_return('127')
    allow(assigner).to receive(:winning_lunchers_list).and_return(true)
    allow_any_instance_of(Lita::Handlers::Api::Market).to receive(:assigner).and_return(assigner)
    allow_any_instance_of(Lita::Handlers::Api::Market).to receive(:current_user).and_return(user)
    allow_any_instance_of(Lita::Handlers::Api::Market)
      .to receive(:market_manager).and_return(market)
    allow_any_instance_of(Lita::Handlers::Api::Market)
      .to receive(:winning_list).and_return(winning_list)
    allow(market).to receive(:add_limit_order).and_return(true)
  end

  describe '#limit_orders' do
    context 'not authorized' do
      it 'responds with not autorized' do
        response = JSON.parse(http.get('market/limit_orders').body)
        expect(response['status']).to eq(401)
        expect(response['message']).to eq('Not authorized')
      end
    end

    context 'authorized' do
      let(:limit_order) { { id: order_id, user_id: 127, type: 'ask', created_at: time } }
      before do
        allow_any_instance_of(Lita::Handlers::Api::Market).to receive(:authorized?).and_return(true)
        allow_any_instance_of(Lita::Handlers::Api::Market)
          .to receive(:market_manager).and_return(market)
        allow(market).to receive(:orders).and_return([limit_order])
      end

      it 'includes the limit orders' do
        response = JSON.parse(http.get('market/limit_orders').body)
        expect(response['limit_orders'].first.to_json).to eq(limit_order.to_json)
      end
    end
  end

  describe '#execute_transaction' do
    context 'not authorized' do
      it 'responds with not autorized' do
        response = JSON.parse(http.get('market/execute_transaction').body)
        expect(response['status']).to eq(401)
        expect(response['message']).to eq('Not authorized')
      end
    end

    context 'authorized' do
      let(:ask_order) { { id: order_id, user_id: 127, type: 'ask', created_at: time } }
      let(:bid_order) { { id: order_id, user_id: 127, type: 'ask', created_at: time } }
      before do
        allow_any_instance_of(Lita::Handlers::Api::Market).to \
          receive(:authorized?).and_return(true)
        allow_any_instance_of(Lita::Handlers::Api::Market)
          .to receive(:market_manager).and_return(market)
        allow(market).to receive(:execute_transaction)
          .and_return('ask': ask_order, 'bid': bid_order)
      end

      it 'includes both orders' do
        response = JSON.parse(http.get('market/execute_transaction').body)
        expect(JSON.parse(response['orders'])['ask'].to_json).to eq(ask_order.to_json)
        expect(JSON.parse(response['orders'])['bid'].to_json).to eq(bid_order.to_json)
      end
    end
  end

  describe 'POST limit order' do
    context 'not authorized' do
      it 'responds with not autorized' do
        response = JSON.parse(http.post('market/limit_orders').body)
        expect(response['status']).to eq(401)
        expect(response['message']).to eq('Not authorized')
      end
    end

    context 'authorized' do
      before do
        allow_any_instance_of(Lita::Handlers::Api::Market).to receive(:authorized?).and_return(true)
        allow(winning_list).to receive(:include?).and_return(true)
      end

      it 'responds with success' do
        response = JSON.parse(http.post do |req|
          req.url 'market/limit_orders'
          req.body = limit_order.to_s
        end.body)
        expect(response['success']).to be(true)
      end

      it 'responds with an order' do
        response = JSON.parse(http.post do |req|
          req.url 'market/limit_orders'
          req.body = limit_order.to_s
        end.body)
        order = JSON.parse(response['order'])
        expect(order).not_to be_nil
        expect(order['id']).not_to be_nil
        expect(order['type']).to eq('ask')
        expect(order['created_at']).not_to be_nil
      end
    end
  end
end
