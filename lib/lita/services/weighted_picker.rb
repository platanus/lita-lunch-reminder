module Lita
  module Services
    class WeightedPicker
      def initialize(weighted_hash)
        raise NonPositiveKarmaError unless weighted_hash.values.all? { |v| v > 0 }
        @weighted_hash = weighted_hash
        @total_elements = weighted_hash.count
      end

      def sample_one(hash)
        return if hash.empty?

        u = rand
        winner = cumulative_weighted_hash(hash).find { |k, _| k > u }.last
        winner
      end

      def sample(n, hash = @weighted_hash)
        winners = []

        sample_size = [n, @total_elements].min

        return winners if sample_size.zero?

        sample_size.times do
          winner = sample_one(hash.except(*winners))
          unless winner.nil? || winners.include?(winner)
            winners.push winner
          end
        end

        winners
      end

      def truncate(n, hash = @weighted_hash)
        sample_size = [n, @total_elements].min
        hash.sort_by { |_, points| -points }.to_a.first(sample_size).to_h.keys
      end

      def choose(n, hash = @weighted_hash)
        sorted_hash = hash.sort_by { |_, points| -points }.to_h
        return hash.keys unless sorted_hash.size >= n
        tied_users = choose_tied_users(n, sorted_hash)
        loosers = choose_loosers(n, sorted_hash)
        winners = truncate(hash.size - tied_users.size - loosers.size, sorted_hash)
        winners.concat sample(n - winners.size, tied_users.to_h)
      end

      private

      def choose_loosers(n, sorted_hash)
        reference_user = sorted_hash.to_a[n - 1]
        sorted_hash.select { |_, karma| karma < reference_user[1] }
      end

      def choose_tied_users(n, sorted_hash)
        reference_user = sorted_hash.to_a[n - 1]
        sorted_hash.select { |_, karma| karma == reference_user[1] }
      end

      def cumulative_weighted_hash(hash)
        total_points = hash.values.reduce(0, :+).to_f
        u = 0.0
        hash.map { |k, v| [u += v / total_points, k] }.to_h
      end
    end

    class NonPositiveKarmaError < StandardError; end
  end
end
