require 'spec_helper'
require 'pry'
require 'dotenv/load'
require 'date'

describe Lita::Services::LunchCounter, lita: true do
  before do
    allow(ENV).to receive(:fetch)
      .with('MAIN_SHEET')
      .and_return('SHEET')
    allow(Lita::Services::SpreadsheetManager).to receive(:new).and_return(sh_manager)
    allow(sh_manager).to receive(:load_worksheet).with('Platanus').and_return(platanus_ws)
    allow(sh_manager).to receive(:load_worksheet).with('Fintual').and_return(fintual_ws)
    allow(sh_manager).to receive(:load_worksheet).with('Buda').and_return(buda_ws)
    allow(sh_manager).to receive(:load_worksheet).with(ENV.fetch('MAIN_SHEET')).and_return(main_ws)
    allow(sh_manager).to receive(:load_worksheet).with('Monthly Counter').and_return(true)
    allow(main_ws).to receive(:num_rows).and_return(5)
    allow(main_ws).to receive(:[]).with(1, 1).and_return('2018-10-30')
    allow(main_ws).to receive(:[]).with(2, 1).and_return('2018-11-01')
    allow(main_ws).to receive(:[]).with(3, 1).and_return('2018-11-03')
    allow(main_ws).to receive(:[]).with(4, 1).and_return('2018-11-04')
    allow(main_ws).to receive(:[]).with(5, 1).and_return('2018-11-05')
    allow(main_ws).to receive(:[]).with(1, 2).and_return('bob')
    allow(main_ws).to receive(:[]).with(2, 2).and_return('juanito')
    allow(main_ws).to receive(:[]).with(3, 2).and_return('pepe')
    allow(main_ws).to receive(:[]).with(4, 2).and_return('maria')
    allow(main_ws).to receive(:[]).with(5, 2).and_return('maria')
  end

  let(:sh_manager) { double }
  let(:subject) { described_class.new }
  let(:platanus_ws) { double(rows: [['juanito'], ['pepe']]) }
  let(:fintual_ws) { double(rows: [['maria'], ['pepe']]) }
  let(:buda_ws) { double(rows: [['maria'], ['bob']]) }
  let(:main_ws) { double }
  # let(:main_rows) do
  #   [
  #     ['header1', 'header2'],
  #     ['2018-11-30', 'bob'],
  #     ['2018-12-01', 'juanito'],
  #     ['2018-12-02', 'pepe'],
  #     ['2018-12-03', 'maria'],
  #     ['2018-12-04', 'maria']
  #   ]
  # end

  describe '#build_orgs' do
    it 'builds each organization with their members' do
      subject.build_orgs
      expect(subject.orgs).to eq('Buda' => { 'members' => ['maria', 'bob'] },
                                 'Fintual' => { 'members' => ['maria', 'pepe'] },
                                 'Platanus' => { 'members' => ['juanito', 'pepe'] })
    end
  end

  describe '#find_repeated_members' do
    before do
      subject.build_orgs
    end
    it 'finds repeated members' do
      expect(subject.find_repeated_members).to eq(['pepe', 'maria'])
    end
  end

  describe '#find_first_day_row' do
    before do
      allow(sh_manager).to receive(:worksheet).and_return(main_ws)
    end

    it 'find the row with first day of month' do
      expect(subject.find_first_day_row).to eq(2)
    end
  end

  describe '#count_lunches' do
    before do
      subject.build_orgs
      allow(sh_manager).to receive(:worksheet).and_return(main_ws)
    end

    it 'counts lunches for everybody' do
      subject.count_lunches
      expect(subject.lunchers).to eq('bob' => 0, 'juanito' => 1, 'maria' => 2, 'pepe' => 1)
    end
  end

  describe '#write_counts' do
    before do
      allow(sh_manager).to receive(:worksheet).and_return(main_ws)
      allow(sh_manager).to receive(:insert_new_row).with(anything).and_return(true)
      subject.build_orgs
      subject.count_lunches
      subject.manage_repeated_members
      subject.add_lunches_to_orgs
    end

    it 'counts lunches for everybody' do
      subject.count_lunches
      expect(subject.write_counts).to eq(['November', '1.5', '1.5', '1.0'])
    end
  end
end
