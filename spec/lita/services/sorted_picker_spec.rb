require "spec_helper"
require 'pry'
require 'dotenv/load'

describe Lita::Services::SortedPicker do
  def init_subject(weighted_hash)
    described_class.new(weighted_hash)
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
      let(:weighted_hash) { { 'ham' => 10, 'agustin' => 2, 'giovanni' => 1 } }
      let(:subject) { init_subject(weighted_hash) }

      context 'with negative sample size' do
        it { expect { subject.sample(-1) }.to raise_error(Lita::Services::NegativeSampleSize) }
      end

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
          expect(subject.sample(3)).to eq(
            [
              'ham',
              'agustin',
              'giovanni'
            ]
          )
        end
      end

      context 'with sample size bigger than lunchers size' do
        it 'returns array of size equal to lunchers size' do
          expect(subject.sample(5).count).to eq(weighted_hash.count)
        end

        it 'returns array with every participant' do
          expect(subject.sample(5)).to eq(
            [
              'ham',
              'agustin',
              'giovanni'
            ]
          )
        end
      end

      describe 'order' do
        let(:weighted_hash) { { 'ham' => 10, 'agustin' => 2, 'giovanni' => 1 } }
        let(:subject) { init_subject(weighted_hash) }

        it { expect(subject.sample(3)).to eq(['ham', 'agustin', 'giovanni']) }
      end
    end
  end
end
