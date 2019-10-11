require 'spec_helper'

describe Lita::Handlers::Api::Market, lita_handler: true do
  let(:karmanager) { double }
  let(:assigner) { double }
  let(:market) { double }
  let(:user) { double }
  let(:order_id) { SecureRandom.uuid }
  let(:time) { Time.now }
  let(:winning_list) { [user] }
  let(:ask_order) { { id: order_id, user_id: 127, type: 'ask', created_at: time } }
  let(:bid_order) { { id: order_id, user_id: 127, type: 'bid', created_at: time } }

  it { is_expected.to route_http(:get, 'market/limit_orders') }
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

  describe 'POST limit order' do
    context 'not authorized' do
      it 'responds with not autorized' do
        response = JSON.parse(http.post('market/limit_orders').body)
        expect(response['status']).to eq(401)
        expect(response['message']).to eq('Not authorized')
      end
    end

    context 'authorized' do
      context 'incorrect order' do
        before do
          allow_any_instance_of(Lita::Handlers::Api::Market).to \
            receive(:authorized?).and_return(true)
          allow(winning_list).to receive(:include?).and_return(false)
        end

        it 'responds with error' do
          response = JSON.parse(http.post do |res|
            res.url 'market/limit_orders'
            res.params['type'] = 'ask'
            res.body = ask_order.to_json
          end.body)
          expect(response['status']).to eq(403)
          expect(response['message']).to eq('Can not place order')
        end
      end

      context 'correct order' do
        before do
          allow_any_instance_of(Lita::Handlers::Api::Market).to \
            receive(:authorized?).and_return(true)
          allow(winning_list).to receive(:include?).and_return(true)
        end

        context 'no transaction possible' do
          before do
            allow_any_instance_of(Rack::Request).to receive(:params).and_return(type: 'ask')
            allow(market).to \
              receive(:execute_transaction).and_return(nil)
          end

          it 'responds with success' do
            response = JSON.parse(http.post do |res|
              res.url 'market/limit_orders'
              res.params['type'] = 'ask'
              res.body = ask_order.to_json
            end.body)
            expect(response['success']).to be(true)
          end

          it 'responds with an order' do
            response = JSON.parse(http.post do |res|
              res.url 'market/limit_orders'
              res.params['type'] = 'ask'
              res.body = ask_order.to_json
            end.body)
            expect(response['order']).not_to be_nil
          end

          it 'calls MarketManager#add_limit_order' do
            http.post do |res|
              res.url 'market/limit_orders'
              res.params['type'] = 'ask'
              res.body = ask_order.to_json
            end
            expect(market).to have_received(:add_limit_order).with(user: user, type: 'ask')
          end

          it "doesn't responds with executed_orders" do
            response = JSON.parse(http.post do |res|
              res.url 'market/limit_orders'
              res.params['type'] = 'ask'
              res.body = ask_order.to_json
            end.body)
            expect(response['executed_orders']).to be_nil
          end
        end

        context 'transaction possible' do
          before do
            allow_any_instance_of(Rack::Request).to receive(:params).and_return(type: 'ask')
            allow(market).to \
              receive(:execute_transaction).and_return('ask': ask_order, 'bid': bid_order)
          end

          it 'responds with success' do
            response = JSON.parse(http.post do |res|
              res.url 'market/limit_orders'
              res.params['type'] = 'ask'
              res.body = ask_order.to_json
            end.body)
            expect(response['success']).to be(true)
          end

          it "doesn't responds with an order" do
            response = JSON.parse(http.post do |res|
              res.url 'market/limit_orders'
              res.params['type'] = 'ask'
              res.body = ask_order.to_json
            end.body)
            expect(response['order']).to be_nil
          end

          it 'responds with executed_orders' do
            response = JSON.parse(http.post do |res|
              res.url 'market/limit_orders'
              res.params['type'] = 'ask'
              res.body = ask_order.to_json
            end.body)
            executed_orders = JSON.parse(response['executed_orders'])
            expect(executed_orders.to_json).to eq({ 'ask': ask_order, 'bid': bid_order }.to_json)
          end
        end
      end
    end
  end
end
