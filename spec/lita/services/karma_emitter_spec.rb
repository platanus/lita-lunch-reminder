require "spec_helper"
require 'pry'
require 'dotenv/load'

describe Lita::Services::KarmaEmitter, lita: true do
  let(:robot) { Lita::Robot.new(registry) }
  let(:lunch_reminder) { Lita::Handlers::LunchReminder.new(robot) }
  let(:karmanager) { Lita::Services::Karmanager.new(lunch_reminder.redis) }
  let(:subject) { described_class.new(lunch_reminder.redis, karmanager) }
  let(:ham) { Lita::User.create(126, mention_name: "ham") }
  let(:andres) { Lita::User.create(127, mention_name: "andres") }
  let(:cristobal) { Lita::User.create(128, mention_name: "cristobal") }
  let(:jaime) { Lita::User.create(129, mention_name: "jaime") }
  let(:ham_karma) { 1 }
  let(:andres_karma) { 2 }
  let(:cristobal_karma) { 10 }
  let(:jaime_karma) { 20 }
  let(:users) { [andres, cristobal, jaime] }

  before do
    karmanager.set_karma(ham.id, ham_karma)
    karmanager.set_karma(andres.id, andres_karma)
    karmanager.set_karma(cristobal.id, cristobal_karma)
    karmanager.set_karma(jaime.id, jaime_karma)
  end

  context 'with one user' do
    let(:users) { [andres] }

    before do
      karmanager.set_karma(andres.id, andres_karma)
    end

    context 'with ham having zero karma' do
      let(:ham_karma) { 0 }

      it 'does not transfer karma from ham to a user' do
        subject.emit(users)
        expect(karmanager.get_karma(ham.id)).to eq(0)
        expect(karmanager.get_karma(andres.id)).to eq(2)
      end

      it { expect(subject.emit(users)).to eq(0) }
    end

    context 'with ham having one karma' do
      let(:ham_karma) { 1 }

      it 'transfers one karma from ham to a user' do
        subject.emit(users)
        expect(karmanager.get_karma(ham.id)).to eq(0)
        expect(karmanager.get_karma(andres.id)).to eq(3)
      end

      it { expect(subject.emit(users)).to eq(1) }
    end

    context 'with ham having more than one karma' do
      let(:ham_karma) { 10 }

      it 'transfers one karma from ham to a user' do
        subject.emit(users)
        expect(karmanager.get_karma(ham.id)).to eq(0)
        expect(karmanager.get_karma(andres.id)).to eq(12)
      end

      it { expect(subject.emit(users)).to eq(10) }
    end
  end

  context 'with more than one user' do
    let(:users) { [andres, cristobal, jaime] }

    context 'with ham having less karma than the number of users' do
      let(:ham_karma) { 2 }
      let(:andres_karma) { 10 }
      let(:cristobal_karma) { 10 }
      let(:jaime_karma) { 10 }

      it 'does not transfer karma from ham to any user' do
        subject.emit(users)
        users_karma = users.map { |user| karmanager.get_karma(user.id) }
        expect(karmanager.get_karma(ham.id)).to eq(2)
        expect(users_karma.uniq).to eq([10])
      end

      it { expect(subject.emit(users)).to eq(0) }
    end

    context 'with ham having as karma a number divisible by the number of users' do
      let(:ham_karma) { 30 }
      let(:andres_karma) { 10 }
      let(:cristobal_karma) { 10 }
      let(:jaime_karma) { 10 }

      it 'does not transfer karma from ham to any user' do
        subject.emit(users)
        users_karma = users.map { |user| karmanager.get_karma(user.id) }
        expect(karmanager.get_karma(ham.id)).to eq(0)
        expect(users_karma.uniq).to eq([20])
      end

      it { expect(subject.emit(users)).to eq(30) }
    end

    context 'with ham having as karma a number not divisible by the number of users' do
      let(:ham_karma) { 32 }
      let(:andres_karma) { 10 }
      let(:cristobal_karma) { 10 }
      let(:jaime_karma) { 10 }

      it 'does not transfer karma from ham to any user' do
        subject.emit(users)
        users_karma = users.map { |user| karmanager.get_karma(user.id) }
        expect(karmanager.get_karma(ham.id)).to eq(2)
        expect(users_karma.uniq).to eq([20])
      end

      it { expect(subject.emit(users)).to eq(30) }
    end

    context 'with one user having the maximum karma' do
      let(:ham_karma) { 30 }
      let(:andres_karma) { 10 }
      let(:cristobal_karma) { 10 }
      let(:jaime_karma) { 50 }

      it 'does not transfer karma to user in limit' do
        subject.emit(users)
        expect(karmanager.get_karma(jaime.id)).to eq(50)
      end

      it 'transfers karma to users not in limit' do
        subject.emit(users)
        expect(karmanager.get_karma(andres.id)).to eq(25)
        expect(karmanager.get_karma(cristobal.id)).to eq(25)
      end

      it { expect(subject.emit(users)).to eq(30) }
    end

    context 'with one user such that if the karma is emitted to him, he will have more than the max' do
      let(:ham_karma) { 30 }
      let(:andres_karma) { 10 }
      let(:cristobal_karma) { 10 }
      let(:jaime_karma) { 48 }

      it 'emits only the remaining karma to reach the limit' do
        subject.emit(users)
        expect(karmanager.get_karma(jaime.id)).to eq(50)
      end

      it 'transfers the reminder to the other participants' do
        subject.emit(users)
        expect(karmanager.get_karma(andres.id)).to eq(24)
        expect(karmanager.get_karma(cristobal.id)).to eq(24)
      end

      it { expect(subject.emit(users)).to eq(30) }
    end
  end
end
