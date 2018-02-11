require "spec_helper"
require 'pry'
require 'dotenv/load'

describe Lita::Services::Karmanager, lita: true do
  let(:robot) { Lita::Robot.new(registry) }
  let(:subject) { described_class.new(Lita::Handlers::LunchReminder.new(robot).redis) }

  it "retrieves karma =0 if not set" do
    expect(subject.get_karma("agustin")).to eq(0)
  end

  it "sets and retrieves karma" do
    subject.set_karma("agustin", 1000)
    expect(subject.get_karma("agustin")).to eq(1000)
  end

  it "transfers karma" do
    subject.set_karma("agustin", 1000)
    subject.set_karma("peter", 1000)
    subject.transfer_karma("agustin", "peter")
    expect(subject.get_karma("agustin")).to eq(999)
  end

  it "adds base karma to everyone on a list" do
    subject.set_karma("agustin", 1)
    subject.add_base_karma(["agustin", "peter", "john"], 100)
    expect(subject.get_karma("agustin")).to eq(101)
  end
end
