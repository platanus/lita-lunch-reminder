require "lita"
require "redis"

Lita.load_locales Dir[File.expand_path(
  File.join("..", "..", "locales", "*.yml"), __FILE__
)]

require "lita/handlers/lunch_reminder"
require "lita/services/spreadsheet_writer"
require "lita/services/lunch_assigner"

Lita::Handlers::LunchReminder.template_root File.expand_path(
  File.join("..", "..", "templates"), __FILE__
)
