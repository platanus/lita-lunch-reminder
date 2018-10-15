require 'spec_helper'
require 'pry'
require 'dotenv/load'

describe Lita::Services::LunchAssigner, lita: true do
  let(:robot) { Lita::Robot.new(registry) }
  let(:karmanager) do
    Lita::Services::Karmanager.new(Lita::Handlers::LunchReminder.new(robot).redis)
  end
  let(:subject) { described_class.new(Lita::Handlers::LunchReminder.new(robot).redis, karmanager) }
  let(:armando) { Lita::User.create(124, mention_name: 'armando') }
  let(:alfredo) { Lita::User.create(125, mention_name: 'alfredo') }
  let(:pedro) { Lita::User.create(126, mention_name: 'pedro') }
  let(:juan) { Lita::User.create(127, mention_name: 'juan') }

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

  it 'create a hash that handles negative karma' do
    subject.add_to_lunchers('juan')
    karmanager.set_karma(juan.id, 10)
    subject.add_to_lunchers('pedro')
    karmanager.set_karma(pedro.id, -10)
    lkh = karmanager.karma_hash(subject.lunchers_list)
    expect(lkh['juan']).to eq(20)
    expect(lkh['pedro']).to eq(1) # 0 karma is 1
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
      karmanager.set_karma(pedro.id, 0)
      subject.add_to_lunchers('juan')
      karmanager.set_karma(juan.id, -100)
      subject.add_to_current_lunchers('pedro')
      subject.add_to_current_lunchers('juan')
      subject.pick_winners(1)
      expect(subject.winning_lunchers_list).to eq(['pedro'])
      expect(karmanager.get_karma(pedro.id)).to eq(-1)
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
end
