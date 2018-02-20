require "spec_helper"
require 'pry'
require 'dotenv/load'

describe Lita::Services::LunchAssigner, lita: true do
  let(:robot) { Lita::Robot.new(registry) }
  let(:karmanager) do
    Lita::Services::Karmanager.new(Lita::Handlers::LunchReminder.new(robot).redis)
  end
  let(:subject) { described_class.new(Lita::Handlers::LunchReminder.new(robot).redis, karmanager) }

  it "returns a list of current lunchers" do
    expect(subject.current_lunchers_list).to eq([])
  end

  it "adds lunchers" do
    subject.add_to_lunchers("alfred")
    expect(subject.lunchers_list).to eq(["alfred"])
  end

  it "removes lunchers" do
    subject.add_to_lunchers("alfred")
    expect(subject.lunchers_list).to eq(["alfred"])
    subject.remove_from_lunchers("alfred")
    expect(subject.lunchers_list).to eq([])
  end

  it "create a hash that handles negative karma" do
    pedro = Lita::User.create(126, mention_name: "pedro")
    juan = Lita::User.create(127, mention_name: "juan")
    subject.add_to_lunchers("juan")
    karmanager.set_karma(juan.id, 10)
    subject.add_to_lunchers("pedro")
    karmanager.set_karma(pedro.id, -10)
    lkh = karmanager.karma_hash(subject.lunchers_list)
    expect(lkh["juan"]).to eq(20)
    expect(lkh["pedro"]).to eq(1) # 0 karma is 1
  end

  it "allows for a single no karma man to win" do
    pedro = Lita::User.create(126, mention_name: "pedro")
    Lita::User.create(127, mention_name: "alfred")
    karmanager.set_karma(pedro.id, 0)
    subject.add_to_lunchers("alfred")
    subject.add_to_current_lunchers("alfred")
    subject.pick_winners(1)
    expect(subject.winning_lunchers_list).to eq(['alfred'])
  end

  it "considers karma for shuffle and decreases to winners" do
    pedro = Lita::User.create(126, mention_name: "pedro")
    juan = Lita::User.create(127, mention_name: "juan")
    subject.add_to_lunchers("pedro")
    karmanager.set_karma(pedro.id, 0)
    subject.add_to_lunchers("juan")
    karmanager.set_karma(juan.id, -100)
    subject.add_to_current_lunchers("pedro")
    subject.add_to_current_lunchers("juan")
    subject.pick_winners(1)
    expect(subject.winning_lunchers_list).to eq(['pedro'])
    expect(karmanager.get_karma(pedro.id)).to eq(-1)
  end

  it "interates until every spot has been asigned" do
    armando = Lita::User.create(124, mention_name: "armando")
    alfredo = Lita::User.create(125, mention_name: "alfredo")
    pedro = Lita::User.create(126, mention_name: "pedro")
    juan = Lita::User.create(127, mention_name: "juan")
    subject.add_to_current_lunchers("armando")
    karmanager.set_karma(armando.id, 0.1)
    subject.add_to_current_lunchers("pedro")
    karmanager.set_karma(pedro.id, 100)
    subject.add_to_current_lunchers("alfredo")
    karmanager.set_karma(alfredo.id, 1)
    subject.add_to_current_lunchers("juan")
    karmanager.set_karma(juan.id, 2)
    subject.pick_winners(3)
    expect(subject.winning_lunchers_list).to include('pedro')
    expect(subject.winning_lunchers_list.count).to eq(2)
  end
end
