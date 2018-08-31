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

        http.get '/karma', :karma

        def karma(request, response)
          return respond_not_authorized(response) unless authorized?(request)
          user = Lita::User.find_by_id(request.params[:user_id])
          if user
            user_karma = @karmanager.get_karma(user.id)
            respond(response, karma: user_karma)
          end
        end

        Lita.register_handler(self)
      end
    end
  end
end
