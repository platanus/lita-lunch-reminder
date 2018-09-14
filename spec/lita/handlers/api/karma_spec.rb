require 'spec_helper'

describe Lita::Handlers::Api::Karma, lita_handler: true do
  let(:redis) { Lita::Handlers::LunchReminder.new(robot).redis }
  let(:karmanager) do
    Lita::Services::Karmanager.new(redis)
  end
  let(:assigner) { Lita::Services::LunchAssigner.new(redis, karmanager) }
  let(:juan) { Lita::User.create(127, mention_name: 'juan') }
  let(:pedro) { Lita::User.create(137, mention_name: 'pedro') }

  it { is_expected.to route_http(:get, 'karma') }

  before do
    assigner.add_to_lunchers('juan')
    assigner.add_to_lunchers('pedro')
    karmanager.set_karma(juan.id, 10)
    karmanager.set_karma(pedro.id, 20)
  end

  describe '#karma' do
    context 'not authorized' do
      it 'responds with not autorized' do
        response = JSON.parse(http.get('karma').body)
        expect(response['status']).to eq(401)
        expect(response['message']).to eq('Not authorized')
      end
    end

    context 'authorized' do
      before do
        allow_any_instance_of(Rack::Request).to receive(:params).and_return(user_id: juan.id)
        @response = JSON.parse(http.get('karma').body)
      end

      it 'writes responds with user karma' do
        expect(@response['karma']).to eq(10)
      end
    end
  end

  describe '#transfer' do
    context 'not authorized' do
      it 'responds with not autorized' do
        response = JSON.parse(http.post('karma/transfer').body)
        expect(response['status']).to eq(401)
        expect(response['message']).to eq('Not authorized')
      end
    end

    context 'authorized' do
      before do
        allow_any_instance_of(Rack::Request).to receive(:params).and_return(user_id: juan.id)
        @juan_karma = karmanager.get_karma(juan.id)
        @pedro_karma = karmanager.get_karma(pedro.id)
        @response = JSON.parse(http.post do |req|
          req.url 'karma/transfer'
          req.body = "{\"receiver_id\": \"#{pedro.id}\", \"karma_amount\": 5 }"
        end.body)
      end

      it 'responds with success' do
        expect(@response['success']).to eq(true)
      end

      it 'transfers the karma' do
        expect(karmanager.get_karma(juan.id)).to eq(@juan_karma - 5)
        expect(karmanager.get_karma(pedro.id)).to eq(@pedro_karma + 5)
      end
    end
  end
end
