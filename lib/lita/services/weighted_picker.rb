module Lita
  module Services
    class WeightedPicker
      def initialize(karma_hash)
        raise NonPositiveKarmaError unless karma_hash.values.all?(&:positive?)
        @karma_hash = karma_hash
        @current_lunchers_count = karma_hash.count
      end

      def sample_one
        return if @karma_hash.empty?

        u = rand
        winner = cumulative_karma_hash.find { |k, _| k > u }.last
        remove(winner)
      end

      def sample(n)
        winners = []

        sample_size = [n, @current_lunchers_count].min

        return winners if sample_size.zero?

        sample_size.times do
          winner = sample_one
          unless winner.nil? || winners.include?(winner)
            winners.push winner
          end
        end

        winners
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
