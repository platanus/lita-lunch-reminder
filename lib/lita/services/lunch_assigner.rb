require 'redis'
module Lita
  module Services
    class LunchAssigner
      attr_accessor :redis

      def initialize(redis_instance, karmanager_instance)
        @redis = redis_instance
        @karmanager = karmanager_instance
      end

      def current_lunchers_list
        @redis.smembers("current_lunchers") || []
      end

      def add_to_current_lunchers(mention_name)
        @redis.sadd("current_lunchers", mention_name)
      end

      def remove_from_current_lunchers(mention_name)
        @redis.srem("current_lunchers", mention_name)
      end

      def add_to_lunchers(mention_name)
        @redis.sadd("lunchers", mention_name)
      end

      def remove_from_lunchers(mention_name)
        @redis.srem("lunchers", mention_name)
      end

      def lunchers_list
        @redis.smembers("lunchers") || []
      end

      def add_to_winning_lunchers(mention_name)
        if winning_lunchers_list.count < ENV['MAX_LUNCHERS'].to_i
          @redis.sadd("winning_lunchers", mention_name)
          true
        else
          false
        end
      end

      def remove_from_winning_lunchers(mention_name)
        @redis.srem("winning_lunchers", mention_name)
      end

      def persist_winning_lunchers
        sw = Lita::Services::SpreadsheetWriter.new
        time = Time.now.strftime("%Y-%m-%d")
        winning_lunchers_list.each do |winner|
          user = User.find_by_mention_name(winner) || User.find_by_name(winner)
          winner_id = user ? user.id : nil
          sw.write_new_row([time, winner, winner_id])
        end
      end

      def winning_lunchers_list
        @redis.smembers("winning_lunchers") || []
      end

      def loosing_lunchers_list
        return [] unless already_assigned?
        current_lunchers_list - winning_lunchers_list
      end

      def wont_lunch
        @redis.sdiff("lunchers", "current_lunchers")
      end

      def reset_lunchers
        @redis.del("current_lunchers")
        @redis.del("winning_lunchers")
        @redis.del("already_assigned")
      end

      def pick_winners(amount)
        winners = Lita::Services::WeightedPicker.new(
          @karmanager.karma_hash(current_lunchers_list)
        ).sample(amount)

        winners.each do |w|
          @karmanager.decrease_karma Lita::User.find_by_mention_name(w).id
          add_to_winning_lunchers w
        end
      end

      def already_assigned?
        redis.get("already_assigned") ? true : false
      end

      def do_the_assignment
        pick_winners(ENV['MAX_LUNCHERS'].to_i)
        redis.set("already_assigned", true)
      end
    end
  end
end
