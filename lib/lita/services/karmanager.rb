require 'redis'
module Lita
  module Services
    class Karmanager
      attr_accessor :redis

      def initialize(redis_instance)
        @redis = redis_instance
      end

      def set_karma(user_id, karma)
        @redis.set("#{user_id}:karma", karma.to_i)
      end

      def get_karma(user_id)
        @redis.get("#{user_id}:karma").to_i || 0
      end

      def increase_karma(user_id)
        increase_karma_by(user_id, 1)
      end

      def decrease_karma(user_id)
        decrease_karma_by(user_id, 1)
      end

      def increase_karma_by(user_id, amount)
        @redis.incrby("#{user_id}:karma", amount)
      end

      def decrease_karma_by(user_id, amount)
        @redis.decrby("#{user_id}:karma", amount)
      end

      def transfer_karma(giver_id, receiver_id)
        decrease_karma(giver_id)
        increase_karma(receiver_id)
      end

      def convert_to_new_karma(list, base)
        list.each do |mention_name|
          user = Lita::User.find_by_mention_name(mention_name)
          set_karma(user.id, base + get_karma(mention_name)) if user
        end
      end

      def karma_hash(list)
        kh = list.map { |m| [m, get_karma(Lita::User.find_by_mention_name(m).id)] }.to_h
        kl = kh.map { |k, v| [k, v - kh.values.min] }.to_h
        kl.map { |k, v| [k, v.to_i.zero? ? 1 : v] }.to_h
      end

      def average_karma(list)
        total_karma = 0
        list.each do |m|
          usr = Lita::User.find_by_mention_name(m)
          total_karma += get_karma(usr.id) if usr
        end
        total_karma / list.length
      end
    end
  end
end
