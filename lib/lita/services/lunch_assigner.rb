require 'redis'
module Lita
  module Services
    class LunchAssigner
      attr_accessor :redis

      def initialize(redis_instance, karmanager_instance)
        @redis = redis_instance
        @karmanager = karmanager_instance
      end

      def set_karma(mention_name, karma)
        user = Lita::User.find_by_mention_name(mention_name)
        @redis.set("#{user.id}:karma", karma.to_i) if user
      end

      def get_karma(mention_name)
        user = Lita::User.find_by_mention_name(mention_name)
        return 0 unless user
        @redis.get("#{user.id}:karma").to_i || 0
      end

      def can_wager?(mention_name, wager)
        get_karma(mention_name) >= wager && wager > 0
      end

      def set_wager(mention_name, wager)
        can_wager = can_wager?(mention_name, wager.to_i)
        @redis.set("#{mention_name}:wager", wager.to_i) if can_wager
        can_wager
      end

      def get_wager(mention_name)
        (@redis.get("#{mention_name}:wager") || 1).to_i
      end

      def increase_karma(mention_name)
        @redis.incr("#{mention_name}:karma")
      end

      def decrease_karma(mention_name, wager)
        user = Lita::User.find_by_mention_name(mention_name)
        @redis.decrby("#{user.id}:karma", wager) if user
      end

      def current_lunchers_list
        @redis.smembers('current_lunchers') || []
      end

      def add_to_current_lunchers(mention_name)
        @redis.sadd('current_lunchers', mention_name)
      end

      def remove_from_current_lunchers(mention_name)
        @redis.srem('current_lunchers', mention_name)
      end

      def add_to_lunchers(mention_name)
        @redis.sadd('lunchers', mention_name)
      end

      def remove_from_lunchers(mention_name)
        @redis.srem('lunchers', mention_name)
      end

      def lunchers_list
        @redis.smembers('lunchers') || []
      end

      def add_to_winning_lunchers(mention_name)
        if winning_lunchers_list.count < ENV['MAX_LUNCHERS'].to_i
          @redis.sadd('winning_lunchers', mention_name)
          true
        else
          false
        end
      end

      def remove_from_winning_lunchers(mention_name)
        @redis.srem('winning_lunchers', mention_name)
      end

      def transfer_lunch(sender_mention_name, receiver_mention_name)
        if lunchers_list.include?(receiver_mention_name) &&
            !winning_lunchers_list.include?(receiver_mention_name) \
            && remove_from_winning_lunchers(sender_mention_name)
          add_to_winning_lunchers(receiver_mention_name)
        else
          false
        end
      end

      def persist_winning_lunchers
        sw = Lita::Services::SpreadsheetManager.new('ALMORZADORES')
        time = Time.now.strftime('%Y-%m-%d')
        winning_lunchers_list.each do |winner|
          user = User.find_by_mention_name(winner) || User.find_by_name(winner)
          winner_id = user ? user.id : nil
          sw.write_new_row([time, winner, winner_id])
        end
      end

      def winning_lunchers_list
        @redis.smembers('winning_lunchers') || []
      end

      def loosing_lunchers_list
        return [] unless already_assigned?
        current_lunchers_list - winning_lunchers_list
      end

      def wont_lunch
        @redis.sdiff('lunchers', 'current_lunchers')
      end

      def reset_lunchers
        lunchers_list.each do |luncher|
          @redis.del("#{luncher}:wager")
        end
        @redis.del("current_lunchers")
        @redis.del("winning_lunchers")
        @redis.del("already_assigned")
      end

      def karma_hash(list)
        kh = list.map { |m| [m, get_karma(m)] }.to_h
        kh.map { |k, v| [k, v - kh.values.min + 1] }.to_h
      end

      def wager_hash(list)
        list.map { |m| [m, get_wager(m)] }.to_h
      end

      def pick_winners(amount)
        wh = wager_hash(current_lunchers_list)
        winners = Lita::Services::WeightedPicker.new(
          wager_hash(current_lunchers_list),
          karma_hash(current_lunchers_list)
        ).choose(amount)

        winners.each do |w|
          decrease_karma w, wh[w]
          add_to_winning_lunchers w
        end
      end

      def already_assigned?
        redis.get('already_assigned') ? true : false
      end

      def do_the_assignment
        pick_winners(ENV['MAX_LUNCHERS'].to_i)
        redis.set('already_assigned', true)
      end

      def weekday_name_plus(i)
        week = ['domingo', 'lunes', 'martes', 'miércoles', 'jueves', 'viernes', 'sábado']
        week[(Date.today.cwday + i) % 7]
      end
    end
  end
end
