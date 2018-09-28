# coding: utf-8

require 'json'

module Lita
  module Handlers
    module Api
      class Lunch < Lita::Handlers::Api::ApiController
        namespace 'lunch_reminder'

        def initialize(robot)
          super
          @karmanager = Lita::Services::Karmanager.new(redis)
          @assigner = Lita::Services::LunchAssigner.new(redis, @karmanager)
        end

        http.get '/winning_lunchers', :winning_lunchers
        http.get '/current_lunchers', :current_lunchers
        http.post '/current_lunchers', :opt_in
        http.post '/lunches/transfer', :transfer

        def winning_lunchers(request, response)
          return respond_not_authorized(response) unless authorized?(request)
          list = @assigner.winning_lunchers_list
          respond(response, winning_lunchers: list)
        end

        def current_lunchers(request, response)
          return respond_not_authorized(response) unless authorized?(request)
          list = @assigner.current_lunchers_list
          respond(response, current_lunchers: list)
        end

        def opt_in(request, response)
          return respond_not_authorized(response) unless authorized?(request)
          user = Lita::User.find_by_id(request.params[:user_id])
          @assigner.add_to_current_lunchers(user.mention_name) if user
          respond(response, success: true) if user
        end

        def transfer(request, response)
          return respond_not_authorized(response) unless authorized?(request)
          body = JSON.parse(request.body.read)
          sender = Lita::User.find_by_id(request.params[:user_id])
          receiver = Lita::User.find_by_mention_name(body['receiver'])
          if sender && receiver
            if @assigner.remove_from_winning_lunchers(sender.mention_name)
              @assigner.add_to_winning_lunchers(receiver.mention_name)
              respond(response, success: true)
            else
              respond(response, status: 404, message: 'User not in winning lunchers')
            end
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
