module Lita
  module Services
    class WeightedPicker
      def initialize(wager_hash, karma_hash)
        raise NonPositiveKarmaError unless wager_hash.values.all? { |value| value > 0 } &&
            karma_hash.values.all? { |value| value > 0 }
        @karma_hash = karma_hash
        @wager_hash = wager_hash
        @total_elements = wager_hash.count
      end

      def choose(n, hash = @wager_hash)
        sorted_hash = hash.sort_by { |_, points| -points }.to_h
        return hash.keys unless sorted_hash.size >= n
        tied_users = choose_tied_users(n, sorted_hash)
        loosers = choose_loosers(n, sorted_hash)
        winners = truncate(hash.size - tied_users.size - loosers.size, sorted_hash)
        tied_users = @karma_hash.slice(*tied_users.keys)
        winners.concat sample(n - winners.size, tied_users.to_h)
      end

      private

      def sample_one(hash)
        return if hash.empty?
        u = rand
        winner = cumulative_weighted_hash(hash).find { |k, _| k > u }.last
        winner
      end

      def sample(n, hash = @karma_hash)
        winners = []
        sample_size = [n, hash.count].min
        return winners if sample_size.zero?
        sample_size.times do
          winner = sample_one(hash.except(*winners))
          unless winner.nil? || winners.include?(winner)
            winners.push winner
          end
        end
        winners
      end

      def truncate(n, hash = @wager_hash)
        sample_size = [n, hash.count].min
        hash.sort_by { |_, points| -points }.to_a.first(sample_size).to_h.keys
      end

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
