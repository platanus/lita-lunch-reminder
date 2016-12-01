require "google_drive"
require "Base64"
module Lita
  module Services
    class SpreadsheetWriter
      def initialize
        @session = GoogleDrive::Session.from_service_account_key(credentials_io)
        @ws = @session.spreadsheet_by_key(ENV['GOOGLE_SP_KEY']).worksheets[0]
      end

      def credentials_io
        credentials = {
          type: ENV['GOOGLE_SP_CRED_TYPE'],
          project_id: ENV['GOOGLE_SP_CRED_PROJECT_ID'],
          private_key_id: ENV['GOOGLE_SP_CRED_PRIVATE_KEY_ID'],
          private_key: Base64.strict_decode64(ENV['GOOGLE_SP_CRED_PRIVATE_KEY']),
          client_email: ENV['GOOGLE_SP_CRED_CLIENT_EMAIL'],
          client_id: ENV['GOOGLE_SP_CRED_CLIENT_ID'],
          auth_uri: ENV['GOOGLE_SP_CRED_AUTH_URI'],
          token_uri: ENV['GOOGLE_SP_CRED_TOKEN_URI'],
          auth_provider_x509_cert_url: ENV['GOOGLE_SP_CRED_AUTH_PROVIDER_X509_CERT_URL'],
          client_x509_cert_url: ENV['GOOGLE_SP_CRED_CLIENT_X509_CERT_URL']
        }
        StringIO.new(credentials.to_json)
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
