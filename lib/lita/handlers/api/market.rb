# coding: utf-8

require 'json'

module Lita
  module Handlers
    module Api
      class Market < Lita::Handlers::Api::ApiController
        namespace 'lunch_reminder'

        def initialize(robot)
          super
          @karmanager = Lita::Services::Karmanager.new(redis)
          @assigner = Lita::Services::LunchAssigner.new(redis, @karmanager)
          @market_manager = Lita::Services::MarketManager.new(redis, @assigner, @karmanager)
        end

        http.get 'market/limit_orders', :limit_orders
        http.post 'market/limit_orders', :place_limit_order
        http.post 'market/market_orders', :place_market_order

        def limit_orders(request, response)
          return respond_not_authorized(response) unless authorized?(request)
          orders = @market_manager.orders
          respond(response, limit_orders: orders)
        end

        def place_limit_order(request, response)
          return respond_not_authorized(response) unless authorized?(request)
          user = Lita::User.find_by_id(request.params[:user_id])
          body = request.body.read
          if user
            if winning_list.include?(user.mention_name) && @market_manager.add_limit_order(body)
              respond(response, success: true)
            end
          else
            response.status = 404
            respond(response, status: 404, message: 'Error in parameters')
          end
        end

        def place_market_order(request, response)
          return respond_not_authorized(response) unless authorized?(request)
          user = Lita::User.find_by_id(request.params[:user_id])

          if user
            if !winning_list.include?(user.mention_name) && @market_manager.add_market_order(user.id)
              respond(response, success: true)
            else
              respond(response, status: 403, message: 'User can\'t place market order')
            end
          else
            response.status = 404
            respond(response, status: 404, message: 'Error in parameters')
          end
        end

        Lita.register_handler(self)

        private

        def winning_list
          @winning_list ||= @assigner.winning_lunchers_list
        end
      end
    end
  end
end
