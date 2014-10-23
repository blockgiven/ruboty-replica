module Ruboty
  module Handlers
    class Replica < Base
      env :HEROKU_API_KEY,  'heroku api key'
      env :HEROKU_APP_NAME, 'heroku app name'

      on /replica(?: to (?<new_owner>.*@.*))?/, name: 'replica', description: 'replicate itself'

      def replica(message)
        Ruboty::Replica::Actions::Replica.new(message).call
      end
    end
  end
end
