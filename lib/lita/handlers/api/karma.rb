# coding: utf-8

require 'json'

module Lita
  module Handlers
    module Api
      class Karma < Lita::Handlers::Api::ApiController
        def initialize(robot)
          super
          @karmanager = Lita::Services::Karmanager.new(redis)
          @assigner = Lita::Services::LunchAssigner.new(redis, @karmanager)
        end

        http.get '/karma/:user_id', :karma

        def karma(request, response)
          user_id = request.env['router.params'][:user_id]
          user = Lita::User.find_by_id(user_id)
          if user
            user_karma = @karmanager.get_karma(user_id)
            respond(response, karma: user_karma)
          else
            respond(response, status: 404, message: 'Usuario no encontrado')
          end
        end

        Lita.register_handler(self)
      end
    end
  end
end
