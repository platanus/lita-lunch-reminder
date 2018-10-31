# coding: utf-8

require 'json'

module Lita
  module Handlers
    module Api
      class Market < Lita::Handlers::Api::ApiController
        namespace 'lunch_reminder'

        def initialize(robot)
          super
        end

        http.get 'market/limit_orders', :limit_orders
        http.post 'market/limit_orders', :place_limit_order
        http.post 'market/execute_transaction', :execute_transaction

        def limit_orders(request, response)
          return respond_not_authorized(response) unless authorized?(request)
          orders = market_manager.orders
          respond(response, limit_orders: orders)
        end

        def execute_transaction(request, response)
          return respond_not_authorized(response) unless authorized?(request)
          user = current_user(request)
          if user
            executed_orders = market_manager.execute_transaction
            unless executed_orders
              response.status = 403
              respond(response, status: 403, message: 'Can not place order')
            end
            respond(response, success: true, orders: executed_orders.to_json)
          end
        end

        def place_limit_order(request, response)
          return respond_not_authorized(response) unless authorized?(request)
          user = current_user(request)
          order = limit_order_for_user(user, 'ask')
          if user
            if winning_list.include?(user.mention_name) && market_manager.add_limit_order(order)
              respond(response, success: true, order: order)
            else
              response.status = 403
              respond(response, status: 403, message: 'Can not place order')
            end
          else
            response.status = 404
            respond(response, status: 404, message: 'Error in parameters')
          end
        end

        Lita.register_handler(self)

        private

        def limit_order_for_user(user, type)
          {
            id: SecureRandom.uuid,
            user_id: user.id,
            type: type,
            created_at: Time.now
          }.to_json
        end

        def winning_list
          @winning_list ||= assigner.winning_lunchers_list
        end

        def market_manager
          @market_manager ||= Lita::Services::MarketManager.new(redis, assigner, karmanager)
        end

        def karmanager
          @karmanager ||= Lita::Services::Karmanager.new(redis)
        end

        def assigner
          @assigner ||= Lita::Services::LunchAssigner.new(redis, karmanager)
        end
      end
    end
  end
end
