require 'redis'
module Lita
  module Services
    class Karmanager
      attr_accessor :redis

      MAX_DAILY_TRANSFER_BY_USER = 5

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
        karma_transfered = daily_karma_transfered(user_id)
        @redis.set("#{user_id}:karma_transfered", karma_transfered + amount)
      end

      def transfer_karma(giver_id, receiver_id, amount)
        return false unless can_transfer?(giver_id, amount)
        decrease_karma_by(giver_id, amount)
        increase_karma_by(receiver_id, amount)
        true
      end

      def can_transfer?(giver_id, amount)
        karma = get_karma(giver_id)
        return false if karma < amount
        return false if max_daily_transfer_reached?(giver_id)
        return false if amount + daily_karma_transfered(giver_id) > MAX_DAILY_TRANSFER_BY_USER
        true
      end

      def daily_karma_transfered(user_id)
        (@redis.get("#{user_id}:karma_transfered") || 0).to_i
      end

      def max_daily_transfer_reached?(giver_id)
        daily_karma_transfered(giver_id) >= MAX_DAILY_TRANSFER_BY_USER
      end

      def reset_daily_transfers(lunchers_ids)
        lunchers_ids.each do |luncher_id|
          @redis.del("#{luncher_id}:karma_transfered")
        end
      end

      def convert_to_new_karma(list, base)
        list.each do |mention_name|
          user = Lita::User.find_by_mention_name(mention_name)
          set_karma(user.id, base + get_karma(mention_name)) if user
        end
      end

      def karma_hash(list)
        kh = list.map { |m| [m, get_karma(Lita::User.find_by_mention_name(m).id)] }.to_h
        kl = kh.map { |k, v| [k, v.to_i - kh.values.min] }.to_h
        kl.map { |k, v| [k, v.to_i.zero? ? 1 : v.to_i] }.to_h
      end

      def average_karma(list)
        total_karma = 0
        list.each do |m|
          usr = Lita::User.find_by_mention_name(m)
          raise Exception.new("Can't find mention name '#{m}'") if !usr
          total_karma += get_karma(usr.id)
        end
        total_karma / list.length
      end
    end
  end
end
