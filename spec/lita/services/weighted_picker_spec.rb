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
        expect(subject.sample_one(weighted_hash)).to be_nil
      end
    end

    context 'with one participant' do
      let(:weighted_hash) { { 'ham' => 10 } }
      let(:subject) { init_subject(weighted_hash) }

      it 'picks the participant, and then returns nil' do
        expect(subject.sample_one(weighted_hash)).to eq('ham')
        expect(subject.sample_one(weighted_hash.except('ham'))).to eq(nil)
      end
    end

    context 'with multiple participants' do
      let(:weighted_hash) { { 'ham' => 10, 'agustin' => 1 } }
      let(:subject) { init_subject(weighted_hash) }
      let(:winners) { ['ham', 'agustin'] }

      it 'picks both lunchers then nil' do
        first_chosen = subject.sample_one(weighted_hash)
        expect(winners).to include(first_chosen)
        second_chosen = subject.sample_one(weighted_hash.except(first_chosen))
        expect(winners).to include(second_chosen)
        expect(
          subject.sample_one(weighted_hash.except(first_chosen, second_chosen))
        ).to be_nil
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

  describe '#truncate' do
    context 'with no participants' do
      let(:weighted_hash) { {} }
      let(:subject) { init_subject(weighted_hash) }

      it 'returns empty array' do
        expect(subject.truncate(3)).to eq([])
      end
    end

    context 'with participants' do
      let(:weighted_hash) { { 'ham' => 10, 'agustin' => 2, 'giovanni' => 1, 'andres' => 1 } }
      let(:subject) { init_subject(weighted_hash) }

      context 'with sample of size 0' do
        it 'returns empty array' do
          expect(subject.truncate(0)).to eq([])
        end
      end

      context 'with sample smaller than lunchers' do
        it 'returns array of size equal to sample argument' do
          expect(subject.truncate(3).count).to eq(3)
        end
      end

      context 'with sample size equal to lunchers size' do
        it 'returns array of size equal to sample argument' do
          expect(subject.truncate(4).count).to eq(4)
        end

        it 'returns array of size equal to lunchers size' do
          expect(subject.truncate(4).count).to eq(weighted_hash.count)
        end

        it 'returns array with every participant' do
          expect(subject.truncate(4)).to contain_exactly(
            'agustin',
            'giovanni',
            'ham',
            'andres'
          )
        end
      end

      context 'with sample size bigger than lunchers size' do
        it 'returns array of size equal to lunchers size' do
          expect(subject.truncate(5).count).to eq(weighted_hash.count)
        end

        it 'returns array with every participant' do
          expect(subject.truncate(5).sort).to contain_exactly(
            'agustin',
            'giovanni',
            'ham',
            'andres'
          )
        end
      end
    end
  end

  describe "#choose" do
    context 'with less participants than choose number' do
      let(:weighted_hash) do
        { 'giovanni' => 10, 'andres' => 5, 'jaime' => 2 }
      end
      let(:subject) { init_subject(weighted_hash) }

      it 'chooses all the users' do
        expect(subject.choose(4)).to contain_exactly('giovanni', 'andres', 'jaime')
      end
    end

    context 'with equal participants than choose number' do
      let(:weighted_hash) do
        { 'giovanni' => 10, 'andres' => 5, 'jaime' => 2 }
      end
      let(:subject) { init_subject(weighted_hash) }

      it 'chooses all the users' do
        expect(subject.choose(3)).to contain_exactly('giovanni', 'andres', 'jaime')
      end
    end

    context 'with more participants than choose number' do
      let(:weighted_hash) do
        { 'giovanni' => 10, 'andres' => 5, 'jaime' => 2, 'agustin' => 2, 'juan' => 2, 'pedro' => 1 }
      end
      let(:subject) { init_subject(weighted_hash) }

      context 'there is a tie in the last positions' do
        before do
          allow(subject).to receive(:truncate).and_return(['giovanni', 'andres'])
          allow(subject).to receive(:sample).and_return(['jaime', 'agustin'])
        end

        it 'receives truncate method' do
          subject.choose(4)
          expect(subject).to have_received(:truncate).with(2, weighted_hash)
        end

        it 'receives sample method' do
          subject.choose(4)
          expect(subject).to have_received(:sample).with(2, 'jaime' => 2, 'agustin' => 2, 'juan' => 2)
        end

        it 'returns and array with the users with highest karma and a sample of who where tied' do
          expect(subject.choose(4)).to contain_exactly('giovanni', 'andres', 'jaime', 'agustin')
        end
      end

      context 'there is no tie in the last positions' do
        it 'returns and array with the elements with more karma' do
          expect(subject.choose(2)).to contain_exactly('giovanni', 'andres')
        end
      end
    end
  end
end
