require "spec_helper"
require 'pry'
require 'dotenv/load'

describe Lita::Services::WeightedPicker do
  def init_subject(karma_hash)
    described_class.new(karma_hash)
  end

  describe '#sample' do
    context 'with no participants' do
      let(:karma_hash) { {} }
      let(:subject) { init_subject(karma_hash) }

      it 'returns nil' do
        expect(subject.sample).to be_nil
      end
    end

    context 'with one participant' do
      let(:karma_hash) { { 'ham' => 10 } }
      let(:subject) { init_subject(karma_hash) }

      it 'picks the participant, and then returns nil' do
        expect(subject.sample).to eq('ham')
        expect(subject.sample).to eq(nil)
        expect(subject.sample).to eq(nil)
      end
    end

    context 'with multiple participants' do
      let(:karma_hash) { { 'ham' => 10, 'agustin' => 1 } }
      let(:subject) { init_subject(karma_hash) }
      let(:current_lunchers) { ['ham', 'agustin'] }

      it 'picks both lunchers then nil' do
        expect(current_lunchers).to include(subject.sample)
        expect(current_lunchers).to include(subject.sample)
        expect(subject.sample).to eq(nil)
        expect(subject.sample).to eq(nil)
      end
    end

    context 'with non positive karma' do
      let(:karma_hash) { { 'agustin' => 1 } }
      let(:subject) { init_subject(karma_hash) }

      it 'raises NonPositiveKarmaError with 0 karma' do
        karma_hash['jaime'] = 0
        expect { init_subject(karma_hash) }.to raise_error(Lita::Services::NonPositiveKarmaError)
      end

      it 'raises NonPositiveKarmaError with negative karma' do
        karma_hash['giovanni'] = -10
        expect { init_subject(karma_hash) }.to raise_error(Lita::Services::NonPositiveKarmaError)
      end
    end
  end
end
