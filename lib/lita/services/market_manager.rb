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
        orders = @redis.smembers('orders') || []
        orders.map { |order| JSON.parse(order) }
              .sort { |x, y| Time.parse(x['created_at']) <=> Time.parse(y['created_at']) }
      end

      def ask_orders
        orders = @redis.smembers('orders') || []
        orders.map { |order| JSON.parse(order) }
              .select { |z| z['type'] == 'ask' }
              .sort { |x, y| Time.parse(x['created_at']) <=> Time.parse(y['created_at']) }
      end

      def bid_orders
        orders = @redis.smembers('orders') || []
        orders.map { |order| JSON.parse(order) }
              .select { |z| z['type'] == 'bid' }
              .sort { |x, y| Time.parse(x['created_at']) <=> Time.parse(y['created_at']) }
      end

      def find_order(type, user_id)
        orders.find { |order| order['type'] == type && order['user_id'] == user_id }
      end

      def remove_order(order)
        @redis.srem('orders', order.to_json)
      end

      def add_limit_order(user:, type:, created_at: Time.now)
        new_order = build_new_order(user: user, type: type, created_at: created_at)
        return if placed_limit_order?(new_order[:user_id])

        @redis.sadd('orders', new_order.to_json)
        new_order
      end

      def placed_limit_order?(user_id)
        orders.map { |order| order['user_id'] }.include? user_id
      end

      def remove_orders
        new_ask_orders = ask_orders
        new_bid_orders = bid_orders
        return if new_ask_orders.empty? || new_bid_orders.empty?
        reset_limit_orders
        new_ask_orders[1..-1].each do |order|
          @redis.sadd('orders', order.to_json)
        end
        new_bid_orders[1..-1].each do |order|
          @redis.sadd('orders', order.to_json)
        end
        { 'ask' => new_ask_orders.first, 'bid' => new_bid_orders.first }
      end

      def reset_limit_orders
        @redis.del('orders')
      end

      def execute_transaction
        return unless transaction_possible?
        executed_orders = remove_orders
        lunch_seller = Lita::User.find_by_id(executed_orders['ask']['user_id'])
        lunch_buyer = Lita::User.find_by_id(executed_orders['bid']['user_id'])
        @karmanager.transfer_karma(lunch_buyer.id, lunch_seller.id, 1)
        @lunch_assigner.transfer_lunch(lunch_seller.mention_name, lunch_buyer.mention_name)
        {
          'buyer' => lunch_buyer,
          'seller' => lunch_seller,
          'timestamp' => Time.now,
          'bid_order' => executed_orders['bid'],
          'ask_order' => executed_orders['ask']
        }
      end

      def transaction_possible?
        ask_orders.any? && bid_orders.any?
      end

      private

      def build_new_order(user:, type:, created_at:)
        {
          id: SecureRandom.uuid,
          user_id: user.id,
          type: type,
          created_at: created_at
        }
      end
    end
  end
end
