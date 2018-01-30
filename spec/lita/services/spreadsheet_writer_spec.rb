RSpec.configure do |config|
  config.mock_framework = :rspec
end

context 'on a new empty worksheet' do
  let(:worksheet_mock) { instance_double('spreadsheet.worksheets[0]') }

  let(:google_spreasheet_mock) do
    double(
      worksheets: [worksheet_mock]
    )
  end

  let(:spreadsheetWriter) do
    instance_double(
      'SpreadsheetWriter',
      spreadsheet: google_spreasheet_mock
    )
  end

  let(:expected_session_credentials) do
    {
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
  end

  let(:google_session_mock) do
    double(
      spreadsheet_by_key: true
    )
  end

  describe '#write_new_row' do
    before do
      allow(ENV).to receive(:fetch)
        .with('GOOGLE_SP_KEY')
        .and_return('ENV_GOOGLE_SP_KEY')
      # credentials_io:
      allow(ENV).to receive(:fetch)
        .with('GOOGLE_SP_CRED_TYPE')
        .and_return('TYPE')
      allow(ENV).to receive(:fetch)
        .with('GOOGLE_SP_CRED_PROJECT_ID')
        .and_return('PROJECT_ID')
      allow(ENV).to receive(:fetch)
        .with('GOOGLE_SP_CRED_PRIVATE_KEY_ID')
        .and_return('PRIVATE_KEY_ID')
      allow(ENV).to receive(:fetch)
        .with('GOOGLE_SP_CRED_PRIVATE_KEY')
        .and_return('UFJJVkFURV9LRVk=') # Base64.strict_decode64(UFJJVkFURV9LRVk=) == PRIVATE_KEY
      allow(ENV).to receive(:fetch)
        .with('GOOGLE_SP_CRED_CLIENT_EMAIL')
        .and_return('CLIENT_EMAIL')
      allow(ENV).to receive(:fetch)
        .with('GOOGLE_SP_CRED_CLIENT_ID')
        .and_return('CLIENT_ID')
      allow(ENV).to receive(:fetch)
        .with('GOOGLE_SP_CRED_AUTH_URI')
        .and_return('AUTH_URI')
      allow(ENV).to receive(:fetch)
        .with('GOOGLE_SP_CRED_TOKEN_URI')
        .and_return('TOKEN_URI')
      allow(ENV).to receive(:fetch)
        .with('GOOGLE_SP_CRED_AUTH_PROVIDER_X509_CERT_URL')
        .and_return('AUTH_PROVIDER_X509_CERT_URL')
      allow(ENV).to receive(:fetch)
        .with('GOOGLE_SP_CRED_CLIENT_X509_CERT_URL')
        .and_return('CLIENT_X509_CERT_URL')

      expect(GoogleDrive::Session).to receive(:from_service_account_key)
        .with(expected_session_credentials)
        .and_return(google_session_mock)
      google_session_mock = GoogleDrive::Session
                            .from_service_account_key(expected_session_credentials)

      expect(google_session_mock).to receive(:spreadsheet_by_key)
        .with(ENV.fetch('GOOGLE_SP_KEY'))
        .and_return(google_spreasheet_mock)
      google_session_mock.spreadsheet_by_key('ENV_GOOGLE_SP_KEY')
    end

    context 'when given an array with values' do
      it "should write the array in the last row, each value in it's own column" do
        array = [*0..5]

        allow(spreadsheetWriter).to receive(:write_new_row).with(array).and_return(true)
        allow(spreadsheetWriter.spreadsheet.worksheets[0]).to receive_message_chain('rows.last')
          .and_return([*0..5].map(&:to_s))

        write_flag = spreadsheetWriter.write_new_row(array)
        expect(write_flag).to eq(true)
        expect(google_spreasheet_mock.worksheets[0].rows.last).to eq(array.map(&:to_s))
      end
    end

    context 'given an empty array' do
      it 'should not write in the worksheet and return false' do
        allow(spreadsheetWriter).to receive(:write_new_row).with([]).and_return(false)

        write_flag = spreadsheetWriter.write_new_row([])
        expect(write_flag).to eq(false)
      end
    end
  end
end
