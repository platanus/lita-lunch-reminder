module Lita
  module Services
    class SortedPicker
      def initialize(weighted_hash)
        raise NonPositiveKarmaError unless weighted_hash.values.all?(&:positive?)
        @weighted_hash = weighted_hash
        @total_elements = weighted_hash.count
      end

      def sample(n)
        raise NegativeSampleSize if n.negative?

        sorted_members = @weighted_hash.group_by { |_, v| v }
                                       .sort_by { |k, _| -k }
                                       .map { |group| group[1].shuffle.map(&:first) }
                                       .flatten

        sample_size = [n, @total_elements].min

        return [] if sample_size.zero?

        sorted_members[0..n - 1]
      end
    end

    class NonPositiveKarmaError < StandardError; end
    class NegativeSampleSize < StandardError; end
  end
end
