module Lita
  module Handlers
    module Api
      class ApiController
        extend Lita::Handler::HTTPRouter

        def respond(response, body)
          response.headers['Content-Type'] = 'application/json'
          response.body << body.to_json
          redis.call(["client", "kill", "type", "normal"])
        end

        def respond_not_authorized(response)
          response.status = 401
          respond(response, status: 401, message: 'Not authorized')
        end

        def authorized?(request)
          user_id = request.params[:user_id]
          user = Lita::User.find_by_id(user_id)
          !user.nil?
        end

        def current_user(request)
          Lita::User.find_by_id(request.params[:user_id])
        end

        Lita.register_handler(self)
      end
    end
  end
end
