require 'spec_helper'
require 'pry'
require 'dotenv/load'

describe Lita::Services::LunchAssigner, lita: true do
  let(:robot) { Lita::Robot.new(registry) }
  let(:redis) { Lita::Handlers::LunchReminder.new(robot).redis }
  let(:karmanager) { Lita::Services::Karmanager.new(redis) }
  let(:subject) { described_class.new(redis, karmanager) }
  let(:armando) { Lita::User.create(124, mention_name: 'armando') }
  let(:alfredo) { Lita::User.create(125, mention_name: 'alfredo') }
  let(:pedro) { Lita::User.create(126, mention_name: 'pedro') }
  let(:juan) { Lita::User.create(127, mention_name: 'juan') }
  let(:agustin) { Lita::User.create(128, mention_name: 'agustin') }
  let(:jaime) { Lita::User.create(129, mention_name: 'jaime') }

  before do
    ENV['MAX_LUNCHERS'] = '20'
  end

  it 'returns a list of current lunchers' do
    expect(subject.current_lunchers_list).to eq([])
  end

  describe '#add_to_lunchers' do
    it 'adds lunchers' do
      subject.add_to_lunchers('alfred')
      expect(subject.lunchers_list).to eq(['alfred'])
    end
  end

  describe '#remove_from_lunchers' do
    it 'removes lunchers' do
      subject.add_to_lunchers('alfred')
      expect(subject.lunchers_list).to eq(['alfred'])
      subject.remove_from_lunchers('alfred')
      expect(subject.lunchers_list).to eq([])
    end
  end

  describe '#transfer_lunch' do
    before do
      subject.add_to_lunchers('alfred')
      subject.add_to_lunchers('andres')
      subject.add_to_current_lunchers('alfred')
    end
    context 'seller user has lunch' do
      before do
        subject.add_to_winning_lunchers('alfred')
      end

      context "buyer user doesn't has lunch" do
        it 'transfer lunch' do
          subject.add_to_winning_lunchers('alfred')
          expect(subject.transfer_lunch('alfred', 'andres')).to be true
          expect(subject.winning_lunchers_list).to contain_exactly('andres')
        end
      end

      context 'buyer user already has lunch' do
        before do
          subject.add_to_winning_lunchers('andres')
        end

        it "doesn't transfer lunch" do
          expect(subject.transfer_lunch('alfred', 'andres')).to be false
          expect(subject.winning_lunchers_list).to include('alfred')
        end
      end
    end

    context "seller user doesn't lunch" do
      it 'transfer lunch' do
        expect(subject.transfer_lunch('alfred', 'andres')).to be false
        expect(subject.winning_lunchers_list).to be_empty
      end
    end
  end

  it "create a hash that handles negative karma" do
    subject.add_to_lunchers(alfredo.mention_name)
    subject.set_karma(alfredo.mention_name, 10)
    subject.add_to_lunchers(pedro.mention_name)
    subject.set_karma(pedro.mention_name, -10)
    lkh = subject.karma_hash(subject.lunchers_list)
    expect(lkh[alfredo.mention_name]).to eq(21)
    expect(lkh[pedro.mention_name]).to eq(1) # 0 karma is 1
  end

  it 'create a hash that handles negative karma' do
    subject.add_to_lunchers('juan')
    karmanager.set_karma(juan.id, 10)
    subject.add_to_lunchers('pedro')
    karmanager.set_karma(pedro.id, -10)
    lkh = karmanager.karma_hash(subject.lunchers_list)
    expect(lkh['juan']).to eq(20)
    expect(lkh['pedro']).to eq(1) # 0 karma is 1
  end

  it "considerates karma for shuffle and decreases to winners" do
    subject.add_to_lunchers(alfredo.mention_name)
    subject.set_karma(alfredo.mention_name, 100)
    subject.add_to_lunchers(pedro.mention_name)
    subject.set_karma(pedro.mention_name, 200)
    subject.add_to_current_lunchers(alfredo.mention_name)
    subject.add_to_current_lunchers(pedro.mention_name)
    subject.pick_winners(1)
    expect(subject.winning_lunchers_list).to eq([pedro.mention_name])
    expect(subject.get_karma(pedro.mention_name)).to eq(199)
    expect(subject.get_karma(alfredo.mention_name)).to eq(100)
  end

  it "interates until every spot has been asigned" do
    subject.add_to_current_lunchers(alfredo.mention_name)
    subject.set_karma(alfredo.mention_name, 1)
    subject.add_to_current_lunchers(pedro.mention_name)
    subject.set_karma(pedro.mention_name, 100)
    subject.add_to_current_lunchers(juan.mention_name)
    subject.set_karma(juan.mention_name, 1)
    subject.add_to_current_lunchers(juan.mention_name)
    subject.set_karma(juan.mention_name, 2)
    subject.add_to_current_lunchers(juan.mention_name)
    subject.set_karma(juan.mention_name, 6)
    subject.pick_winners(2)
    expect(subject.winning_lunchers_list).to include(pedro.mention_name)
    expect(subject.winning_lunchers_list).to include(juan.mention_name)
    expect(subject.winning_lunchers_list.count).to eq(2)
  end

  describe '#pick_winners' do
    it 'allows for a single no karma man to win' do
      Lita::User.create(127, mention_name: 'alfred')
      karmanager.set_karma(pedro.id, 0)
      subject.add_to_lunchers('alfred')
      subject.add_to_current_lunchers('alfred')
      subject.pick_winners(1)
      expect(subject.winning_lunchers_list).to eq(['alfred'])
    end

    it 'considers karma for shuffle and decreases to winners' do
      subject.add_to_lunchers('pedro')
      subject.add_to_current_lunchers('pedro')
      karmanager.set_karma(pedro.id, 100)
      subject.set_wager(pedro.mention_name, 30)
      20.times do |i|
        juan_i = Lita::User.create(200 + i, mention_name: "juan_#{i}")
        subject.add_to_lunchers(juan_i.mention_name)
        subject.add_to_current_lunchers(juan_i.mention_name)
        karmanager.set_karma(juan_i.id, 0)
        subject.set_wager(juan_i.mention_name, 1)
      end
      subject.pick_winners(1)
      expect(subject.winning_lunchers_list).to eq(['pedro'])
      expect(karmanager.get_karma(pedro.id)).to eq(70)
    end

    it 'interates until every spot has been asigned' do
      subject.add_to_current_lunchers('armando')
      karmanager.set_karma(armando.id, 0.1)
      subject.add_to_current_lunchers('pedro')
      karmanager.set_karma(pedro.id, 100)
      subject.add_to_current_lunchers('alfredo')
      karmanager.set_karma(alfredo.id, 1)
      subject.add_to_current_lunchers('juan')
      karmanager.set_karma(juan.id, 2)
      subject.pick_winners(3)
      expect(subject.winning_lunchers_list).to include('pedro')
      expect(subject.winning_lunchers_list.count).to eq(3)
    end
  end

  describe '#weekday_name_plus' do
    it 'knows the day of the week' do
      fake_today = Date.parse('2018-01-01')
      allow(Date).to receive(:today).and_return(fake_today)
      expect(subject.weekday_name_plus(0)).to eq('lunes')
    end
  end

  it "retrieves wager =1 if not set" do
    expect(subject.get_wager('agustin')).to eq(1)
  end

  describe 'set_wager' do
    context 'with enough karma points' do
      before do
        subject.set_karma(agustin.mention_name, 100)
        redis.del('agustin:wager')
      end

      it "sets and retrieves wager" do
        subject.set_wager("agustin", 50)
        expect(subject.get_wager("agustin")).to eq(50)
      end
    end

    context 'with not enough karma points' do
      before do
        subject.set_karma(agustin.mention_name, 1)
        redis.del('agustin:wager')
      end

      it "sets and retrieves wager" do
        subject.set_wager("agustin", 51)
        expect(subject.get_wager("agustin")).to eq(1)
      end
    end
  end

  describe 'karma_hash' do
    before do
      subject.add_to_lunchers(agustin.mention_name)
      subject.add_to_lunchers(jaime.mention_name)
      subject.set_karma(agustin.mention_name, 10)
      subject.set_karma(jaime.mention_name, 20)
      subject.set_wager(agustin.mention_name, 5)
      subject.set_wager(jaime.mention_name, 10)
    end

    it "get hash correctly" do
      expect(subject.wager_hash([jaime.mention_name, agustin.mention_name])).to(
        include(agustin.mention_name => 5, jaime.mention_name => 10)
      )
    end
  end

  describe 'reset_lunchers' do
    before do
      subject.add_to_lunchers('ignacio')
      subject.add_to_lunchers('agustin')
      subject.add_to_lunchers('jaime')
      subject.add_to_current_lunchers('ignacio')
      subject.add_to_current_lunchers('agustin')
      subject.add_to_current_lunchers('jaime')
      subject.add_to_winning_lunchers('ignacio')
      redis.set('already_assigned', true)
      subject.set_karma('jaime', -20)
      subject.set_wager('jaime', 10)
    end

    it 'erases the required variables' do
      subject.reset_lunchers

      expect(subject.winning_lunchers_list).to eq([])
      expect(subject.current_lunchers_list).to eq([])
      expect(subject.already_assigned?).to be false
      expect(subject.get_wager('someone')).to eq(1)
    end
  end

  describe 'winners lose wagered points' do
    before do
      subject.add_to_current_lunchers(jaime.mention_name)
      subject.set_karma(jaime.mention_name, 10)
      subject.set_wager(jaime.mention_name, 5)
      subject.pick_winners(1)
    end

    it { expect(subject.get_karma(jaime.mention_name)).to eq(5) }
  end
end
