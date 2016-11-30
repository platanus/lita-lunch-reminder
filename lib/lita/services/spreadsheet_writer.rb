require "google_drive"
module Lita
  module Services
    class SpreadsheetWriter

      def initialize
        @session = GoogleDrive::Session.from_service_account_key("lita-ham-03f138698b38.json")
        @ws = @session.spreadsheet_by_key("1XtlGfn4Ih6YrpeGNh6RHgjWpmFcHt48RxdIkeoQ3G90").worksheets[0]
      end

      def write_new_row(array)
        new_row = @ws.num_rows + 1
        array.each_with_index do |e, i|
          @ws[new_row, i + 1] = e
        end
        @ws.save
      end
    end
  end
end
