require "lita"
require "redis"
require "rufus-scheduler"

Lita.load_locales Dir[File.expand_path(
  File.join("..", "..", "locales", "*.yml"), __FILE__
)]

require "lita/handlers/lunch_reminder"
require "lita/handlers/api/api_controller"
require "lita/handlers/api/karma"
require "lita/handlers/api/lunch"
require "lita/handlers/api/market"
require "lita/services/spreadsheet_manager"
require "lita/services/lunch_assigner"
require "lita/services/weighted_picker"
require "lita/services/karmanager"
require "lita/services/market_manager"

Lita::Handlers::LunchReminder.template_root File.expand_path(
  File.join("..", "..", "templates"), __FILE__
)

unless ENV['RACK_ENV'] == 'production'
  require 'pry'
end
