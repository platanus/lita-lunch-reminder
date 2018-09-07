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

        Lita.register_handler(self)
      end
    end
  end
end
