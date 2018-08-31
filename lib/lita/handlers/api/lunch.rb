# coding: utf-8

require 'json'

module Lita
  module Handlers
    module Api
      class Lunch < Lita::Handlers::Api::ApiController
        def initialize(robot)
          super
          @karmanager = Lita::Services::Karmanager.new(redis)
          @assigner = Lita::Services::LunchAssigner.new(redis, @karmanager)
        end

        http.get '/winning_lunchers', :winning_lunchers
        http.get '/current_lunchers', :current_lunchers
        http.post '/current_lunchers', :opt_in

        def winning_lunchers(_request, response)
          list = @assigner.winning_lunchers_list
          respond(response, winning_lunchers: list)
        end

        def current_lunchers(_request, response)
          list = @assigner.current_lunchers_list
          respond(response, current_lunchers: list)
        end

        def opt_in(request, response)
          user_id = JSON.parse(request.body.read)['user_id']
          user = Lita::User.find_by_id(user_id) if user_id
          if user
            @assigner.add_to_current_lunchers(user.mention_name)
            respond(response, success: true)
          else
            respond(response, status: 404, message: 'Usuario no encontrado')
          end
        end

        Lita.register_handler(self)
      end
    end
  end
end
