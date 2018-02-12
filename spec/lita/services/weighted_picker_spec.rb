require "spec_helper"
require 'pry'
require 'dotenv/load'

describe Lita::Services::WeightedPicker do
  def init_subject(weighted_hash)
    described_class.new(weighted_hash)
  end

  describe '#sample_one' do
    context 'with no participants' do
      let(:weighted_hash) { {} }
      let(:subject) { init_subject(weighted_hash) }

      it 'returns nil' do
        expect(subject.sample_one).to be_nil
      end
    end

    context 'with one participant' do
      let(:weighted_hash) { { 'ham' => 10 } }
      let(:subject) { init_subject(weighted_hash) }

      it 'picks the participant, and then returns nil' do
        expect(subject.sample_one).to eq('ham')
        expect(subject.sample_one).to eq(nil)
        expect(subject.sample_one).to eq(nil)
      end
    end

    context 'with multiple participants' do
      let(:weighted_hash) { { 'ham' => 10, 'agustin' => 1 } }
      let(:subject) { init_subject(weighted_hash) }
      let(:winners) { ['ham', 'agustin'] }

      it 'picks both lunchers then nil' do
        expect(winners).to include(subject.sample_one)
        expect(winners).to include(subject.sample_one)
        expect(subject.sample_one).to eq(nil)
        expect(subject.sample_one).to eq(nil)
      end
    end

    context 'with non positive karma' do
      let(:weighted_hash) { { 'agustin' => 1 } }
      let(:subject) { init_subject(weighted_hash) }

      it 'raises NonPositiveKarmaError with 0 karma' do
        weighted_hash['jaime'] = 0
        expect { init_subject(weighted_hash) }.to raise_error(Lita::Services::NonPositiveKarmaError)
      end

      it 'raises NonPositiveKarmaError with negative karma' do
        weighted_hash['giovanni'] = -10
        expect { init_subject(weighted_hash) }.to raise_error(Lita::Services::NonPositiveKarmaError)
      end
    end
  end

  describe '#sample' do
    context 'with no participants' do
      let(:weighted_hash) { {} }
      let(:subject) { init_subject(weighted_hash) }

      it 'returns empty array' do
        expect(subject.sample(3)).to eq([])
      end
    end

    context 'with participants' do
      let(:weighted_hash) { { 'ham' => 10, 'agustin' => 1, 'giovanni' => 1 } }
      let(:subject) { init_subject(weighted_hash) }

      context 'with sample of size 0' do
        it 'returns empty array' do
          expect(subject.sample(0)).to eq([])
        end
      end

      context 'with sample smaller than lunchers' do
        it 'returns array of size equal to sample argument' do
          expect(subject.sample(2).count).to eq(2)
        end
      end

      context 'with sample size equal to lunchers size' do
        it 'returns array of size equal to sample argument' do
          expect(subject.sample(3).count).to eq(3)
        end

        it 'returns array of size equal to lunchers size' do
          expect(subject.sample(3).count).to eq(weighted_hash.count)
        end

        it 'returns array with every participant' do
          expect(subject.sample(3).sort).to eq(
            [
              'agustin',
              'giovanni',
              'ham'
            ]
          )
        end
      end

      context 'with sample size bigger than lunchers size' do
        it 'returns array of size equal to lunchers size' do
          expect(subject.sample(5).count).to eq(weighted_hash.count)
        end

        it 'returns array with every participant' do
          expect(subject.sample(3).sort).to eq(
            [
              'agustin',
              'giovanni',
              'ham'
            ]
          )
        end
      end
    end
  end
end
