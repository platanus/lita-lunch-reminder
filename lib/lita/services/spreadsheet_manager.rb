require "google_drive"
require "base64"
module Lita
  module Services
    class SpreadsheetManager
      def initialize(spreadsheet_key, ws_title)
        @session = GoogleDrive::Session.from_service_account_key(credentials_io)
        @spreadsheet = @session.spreadsheet_by_key(spreadsheet_key)
        @ws = load_worksheet(ws_title)
      end

      # current selected worksheet
      def worksheet
        @ws
      end

      def spreadsheet
        @spreadsheet
      end

      def write_new_row(array)
        new_row = @ws.num_rows + 1
        array.each_with_index do |e, i|
          @ws[new_row, i + 1] = e
        end
        @ws.save
      end

      def insert_new_row(array)
        @ws.insert_rows(@ws.num_rows + 1, [array])
        @ws.save
      end

      def load_worksheet(ws_title)
        @ws = @spreadsheet.worksheet_by_title(ws_title)
      end

      private

      def credentials_io
        credentials = {
          type: ENV.fetch('GOOGLE_SP_CRED_TYPE'),
          project_id: ENV.fetch('GOOGLE_SP_CRED_PROJECT_ID'),
          private_key_id: ENV.fetch('GOOGLE_SP_CRED_PRIVATE_KEY_ID'),
          private_key: Base64.strict_decode64(ENV.fetch('GOOGLE_SP_CRED_PRIVATE_KEY')),
          client_email: ENV.fetch('GOOGLE_SP_CRED_CLIENT_EMAIL'),
          client_id: ENV.fetch('GOOGLE_SP_CRED_CLIENT_ID'),
          auth_uri: ENV.fetch('GOOGLE_SP_CRED_AUTH_URI'),
          token_uri: ENV.fetch('GOOGLE_SP_CRED_TOKEN_URI'),
          auth_provider_x509_cert_url: ENV.fetch('GOOGLE_SP_CRED_AUTH_PROVIDER_X509_CERT_URL'),
          client_x509_cert_url: ENV.fetch('GOOGLE_SP_CRED_CLIENT_X509_CERT_URL')
        }
        StringIO.new(credentials.to_json)
      end
    end
  end
end
