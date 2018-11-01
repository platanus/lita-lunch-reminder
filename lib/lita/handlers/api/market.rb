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
              respond(response, status: 403, message: 'Any transaction possible')
            end
            respond(response, success: true, orders: executed_orders.to_json)
          end
        end

        def place_limit_order(request, response)
          return respond_not_authorized(response) unless authorized?(request)
          user = current_user(request)
          type = request.params['type']
          if user
            limit_order = add_limit_order(user, type)
            if limit_order
              respond(response, success: true, order: limit_order)
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

        def add_limit_order(user, type)
          order = limit_order_for_user(user, type)
          has_lunch = winning_list.include?(user.mention_name)
          if (has_lunch && type == 'ask') || (!has_lunch && type == 'bid')
            return order if market_manager.add_limit_order(order)
          end
        end

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
