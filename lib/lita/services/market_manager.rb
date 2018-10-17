require 'redis'
require 'json'
require 'time'

module Lita
  module Services
    class MarketManager
      attr_accessor :redis

      def initialize(redis_instance, lunch_assigner, karmanager)
        @lunch_assigner = lunch_assigner
        @karmanager = karmanager
        @redis = redis_instance
      end

      def orders
        orders = @redis.smembers('orders').map { |order| JSON.parse(order) } || [] 
        orders.sort { |x, y| Time.parse(x['created_at']) <=> Time.parse(y['created_at']) }
      end

      def add_limit_order(new_order)
        return if placed_limit_order?(JSON.parse(new_order)['user_id'])
        @redis.sadd('orders', new_order)
      end

      def placed_limit_order?(user_id)
        orders.map { |order| order['user_id'] }.include? user_id
      end

      def add_market_order(lunch_sender_id)
        return unless @karmanager.get_karma(lunch_sender_id).positive?
        order = remove_order
        return if order.nil?
        lunch_sender = Lita::User.find_by_id(order['user_id'].to_i)
        lunch_receiver = Lita::User.find_by_id(lunch_sender_id)
        @karmanager.transfer_karma(lunch_sender_id, order['user_id'], 1)
        @lunch_assigner.transfer_lunch(lunch_sender.mention_name, lunch_receiver.mention_name)
      end

      def remove_order
        return if orders.empty?
        new_orders = orders
        reset_limit_orders
        new_orders[1..-1].each do |order|
          @redis.sadd('orders', order.to_json)
        end
        new_orders.first
      end

      def reset_limit_orders
        @redis.del('orders')
      end
    end
  end
end
