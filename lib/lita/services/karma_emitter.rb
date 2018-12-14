require 'redis'
module Lita
  module Services
    class KarmaEmitter
      attr_accessor :redis

      KARMA_LIMIT = 50

      def initialize(redis_instance, karmanager_instance)
        @redis = redis_instance
        @karmanager = karmanager_instance
        @ham = Lita::User.find_by_mention_name('ham')
      end

      def emit(users, acc = 0)
        users = users.select { |user| @karmanager.get_karma(user.id) < KARMA_LIMIT }
        karma_per_user = @karmanager.get_karma(@ham.id) / users.size
        save_last_emission_date if acc > 0
        return acc unless karma_per_user > 0

        users.each do |user|
          karma_to_emit = karma_to_emit(user, karma_per_user)
          acc += karma_to_emit
          @karmanager.transfer_karma(@ham.id, user.id, karma_to_emit, check_limit: false)
        end

        emit(users, acc)
      end

      def last_emission_date
        Date.parse(@redis.get('karma_emitter:last_emission_date') || '2000-01-01')
      end

      private

      def save_last_emission_date
        @redis.set('karma_emitter:last_emission_date', Date.today.to_s)
      end

      def karma_to_emit(user, karma_per_user)
        karma_to_emit = karma_per_user
        if @karmanager.get_karma(user.id) + karma_per_user > KARMA_LIMIT
          karma_to_emit = KARMA_LIMIT - @karmanager.get_karma(user.id)
        end
        karma_to_emit
      end
    end
  end
end
