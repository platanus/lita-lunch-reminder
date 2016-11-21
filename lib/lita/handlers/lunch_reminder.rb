require 'rufus-scheduler'

module Lita
  module Handlers
    class LunchReminder < Handler
      on :loaded, :load_on_start
      def load_on_start(_payload)
        scheduler = Rufus::Scheduler.new
        scheduler.cron('00 10 * * *') do
          refresh
        end
      end
      route(/comienza un nuevo día/) do |response|
        refresh
      end
      route(/por\sfavor\sconsidera\sa\s([^\s]+)\s(para|en) (el|los) almuerzos?/) do |response|
        mention_name = response.matches[0][0]
        success = add_to_lunchers(mention_name)
        if success
          response.reply(t(:will_ask_daily, subject: mention_name))
        else
          response.reply(t(:already_considered, subject: mention_name))
        end
      end
      route(/por\sfavor\sconsidé?e?rame\s(para|en) los almuerzos/) do |response|
        success = add_to_lunchers(response.user.mention_name)
        if success
          response.reply(t(:will_ask_you_daily))
        else
          response.reply(t(:already_considered_you,subject:response.user.mention_name))
        end
      end
      route(/^sí$|^hoy almuerzo aquí$|^si$/, command: true) do |response|
        success = add_to_current_lunchers(response.user.mention_name)
        lunchers = current_lunchers_list.length
        if success
          case lunchers
          when 1
            response.reply(t(:current_lunchers_one))
          when 2..9
            response.reply(t(:current_lunchers_some, subject:lunchers))
          end
        else
          response.reply(t(:current_lunchers_too_many))
        end
      end
      route(/^no$|no almuerzo|^nop$/, command: true) do |response|
        remove_from_current_lunchers response.user.mention_name
        response.reply(t(:thanks_for_answering))
      end

      route(/quié?e?nes almuerzan hoy/i) do |response|
        case current_lunchers_list.length
        when 0
          response.reply(t(:no_one_lunches))
        when 1
          response.reply(t(:only_one_lunches, subject: current_lunchers_list[0]))
        when 2
          response.reply(t(:dinner_for_two, subject1: current_lunchers_list[0], subject2: current_lunchers_list[1]))
        else
          response.reply(t(:current_lunchers_list, subject1: current_lunchers_list.length, subject2:current_lunchers_list.join(', ')))
        end
      end

      route(/quié?e?nes está?a?n considerados para el almuerzo\??/i) do |response|
        response.reply(lunchers_list.join(', '))
      end

      def refresh
        reset_current_lunchers
        lunchers_list.each do |luncher|
          user = Lita::User.find_by_mention_name(luncher)
          message = t(:question, subject: luncher)
          robot.send_message(Source.new(user: user), message)
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
        if current_lunchers_list.length < 10
          redis.sadd("current_lunchers", mention_name)
          true
        else
          false
        end
      end

      def remove_from_current_lunchers(mention_name)
        redis.srem("current_lunchers", mention_name)
      end

      def current_lunchers_list
        redis.smembers("current_lunchers") || []
      end

      def havent_answered
        redis.sdiff("lunchers", "current_lunchers")
      end

      def reset_current_lunchers
        redis.del("current_lunchers")
      end
      Lita.register_handler(self)
    end
  end
end
