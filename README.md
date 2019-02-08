# lita-lunch-reminder

TODO: Add a description of the plugin.

## Installation

Add lita-lunch-reminder to your Lita instance's Gemfile:

``` ruby
gem "lita-lunch-reminder"
```

## Configuration

TODO: Describe any configuration attributes the plugin exposes.

## Environment Variables

The following environment variables should be defined in your Lita instance:

- MAX_LUNCHERS
- EMISSION_INTERVAL_DAYS: days between karma emissions - default: 30
- COOKING_CHANNEL: slack channel where cooking-related announcements belong (**must** start with `#`)
- KARMA_AUDIT_CHANNEL: slack channel where all karma transactions are made public (**must** start with `#`)
- QUIET_START_HOUR
- QUIET_END_HOUR
- ASK_CRON
- WAIT_RESPONSES_SECONDS
- PERSIST_CRON
- COUNTS_CRON
- KARMA_LIST_CRON
- LUNCH_ADMIN
- KARMA_LIMIT: max karma users can have - default: 50
- MAIN_SHEET
- GOOGLE_SP_CRED_AUTH_PROVIDER_X509_CERT_URL
- GOOGLE_SP_CRED_AUTH_URI
- GOOGLE_SP_CRED_CLIENT_EMAIL
- GOOGLE_SP_CRED_CLIENT_ID
- GOOGLE_SP_CRED_CLIENT_X509_CERT_URL
- GOOGLE_SP_CRED_PRIVATE_KEY
- GOOGLE_SP_CRED_PRIVATE_KEY_ID
- GOOGLE_SP_CRED_PROJECT_ID
- GOOGLE_SP_CRED_TOKEN_URI
- GOOGLE_SP_CRED_TYPE
- GOOGLE_SP_KEY

## Usage

TODO: Describe the plugin's features and how to use them.
