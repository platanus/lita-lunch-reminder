require 'spec_helper'

describe Lita::Handlers::Api::Market, lita_handler: true do
  let(:redis) { Lita::Handlers::LunchReminder.new(robot).redis }
  let(:karmanager) do
    Lita::Services::Karmanager.new(redis)
  end
  let(:assigner) { Lita::Services::LunchAssigner.new(redis, karmanager) }
  let(:market) { Lita::Services::LunchAssigner.new(redis, assigner, karmanager) }
  let(:juan) { Lita::User.create(127, mention_name: 'juan') }
  let(:pedro) { Lita::User.create(137, mention_name: 'pedro') }
  let(:oscar) { Lita::User.create(157, mention_name: 'oscar') }

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
  it { is_expected.to route_http(:post, 'market/limit_orders') }
  it { is_expected.to route_http(:post, 'market/market_orders') }

  before do
    ENV['MAX_LUNCHERS'] = '20'
    assigner.add_to_lunchers('juan')
    assigner.add_to_lunchers('pedro')
    assigner.add_to_lunchers('oscar')
    karmanager.set_karma(juan.id, 10)
    karmanager.set_karma(pedro.id, 20)
    karmanager.set_karma(oscar.id, 20)
    assigner.add_to_current_lunchers(juan.mention_name)
    assigner.add_to_current_lunchers(pedro.mention_name)
    assigner.add_to_winning_lunchers(pedro.mention_name)
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
      before do
        allow_any_instance_of(Rack::Request).to receive(:params).and_return(user_id: pedro.id)
        add_limit_order(SecureRandom.uuid, pedro, 'sell', Time.now)
        @response = JSON.parse(http.get('market/limit_orders').body)
      end

      it 'includes the limit orders' do
        expect(@response['limit_orders']).to contain_exactly('pedro')
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
      context 'user didn\'t won lunch' do
        before do
          id = SecureRandom.uuid
          time = Time.now
          allow_any_instance_of(Rack::Request).to receive(:params).and_return(user_id: juan.id)
          @response = JSON.parse(http.post do |req|
            req.url 'market/limit_orders'
            req.body = "{
              \"id\": \"#{SecureRandom.uuid}\",
              \"user_id\": #{juan.id},
              \"type\": \"sell\",
              \"created_at\": #{time}
            }"
          end.body)
        end

        it { expect(@response['status']).to eq(404) }
        it { expect(@response['message']).to eq('User didn\'t won lunch') }

        it 'should not add order to limits orders' do
          limit_orders = market.orders
          expect(limit_orders.size).to eq(0)
        end
      end

      context 'user won lunch' do
        before do
          allow_any_instance_of(Rack::Request).to receive(:params).and_return(user_id: pedro.id)
          id = SecureRandom.uuid
          time = Time.now
          @response = JSON.parse(http.post do |req|
            req.url 'market/place_limit_order'
            req.body = "{
              id: #{SecureRandom.uuid},
              user_id: #{pedro.id},
              type: sell,
              created_at: #{time}
            }"
          end.body)
        end

        it { expect(@response['success']).to be(true) }

        it 'should place limit order' do
          limit_orders = market.orders
          expect(limit_orders.size).to eq(1)
        end

        # Verificar datos de la limit order
      end
    end
  end

  describe 'POST market order' do
    context 'no limit orders' do
      before do
        allow_any_instance_of(Rack::Request).to receive(:params).and_return(user_id: juan.id)
        @response = JSON.parse(http.post do |req|
          req.url 'market/place_market_order'
          req.body = "{\"sender_id\": \"#{juan.id}\"}"
        end.body)
      end
    end

    context 'one or more limit orders' do
      before do
        add_limit_order(SecureRandom.uuid, pedro, 'sell', Time.now)
        allow_any_instance_of(Rack::Request).to receive(:params).and_return(user_id: juan.id)
        @response = JSON.parse(http.post do |req|
          req.url 'market/place_market_order'
          req.body = "{\"sender_id\": \"#{juan.id}\"}"
        end.body)
      end

      # Terminar test: Verificar transaccion. Que no pueda comprar almuerzo si ya tiene.
    end
  end
end
