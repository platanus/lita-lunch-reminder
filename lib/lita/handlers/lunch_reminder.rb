require 'rufus-scheduler'

module Lita
  module Handlers
    class LunchReminder < Handler
      on :loaded, :load_on_start

      def self.help_msg(route)
        { "lunch-reminder: #{t("help.#{route}.usage")}" => t("help.#{route}.description") }
      end

      def load_on_start(_payload)
        create_schedule
      end
      route(/gracias/i, command: true, help: help_msg(:thanks)) do |response|
        response.reply(t(:yourwelcome, subject: response.user.mention_name))
      end
      route(/^está?a? (listo|servido) el almuerzo/i, help: help_msg(:lunch_served)) do
        message = t(:dinner_is_served)
        notify current_lunchers_list, message
      end
      route(/qué?e? hay de postre/i, help: help_msg(:dessert)) do |response|
        response.reply(t(:"todays_dessert#{1 + rand(4)}"))
      end
      route(/qué?e? hay de almuerzo/i, help: help_msg(:menu)) do |response|
        response.reply(t(:todays_lunch))
      end
      route(/por\sfavor\sconsidera\sa\s([^\s]+)\s(para|en) (el|los) almuerzos?/,
        command: true, help: help_msg(:consider_user)) do |response|
        mention_name = mention_name_from_response(response)
        success = add_to_lunchers(mention_name)
        if success
          response.reply(t(:will_ask_daily, subject: mention_name))
        else
          response.reply(t(:already_considered, subject: mention_name))
        end
      end
      route(/por\sfavor\sconsidé?e?rame\s(para|en) los almuerzos/i,
        command: true, help: help_msg(:consider_me)) do |response|
        success = add_to_lunchers(response.user.mention_name)
        if success
          response.reply(t(:will_ask_you_daily))
        else
          response.reply(t(:already_considered_you, subject: response.user.mention_name))
        end
      end
      route(/por\sfavor\sya\sno\sconsideres\sa\s([^\s]+)\s(para|en) (el|los) almuerzos?/i,
        command: true, help: help_msg(:not_consider_user)) do |response|
        mention_name = mention_name_from_response(response)
        remove_from_lunchers(mention_name)
        response.reply(t(:thanks_for_answering))
      end
      route(/^sí$|^hoy almuerzo aquí?i?$|^si$/i,
        command: true, help: help_msg(:confirm_yes)) do |response|
        success = add_to_current_lunchers(response.user.mention_name)
        lunchers = current_lunchers_list.length
        if success
          case lunchers
          when 1
            response.reply(t(:current_lunchers_one))
          when 2..10
            response.reply(t(:current_lunchers_some, subject: lunchers))
          end
        else
          response.reply(t(:current_lunchers_too_many))
        end
      end
      route(/no almuerzo/i, command: true, help: help_msg(:confirm_no)) do |response|
        remove_from_current_lunchers response.user.mention_name
        response.reply(t(:thanks_for_answering))
      end

      route(/tengo un invitado/i, command: true) do |response|
        if add_to_current_lunchers("invitado_de_#{response.user.mention_name}")
          response.reply(t(:friend_added, subject: response.user.mention_name))
        else
          response.reply("tu amigo no cabe wn")
        end
      end

      route(/tengo una invitada/i, command: true) do |response|
        response.reply("es rica?")
      end

      route(/quié?e?nes almuerzan hoy/i, help: help_msg(:show_today_lunchers)) do |response|
        case current_lunchers_list.length
        when 0
          response.reply(t(:no_one_lunches))
        when 1
          response.reply(t(:only_one_lunches, subject: current_lunchers_list[0]))
        when 2
          response.reply(t(:dinner_for_two,
            subject1: current_lunchers_list[0],
            subject2: current_lunchers_list[1]))
        else
          response.reply(t(:current_lunchers_list,
            subject1: current_lunchers_list.length,
            subject2: current_lunchers_list.join(', ')))
        end
      end

      route(/quié?e?nes no almuerzan hoy/i, help: help_msg(:show_today_not_lunchers)) do |response|
        response.reply(t(:wont_lunch, subject: wont_lunch.join(', ')))
      end

      route(/quié?e?nes está?a?n considerados para (el|los) almuerzos?/i,
        help: help_msg(:show_considered)) do |response|
        response.reply(lunchers_list.join(', '))
      end

      route(/cédele mi puesto a ([^\s]+)/i, command: true) do |response|
        remove_from_current_lunchers(response.user.mention_name)
        enters = response.matches[0][0]
        add_to_current_lunchers(enters)
        response.reply("tú te lo pierdes, comerá #{enters} por ti")
      end

      def mention_name_from_response(response)
        mention_name = response.matches[0][0]
        mention_name.delete('@') if mention_name
      end

      def refresh
        reset_current_lunchers
        lunchers_list.each do |luncher|
          user = Lita::User.find_by_mention_name(luncher)
          message = t(:question, subject: luncher)
          robot.send_message(Source.new(user: user), message) if user
        end
      end

      def notify(list, message)
        list.shuffle.each do |luncher|
          user = Lita::User.find_by_mention_name(luncher)
          robot.send_message(Source.new(user: user), message) if user
        end
      end

      def add_to_lunchers(mention_name)
        redis.sadd("lunchers", mention_name)
      end

      def remove_from_lunchers(mention_name)
        redis.srem("lunchers", mention_name)
      end

      def lunchers_list
        redis.smembers("lunchers") || []
      end

      def add_to_current_lunchers(mention_name)
        if current_lunchers_list.length < ENV['MAX_LUNCHERS'].to_i
          redis.sadd("current_lunchers", mention_name)
          true
        else
          false
        end
      end

      def remove_from_current_lunchers(mention_name)
        redis.srem("current_lunchers", mention_name)
      end

      def persist_current_lunchers
        sw = Lita::Services::SpreadsheetWriter.new
        sw.write_new_row([Time.now.strftime("%Y-%m-%d")].concat(current_lunchers_list))
      end

      def current_lunchers_list
        redis.smembers("current_lunchers") || []
      end

      def wont_lunch
        redis.sdiff("lunchers", "current_lunchers")
      end

      def reset_current_lunchers
        redis.del("current_lunchers")
      end

      def create_schedule
        scheduler = Rufus::Scheduler.new
        scheduler.cron(ENV['ASK_CRON']) do
          refresh
        end
        scheduler.cron(ENV['PERSIST_CRON']) do
          persist_current_lunchers
        end
      end

      Lita.register_handler(self)
    end
  end
end
