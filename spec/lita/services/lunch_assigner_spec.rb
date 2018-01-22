require "spec_helper"
require 'pry'
require 'dotenv/load'

describe Lita::Services::LunchAssigner, lita: true do
  let(:robot) { Lita::Robot.new(registry) }
  let(:subject) { described_class.new(Lita::Handlers::LunchReminder.new(robot).redis) }

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

  it "retrieves karma =0 if not set" do
    expect(subject.get_karma("agustin")).to eq(0)
  end

  it "sets and retrieves karma" do
    subject.set_karma("agustin", 1000)
    expect(subject.get_karma("agustin")).to eq(1000)
  end

  it "create a hash that handles negative karma" do
    subject.add_to_lunchers("alfred")
    subject.set_karma("alfred", 10)
    subject.add_to_lunchers("peter")
    subject.set_karma("peter", -10)
    lkh = subject.karma_hash(subject.lunchers_list)
    expect(lkh["alfred"]).to eq(20)
    expect(lkh["peter"]).to eq(1) # 0 karma is 1
  end

  it "allows for a single no karma man to win" do
    subject.set_karma("alfred", 0)
    subject.add_to_lunchers("alfred")
    subject.add_to_current_lunchers("alfred")
    subject.pick_winners(1)
    expect(subject.winning_lunchers_list).to eq(['alfred'])
  end

  it "considerates karma for shuffle and decreases to winners" do
    subject.add_to_lunchers("alfred")
    subject.set_karma("alfred", 0)
    subject.add_to_lunchers("peter")
    subject.set_karma("peter", -100)
    subject.add_to_current_lunchers("alfred")
    subject.add_to_current_lunchers("peter")
    subject.pick_winners(1)
    expect(subject.winning_lunchers_list).to eq(['alfred'])
    expect(subject.get_karma("alfred")).to eq(-1)
  end

  it "interates until every spot has been asigned" do
    subject.add_to_current_lunchers("alfred")
    subject.set_karma("alfred", 0.1)
    subject.add_to_current_lunchers("peter")
    subject.set_karma("peter", 100)
    subject.add_to_current_lunchers("john")
    subject.set_karma("john", 1)
    subject.add_to_current_lunchers("john")
    subject.set_karma("john", 2)
    subject.add_to_current_lunchers("john")
    subject.set_karma("john", 6)
    subject.pick_winners(3)
    expect(subject.winning_lunchers_list).to include('peter')
    expect(subject.winning_lunchers_list.count).to eq(2)
  end
end
