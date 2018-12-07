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
    subject.transfer_karma("agustin", "peter", 1)
    expect(subject.get_karma("agustin")).to eq(999)
  end

  it 'not transfers karma' do
    subject.set_karma("agustin", 1000)
    subject.set_karma("peter", 1000)
    subject.decrease_karma_by("agustin", 9)
    subject.transfer_karma("agustin", "peter", 1)
    expect(subject.get_karma("agustin")).to eq(991)
    expect(subject.get_karma("peter")).to eq(1000)
  end

  it "adds base karma to everyone on a list" do
    Lita::User.create(126, mention_name: "john")
    Lita::User.create(127, mention_name: "peter")
    agustin = Lita::User.create(129, mention_name: "agustin")
    subject.set_karma("agustin", 1) # this line sets old-mention_name-based-karma
    subject.convert_to_new_karma(["agustin", "peter", "john"], 100)
    expect(subject.get_karma(agustin.id)).to eq(101)
  end

  it "calculates average karma" do
    john = Lita::User.create(126, mention_name: "john")
    peter = Lita::User.create(127, mention_name: "peter")
    agustin = Lita::User.create(129, mention_name: "agustin")
    subject.set_karma(john.id, 300)
    subject.set_karma(peter.id, 0)
    subject.set_karma(agustin.id, 0)
    expect(subject.average_karma(["john", "peter", "agustin"])).to eq(100)
  end

  it "raises exception" do
    john = Lita::User.create(126, mention_name: "john")
    subject.set_karma(john.id, 300)
    expect do
      subject.average_karma(["john", "peter", "agustin"])
    end.to raise_exception("Can't find mention name 'peter'")
  end

  describe '#reset_daily_transfers' do
    it 'resets the daily transfer counter' do
      john = Lita::User.create(126, mention_name: "john")
      peter = Lita::User.create(127, mention_name: "peter")
      subject.set_karma(john.id, 1000)
      subject.set_karma(peter.id, 1000)
      subject.transfer_karma(peter.id, john.id, 3)
      expect(subject.daily_karma_transfered(peter.id)).to eq 3
      subject.reset_daily_transfers([john.id, peter.id])
      expect(subject.daily_karma_transfered(peter.id)).to eq 0
    end
  end

  describe "#can_transfer?" do
    let(:john) { Lita::User.create(126, mention_name: "john") }
    let(:amount) { 10 }
    let(:karma) { 10 }

    before do
      subject.set_karma(john.id, karma)
    end

    context 'with less karma than amount' do
      let(:amount) { 20 }

      it { expect(subject.can_transfer?(john.id, amount)).to eq false }
    end

    context 'with more karma than amount and limit reached' do
      let(:amount) { 5 }

      before do
        subject.decrease_karma_by(john.id, 9)
      end

      it { expect(subject.can_transfer?(john.id, amount)).to eq false }
    end

    context 'amount more than max daily limit' do
      let(:amount) { 5 }

      before do
        subject.decrease_karma_by(john.id, 3)
      end

      it { expect(subject.can_transfer?(john.id, amount)).to eq false }
    end

    context 'with all the correct parameters' do
      let(:amount) { 5 }

      it { expect(subject.can_transfer?(john.id, amount)).to eq true }
    end
  end
end
