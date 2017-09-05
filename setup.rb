unless ENV['RACK_ENV'] == 'production'
  require 'dotenv'
  Dotenv.load('.env.local')
  Dotenv.load('.env.development')
  Dotenv.load('.env.test')
end
