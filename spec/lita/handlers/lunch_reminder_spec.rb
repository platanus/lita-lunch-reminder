require 'spec_helper'
require 'dotenv/load'

describe Lita::Handlers::LunchReminder, lita_handler: true do
  before do
    ENV['MAX_LUNCHERS'] = '3'
    ENV['WAIT_RESPONSES_SECONDS'] = '0 0 * * *'
    ENV['ASK_CRON'] = '0 0 * * *'
    ENV['PERSIST_CRON'] = '0 0 * * *'
  end

  it 'responds to invite announcement' do
    usr = Lita::User.create(123, name: 'carlos')
    send_message('@lita tengo un invitado', as: usr)
    expect(replies.last).to eq('Perfecto @carlos, anoté a tu invitado como invitado_de_carlos.')
  end
  it 'responds to user' do
    usr = Lita::User.create(124, name: 'armando')
    send_message('@lita tengo un invitado', as: usr)
    expect(replies.last).to eq('Perfecto @armando, anoté a tu invitado como invitado_de_armando.')
  end
  it 'responds to user' do
    usr = Lita::User.create(124, name: 'armando')
    send_message('@lita tengo un invitado', as: usr)
    send_message('quienes almuerzan hoy?', as: usr)
    expect(replies.last).to match('no lo se')
  end
  it 'responds that invitee does not fit' do
    ['armando', 'luis', 'peter'].each do |name|
      usr = Lita::User.create(124, name: name)
      send_message('@lita tengo un invitado', as: usr)
    end
    expect(replies.last).to match('no cabe')
  end
  it 'does not allow a user to give his place before he has it' do
    usr = Lita::User.create(124, name: 'armando')
    send_message('@lita hoy almuerzo aquí', as: usr)
    send_message('@lita cédele mi puesto a patricio', as: usr)
    expect(replies.last).to match('algo que no tienes')
  end
  it 'answers the user karma' do
    usr = Lita::User.create(124, name: 'armando')
    send_message('@lita cuánto karma tengo?', as: usr)
    expect(replies.last).to match('Tienes 0 puntos de karma, mi padawan')
  end
  it 'answers with the user karma' do
    usr1 = Lita::User.create(124, name: 'armando')
    Lita::User.create(1292, mention_name: 'fernando')
    send_message('@lita cuánto karma tiene fernando?', as: usr1)
    expect(replies.last).to match('@fernando tiene 0 puntos de karma.')
  end
  it 'transfers karma' do
    armando = Lita::User.create(124, mention_name: 'armando')
    jilberto = Lita::User.create(125, mention_name: 'jilberto')
    send_message('@lita transfierele karma a armando', as: jilberto)
    send_message('@lita cuánto karma tengo?', as: jilberto)
    expect(replies.last).to match('Tienes -1 puntos de karma, mi padawan')
    send_message('@lita cuánto karma tengo?', as: armando)
    expect(replies.last).to match('Tienes 1 puntos de karma, mi padawan')
  end

  describe 'sell lunch' do
    context 'user has lunch' do
      context 'no ask orders placed' do
        before do
          allow_any_instance_of(Lita::Services::MarketManager).to\
            receive(:add_limit_order).and_return(true)
          allow_any_instance_of(Lita::Services::LunchAssigner).to\
            receive(:winning_lunchers_list).and_return(['armando'])
        end
        it 'responds that limit order was placed' do
          armando = Lita::User.create(124, mention_name: 'armando')
          send_message('@lita vendo almuerzo', as: armando)
          expect(replies.last).to match('tengo tu almuerzo en venta!')
        end
      end

      context 'one or more ask orders placed' do
        let(:ask_order) { { 'id': 1111, 'user_id': 123, 'type': 'ask' } }
        let(:bid_order) { { 'id': 2222, 'user_id': 124, 'type': 'bid' } }
        let(:orders) { { 'ask': ask_order, 'bid': bid_order } }

        let(:user) { double(mention_name: 'felipe.dominguez') }
        let(:lita_user) { Lita::User }
        let!(:user2) { Lita::User.create(124, mention_name: 'armando') }

        before do
          allow_any_instance_of(Lita::Services::MarketManager).to \
            receive(:execute_transaction).and_return(orders)
          allow(lita_user).to receive(:find_by_id).and_return(user)
          allow(lita_user).to receive(:create).and_return(user2)
        end

        it 'responds with transaction' do
          armando = Lita::User.create(124, mention_name: 'armando')
          send_message('@lita compro almuerzo', as: armando)
          expect(replies.last).to match('@armando le compró almuerzo a @felipe.dominguez')
        end
      end


      before do
        allow_any_instance_of(Lita::Services::MarketManager).to\
          receive(:add_limit_order).and_return(true)
        allow_any_instance_of(Lita::Services::LunchAssigner).to\
          receive(:winning_lunchers_list).and_return(['armando'])
      end
      it 'responds that limit order was placed' do
        armando = Lita::User.create(124, mention_name: 'armando')
        send_message('@lita vende mi almuerzo', as: armando)
        expect(replies.last).to match('tengo tu almuerzo en venta!')
      end
    end
    context 'user without lunch' do
      before do
        allow_any_instance_of(Lita::Services::MarketManager).to\
          receive(:add_limit_order).and_return(true)
        allow_any_instance_of(Lita::Services::LunchAssigner).to\
          receive(:winning_lunchers_list).and_return([])
      end
      it 'responds with an error' do
        armando = Lita::User.create(124, mention_name: 'armando')
        send_message('@lita vende mi almuerzo', as: armando)
        expect(replies.last).to match('@armando no puedes vender algo que no tienes!')
      end
    end
  end

  describe 'buy lunch' do
    context 'user has lunch' do
      before do
        allow_any_instance_of(Lita::Services::MarketManager).to\
          receive(:add_limit_order).and_return(false)
        allow_any_instance_of(Lita::Services::LunchAssigner).to\
          receive(:winning_lunchers_list).and_return(['armando'])
      end
      it 'responds with an error' do
        armando = Lita::User.create(124, mention_name: 'armando')
        send_message('@lita compro almuerzo', as: armando)
        expect(replies.last).to match('no te puedo comprar almuerzo...')
      end
    end

    context 'user without lunch' do
      context 'no ask orders placed' do
        before do
          allow_any_instance_of(Lita::Services::MarketManager).to\
            receive(:add_limit_order).and_return(true)
          allow_any_instance_of(Lita::Services::LunchAssigner).to\
            receive(:winning_lunchers_list).and_return([])
        end
        it 'responds that limit order was placed' do
          armando = Lita::User.create(124, mention_name: 'armando')
          send_message('@lita compro almuerzo', as: armando)
          expect(replies.last).to match('voy a tratar de conseguirte almuerzo!')
        end
      end

      context 'one or more ask orders placed' do
        let(:ask_order) { { 'id': 1111, 'user_id': 123, 'type': 'ask' } }
        let(:bid_order) { { 'id': 2222, 'user_id': 124, 'type': 'bid' } }
        let(:orders) { { 'ask': ask_order, 'bid': bid_order } }

        let(:user) { double(mention_name: 'felipe.dominguez') }
        let(:lita_user) { Lita::User }
        let!(:user2) { Lita::User.create(124, mention_name: 'armando') }

        before do
          allow_any_instance_of(Lita::Services::MarketManager).to \
            receive(:execute_transaction).and_return(orders)
          allow(lita_user).to receive(:find_by_id).and_return(user)
          allow(lita_user).to receive(:create).and_return(user2)
        end

        it 'responds with transaction' do
          armando = Lita::User.create(124, mention_name: 'armando')
          send_message('@lita compro almuerzo', as: armando)
          expect(replies.last).to match('@armando le compró almuerzo a @felipe.dominguez')
        end
      end
    end
  end
end
