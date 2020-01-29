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

      def order_criteria(order1, order2, order_type)
        factor = order_type == :ask ? 1 : -1
        [factor * order1['price'], Time.parse(order1['created_at'])] <=>
          [factor * order2['price'], Time.parse(order2['created_at'])]
      end

      def ask_orders
        orders = @redis.smembers('orders') || []
        orders.map { |order| JSON.parse(order) }
              .select { |z| z['type'] == 'ask' }
              .sort { |x, y| order_criteria(x, y, :ask) }
      end

      def bid_orders
        orders = @redis.smembers('orders') || []
        orders.map { |order| JSON.parse(order) }
              .select { |z| z['type'] == 'bid' }
              .sort { |x, y| order_criteria(x, y, :bid) }
      end

      def find_order(type, user_id)
        orders.find { |order| order['type'] == type && order['user_id'] == user_id }
      end

      def remove_order(order)
        @redis.srem('orders', order.to_json)
      end

      def add_limit_order(user:, type:, created_at: Time.now, price: 1)
        new_order = build_new_order(
          user: user, type: type, created_at: created_at, price: price
        )
        return if placed_limit_order?(new_order[:user_id])

        @redis.sadd('orders', new_order.to_json)
        new_order
      end

      def placed_limit_order?(user_id)
        orders.map { |order| order['user_id'] }.include? user_id
      end

      def pop_matching_orders
        temp_ask_orders = ask_orders
        temp_bid_orders = bid_orders
        return if temp_ask_orders.empty? || temp_bid_orders.empty?

        matches = matching_orders
        return unless matches

        reset_limit_orders
        temp_ask_orders.reject { |ask| ask['id'] == matches['ask']['id'] }
                       .each { |order| @redis.sadd('orders', order.to_json) }
        temp_bid_orders.reject { |bid| bid['id'] == matches['bid']['id'] }
                       .each { |order| @redis.sadd('orders', order.to_json) }
        matches
      end

      def matching_orders
        ask_orders.each do |ask_order|
          bid_orders.each do |bid_order|
            next if ask_order['price'] > bid_order['price']

            return { 'ask' => ask_order, 'bid' => bid_order }
          end
        end
        nil
      end

      def reset_limit_orders
        @redis.del('orders')
      end

      def execute_transaction
        return unless transaction_possible?

        executed_orders = pop_matching_orders
        return unless executed_orders

        lunch_seller = Lita::User.find_by_id(executed_orders['ask']['user_id'])
        lunch_buyer = Lita::User.find_by_id(executed_orders['bid']['user_id'])
        karma_transfered = @karmanager.transfer_karma(
          lunch_buyer.id,
          lunch_seller.id,
          executed_orders['ask']['price'],
          check_limit: false
        )
        return unless karma_transfered
        lunch_transfered = @lunch_assigner.transfer_lunch(lunch_seller.mention_name, lunch_buyer.mention_name)
        if lunch_transfered
          sw = Lita::Services::SpreadsheetManager.new(ENV.fetch('GOOGLE_SP_DB_KEY'),'transactions')
          sw.insert_new_row([
            Time.now.strftime('%Y-%m-%d'),
            lunch_buyer.name,
            lunch_buyer.id,
            lunch_seller.name,
            lunch_seller.id,
            executed_orders['ask']['price']
          ])
        end
        {
          'buyer' => lunch_buyer,
          'seller' => lunch_seller,
          'timestamp' => Time.now,
          'bid_order' => executed_orders['bid'],
          'ask_order' => executed_orders['ask'],
          'price' => executed_orders['ask']['price']
        }
      end

      def transaction_possible?
        matching_orders.present?
      end

      private

      def build_new_order(user:, type:, created_at:, price:)
        {
          id: SecureRandom.uuid,
          user_id: user.id,
          type: type,
          created_at: created_at,
          price: price
        }
      end
    end
  end
end
