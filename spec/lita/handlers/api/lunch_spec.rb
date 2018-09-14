require 'spec_helper'

describe Lita::Handlers::Api::Lunch, lita_handler: true do
  let(:redis) { Lita::Handlers::LunchReminder.new(robot).redis }
  let(:karmanager) do
    Lita::Services::Karmanager.new(redis)
  end
  let(:assigner) { Lita::Services::LunchAssigner.new(redis, karmanager) }
  let(:juan) { Lita::User.create(127, mention_name: 'juan') }
  let(:pedro) { Lita::User.create(137, mention_name: 'pedro') }
  let(:oscar) { Lita::User.create(157, mention_name: 'oscar') }

  it { is_expected.to route_http(:get, 'winning_lunchers') }
  it { is_expected.to route_http(:get, 'current_lunchers') }
  it { is_expected.to route_http(:post, 'current_lunchers') }

  before do
    ENV['MAX_LUNCHERS'] = '20'
    assigner.add_to_lunchers('juan')
    assigner.add_to_lunchers('pedro')
    assigner.add_to_lunchers('oscar')
    karmanager.set_karma(juan.id, 10)
    karmanager.set_karma(pedro.id, 20)
    assigner.add_to_current_lunchers(juan.mention_name)
    assigner.add_to_current_lunchers(pedro.mention_name)
    assigner.add_to_winning_lunchers(pedro.mention_name)
  end

  describe '#winning_lunchers' do
    context 'not authorized' do
      it 'responds with not autorized' do
        response = JSON.parse(http.get('winning_lunchers').body)
        expect(response['status']).to eq(401)
        expect(response['message']).to eq('Not authorized')
      end
    end

    context 'authorized' do
      before do
        allow_any_instance_of(Rack::Request).to receive(:params).and_return(user_id: juan.id)
        @response = JSON.parse(http.get('winning_lunchers').body)
      end

      it 'includes the winning lunchers' do
        expect(@response['winning_lunchers']).to include('pedro')
      end

      it 'doesnt include non winning lunchers' do
        expect(@response['winning_lunchers']).not_to include('juan')
      end
    end
  end

  describe '#current_lunchers' do
    context 'not authorized' do
      it 'responds with not autorized' do
        response = JSON.parse(http.get('winning_lunchers').body)
        expect(response['status']).to eq(401)
        expect(response['message']).to eq('Not authorized')
      end
    end

    context 'authorized' do
      before do
        allow_any_instance_of(Rack::Request).to receive(:params).and_return(user_id: juan.id)
        @response = JSON.parse(http.get('current_lunchers').body)
      end

      it 'includes the current lunchers' do
        expect(@response['current_lunchers']).to include('juan', 'pedro')
      end

      it 'not includes other lunchers' do
        expect(@response['current_lunchers']).not_to include('oscar')
      end
    end
  end

  describe '#opt_in' do
    context 'not authorized' do
      it 'responds with not autorized' do
        response = JSON.parse(http.post('current_lunchers').body)
        expect(response['status']).to eq(401)
        expect(response['message']).to eq('Not authorized')
      end
    end

    context 'authorized' do
      before do
        allow_any_instance_of(Rack::Request).to receive(:params).and_return(user_id: oscar.id)
        @response = JSON.parse(http.post('current_lunchers').body)
      end

      it 'responds with success' do
        expect(@response['success']).to be(true)
      end

      it 'adds user to current lunchers' do
        current_lunchers = assigner.current_lunchers_list
        expect(current_lunchers).to include(oscar.mention_name)
      end
    end
  end
end
