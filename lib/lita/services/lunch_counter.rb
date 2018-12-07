require 'date'

module Lita
  module Services
    class LunchCounter
      attr_accessor :orgs, :lunchers

      def initialize
        @sm = Lita::Services::SpreadsheetManager.new(ENV.fetch('MAIN_SHEET'))
        @orgs = {}
        @lunchers = {}
        @orgs_names = ['Platanus', 'Fintual', 'Buda']
      end

      def persist_lunches_count
        build_orgs
        find_repeated_members
        count_lunches
        manage_repeated_members
        add_lunches_to_orgs
        write_counts
      end

      def write_counts
        @sm.load_worksheet('Monthly Counter')
        row = [Date.today.prev_month.strftime('%B')]
        @orgs_names.each do |org|
          row << @orgs[org]['lunches'].to_s
        end
        return row if @sm.insert_new_row(row)
      end

      def add_lunches_to_orgs
        @lunchers.keys.each do |user|
          @orgs_names.each do |org|
            @orgs[org]['lunches'] += @lunchers[user] if @orgs[org]['members'].include? user
          end
        end
      end

      def build_orgs
        @orgs_names.each do |org|
          sheet = @sm.load_worksheet(org)
          @orgs[org] = Hash.new(0)
          org_members = []
          sheet.rows.each do |row|
            org_members << row.first
            @lunchers[row.first] = 0
          end
          @orgs[org]['members'] = org_members
        end
      end

      def find_repeated_members
        all = []
        @orgs_names.each do |org|
          all += @orgs[org]['members']
        end
        all.reject { |e| all.count(e) < 2 }.uniq
      end

      def manage_repeated_members
        find_repeated_members.each do |user|
          @lunchers[user] /= 2.0
        end
      end

      def count_lunches
        sheet = @sm.load_worksheet(ENV.fetch('MAIN_SHEET'))
        user_column = 2
        total_rows = sheet.num_rows
        inital_row = find_first_day_row
        (inital_row..total_rows).each do |n|
          user = sheet[n, user_column]
          if user.include? 'invitado'
            user = user.split('_')[-1]
            @lunchers[user] += 1
          else
            @lunchers[sheet[n, user_column]] += 1
          end
        end
      end

      def find_first_day_row
        sheet = @sm.worksheet
        inital_row = sheet.num_rows
        time = Date.today
        obj_time = Date.today.prev_month - Date.today.mday + 1
        until obj_time > time
          inital_row -= 1
          year, month, day = sheet[inital_row, 1].split('-').map(&:to_i)
          time = Date.new(year, month, day)
        end
        inital_row + 1
      end
    end
  end
end
