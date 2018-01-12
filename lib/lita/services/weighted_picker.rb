module Lita
  module Services
    class WeightedPicker
      def initialize(karma_hash)
        raise NonPositiveKarmaError unless karma_hash.values.all?(&:positive?)
        @karma_hash = karma_hash
      end

      def sample
        return if @karma_hash.empty?

        u = rand
        winner = cumulative_karma_hash.find { |k, _| k > u }.last
        remove(winner)
      end

      private

      def cumulative_karma_hash
        total_karma = @karma_hash.values.reduce(0, :+).to_f
        u = 0.0
        @karma_hash.map { |k, v| [u += v / total_karma, k] }.to_h
      end

      def min
        @karma_hash.values.min
      end

      def max
        @karma_hash.values.max
      end

      def remove(winner)
        @karma_hash = @karma_hash.reject { |k, _| k == winner }
        winner
      end
    end

    class NonPositiveKarmaError < StandardError; end
  end
end
