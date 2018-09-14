# coding: utf-8

require 'json'

module Lita
  module Handlers
    module Api
      class Karma < Lita::Handlers::Api::ApiController
        namespace 'lunch_reminder'

        def initialize(robot)
          super
          @karmanager = Lita::Services::Karmanager.new(redis)
          @assigner = Lita::Services::LunchAssigner.new(redis, @karmanager)
        end

        http.get '/karma', :karma
        http.post '/karma/transfer', :transfer

        def karma(request, response)
          return respond_not_authorized(response) unless authorized?(request)
          user = Lita::User.find_by_id(request.params[:user_id])
          if user
            user_karma = @karmanager.get_karma(user.id)
            respond(response, karma: user_karma)
          end
        end

        def transfer(request, response)
          return respond_not_authorized(response) unless authorized?(request)
          body = JSON.parse(request.body.read)
          user = Lita::User.find_by_id(request.params[:user_id])
          receiver = Lita::User.find_by_id(body['receiver_id'])
          karma_amount = body['karma_amount']
          if user && receiver && karma_amount
            @karmanager.transfer_karma(user.id, receiver.id, karma_amount)
            respond(response, success: true)
          else
            response.status = 404
            respond(response, status: 404, message: 'Error in parameters')
          end
        end

        Lita.register_handler(self)
      end
    end
  end
end
