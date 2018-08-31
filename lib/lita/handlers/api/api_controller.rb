module Lita
  module Handlers
    module Api
      class ApiController
        extend Lita::Handler::HTTPRouter

        def respond(response, body)
          response.headers['Content-Type'] = 'application/json'
          response.body << body.to_json
        end

        Lita.register_handler(self)
      end
    end
  end
end
