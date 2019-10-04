require 'spec_helper'
require 'dotenv/load'

describe Lita::Handlers::LunchReminder, lita_handler: true do
  before do
    ENV['MAX_LUNCHERS'] = '3'
    ENV['WAIT_RESPONSES_SECONDS'] = '0 0 * * *'
    ENV['ASK_CRON'] = '0 0 * * *'
    ENV['PERSIST_CRON'] = '0 0 * * *'
    ENV['COUNTS_CRON'] = '00 04 1 * *'
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

  describe 'transfer karma' do
    context 'can transfer' do
      before do
        allow_any_instance_of(Lita::Services::Karmanager).to(
          receive(:transfer_karma).and_return(true)
        )
      end

      it 'transfers karma' do
        armando = Lita::User.create(124, mention_name: 'armando')
        jilberto = Lita::User.create(125, mention_name: 'jilberto')
        send_message('@lita transfierele karma a armando', as: jilberto)
        expect(replies.last).to match('@jilberto, le ha dado un punto de karma a @armando.')
      end
    end

    context 'can not transfer' do
      before do
        allow_any_instance_of(Lita::Services::Karmanager).to(
          receive(:transfer_karma).and_return(false)
        )
      end

      it 'not transfer karma' do
        armando = Lita::User.create(124, mention_name: 'armando')
        jilberto = Lita::User.create(125, mention_name: 'jilberto')
        send_message('@lita transfierele karma a armando', as: jilberto)
        expect(replies.last).to match('@jilberto, no se pudo transferir el karma')
      end
    end
  end

  describe 'sell lunch' do
    context 'user has lunch' do
      before do
        allow_any_instance_of(Lita::Services::LunchAssigner).to\
          receive(:winning_lunchers_list).and_return(['armando'])
      end
      context 'no bid orders placed' do
        before do
          allow_any_instance_of(Lita::Services::MarketManager).to\
            receive(:add_limit_order).and_return(true)
        end
        it 'responds that limit order was placed' do
          armando = Lita::User.create(124, mention_name: 'armando')
          send_message('@lita vendo almuerzo', as: armando)
          expect(replies.last).to match('tengo tu almuerzo en venta a 1 karma/s!')
        end
      end

      context 'one or more bid orders placed' do
        let(:ask_order) { { 'id' => 1111, 'user_id' => 124, 'type' => 'ask' } }
        let(:bid_order) { { 'id' => 2222, 'user_id' => 123, 'type' => 'bid' } }
        let(:orders) do
          {
            'buyer' => user,
            'seller' => user2,
            'ask_order' => ask_order,
            'bid_order' => bid_order
          }
        end
        let(:lita_user) { Lita::User }
        let(:user) { Lita::User.create(123, mention_name: 'felipe.dominguez') }
        let(:user2) { Lita::User.create(124, mention_name: 'armando') }

        before do
          allow_any_instance_of(Lita::Services::MarketManager).to \
            receive(:execute_transaction).and_return(orders)
        end

        it 'responds with transaction' do
          armando = Lita::User.create(124, mention_name: 'armando')
          send_message('@lita vendo almuerzo', as: armando)
          expect(replies.last).to match('@felipe.dominguez le compró almuerzo a @armando')
        end
      end
    end

    context 'user without lunch' do
      before do
        allow_any_instance_of(Lita::Services::LunchAssigner).to\
          receive(:winning_lunchers_list).and_return([])
      end
      it 'responds with an error' do
        armando = Lita::User.create(124, mention_name: 'armando')
        send_message('@lita vende mi almuerzo', as: armando)
        expect(replies.last).to match('@armando no puedes vender algo que no tienes!')
      end
    end

    context 'with user selling at more than 1' do
      let(:market) { double }
      let(:executed_tx) { nil }
      let(:buyer) { Lita::User.create(124, mention_name: 'armando') }
      let(:seller) { Lita::User.create(121, mention_name: 'jorge') }

      before do
        allow(Lita::Services::MarketManager).to receive(:new).and_return(market)
        allow(market).to receive(:add_limit_order).and_return(true)
        allow_any_instance_of(Lita::Services::LunchAssigner).to \
          receive(:winning_lunchers_list).and_return(['jorge'])
        allow(market).to receive(:execute_transaction).and_return(executed_tx)
      end

      context 'with transaction not executed' do
        let(:executed_tx) { nil }

        it 'responds that limit order was placed' do
          send_message('@lita vendo almuerzo a 12 karmas', as: seller)
          expect(replies.last).to match('@jorge, tengo tu almuerzo en venta a 12 karma/s!')
        end
      end

      context 'with transaction executed' do
        let(:executed_tx) { { 'buyer' => buyer, 'seller' => seller } }

        it 'responds that tx was executed' do
          send_message('@lita vendo almuerzo a 12 karmas', as: seller)
          expect(replies.last).to match('@armando le compró almuerzo a @jorge a 12 karma/s')
        end
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
        expect(replies.last).to match('@armando no te puedo comprar almuerzo...')
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
          expect(replies.last).to match('voy a tratar de conseguirte almuerzo a 1 karma/s!')
        end
      end

      context 'one or more ask orders placed' do
        let(:ask_order) { { 'id' => 1111, 'user_id' => seller.id, 'type' => 'ask' } }
        let(:bid_order) { { 'id' => 2222, 'user_id' => buyer.id, 'type' => 'bid' } }
        let(:orders) do
          {
            'ask_order' => ask_order,
            'bid_order' => bid_order,
            'buyer' => buyer,
            'seller' => seller
          }
        end
        let(:lita_user) { Lita::User }
        let(:seller) { Lita::User.create(123, mention_name: 'felipe.dominguez') }
        let(:buyer) { Lita::User.create(124, mention_name: 'armando') }

        before do
          allow_any_instance_of(Lita::Services::MarketManager).to \
            receive(:execute_transaction).and_return(orders)
        end

        it 'responds with transaction' do
          send_message('@lita compro almuerzo', as: buyer)
          expect(replies.last).to match('@armando le compró almuerzo a @felipe.dominguez')
        end
      end
    end

    context 'with user buying at more than 1' do
      let(:market) { double }
      let(:executed_tx) { nil }
      let(:buyer) { Lita::User.create(124, mention_name: 'armando') }
      let(:seller) { Lita::User.create(121, mention_name: 'jorge') }

      before do
        allow(Lita::Services::MarketManager).to receive(:new).and_return(market)
        allow(market).to receive(:add_limit_order).and_return(true)
        allow(market).to receive(:winning_lunchers_list).and_return([])
        allow(market).to receive(:execute_transaction).and_return(executed_tx)
      end

      context 'with transaction not executed' do
        let(:executed_tx) { nil }

        it 'responds that limit order was placed' do
          send_message('@lita compro almuerzo a 12 karmas', as: buyer)
          expect(replies.last).to match('@armando, voy a tratar de conseguirte almuerzo a 12 karma/s!')
        end
      end

      context 'with transaction executed' do
        let(:executed_tx) { { 'buyer' => buyer, 'seller' => seller } }

        it 'responds that tx was executed' do
          send_message('@lita compro almuerzo a 12 karmas', as: buyer)
          expect(replies.last).to match('@armando le compró almuerzo a @jorge a 12 karma/s')
        end
      end
    end
  end

  it "assigns user wager" do
    armando = Lita::User.create(124, name: 'armando')
    expect_any_instance_of(Lita::Services::LunchAssigner).to receive(:set_wager)
      .with('armando', 5)
    send_message("@lita apuesto 5 puntos de karma", as: armando)
  end

  describe 'karma emission' do
    let!(:ham) { Lita::User.create(124, mention_name: 'ham') }
    let!(:andres) { Lita::User.create(125, mention_name: 'andres') }

    before do
      allow_any_instance_of(Lita::Services::KarmaEmitter).to(
        receive(:last_emission_date).and_return(last_emission_date)
      )
      allow_any_instance_of(Lita::Services::KarmaEmitter).to(
        receive(:emit).and_return(10)
      )
    end

    context 'emission not done in 30 days' do
      let(:last_emission_date) { Date.new }

      it 'does emit karma' do
        send_message('@lita reparte tu karma', as: andres)
        expect(replies.last).to(
          match('Repartí 10 karmas entre todos. Recuerda: el que guarda siempre tiene')
        )
      end
    end

    context 'emission done in less than 30 days' do
      let(:last_emission_date) { Date.today }

      it 'does not emit karma' do
        send_message('@lita reparte tu karma', as: andres)
        send_message('@lita reparte tu karma', as: andres)
        expect(replies.last).to(
          match('No pude repartir el karma. Faltan 30 días para que pueda emitir de nuevo')
        )
      end
    end
  end
end
