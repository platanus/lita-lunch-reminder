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
        http.post 'market/market_orders', :place_market_order

        def limit_orders(request, response)
          return respond_not_authorized(response) unless authorized?(request)
          orders = market_manager.orders
          respond(response, limit_orders: orders)
        end

        def place_limit_order(request, response)
          return respond_not_authorized(response) unless authorized?(request)
          user = current_user(request)
          order = limit_order_for_user(user)
          if user
            if winning_list.include?(user.mention_name) && market_manager.add_limit_order(order)
              respond(response, success: true, order: order)
            end
          else
            response.status = 404
            respond(response, status: 404, message: 'Error in parameters')
          end
        end

        def place_market_order(request, response)
          return respond_not_authorized(response) unless authorized?(request)
          user = current_user(request)
          if user
            if !winning_list.include?(user.mention_name) && market_manager.add_market_order(user.id)
              respond(response, success: true)
            end
          else
            response.status = 404
            respond(response, status: 404, message: 'Error in parameters')
          end
        end

        Lita.register_handler(self)

        private

        def limit_order_for_user(user)
          {
            id: SecureRandom.uuid,
            user_id: user.id,
            type: 'limit',
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
