module Darts
  module Core
    class Throw
      MULTIPLIERS = {
        "miss" => 0,
        "single" => 1,
        "double" => 2,
        "triple" => 3
      }.freeze

      attr_reader :segment, :multiplier

      def self.from_name(name)
        return new(segment: 0, multiplier: "miss") if name == "MISS"
        return new(segment: 25, multiplier: "double") if name == "Bull"
        return new(segment: 25, multiplier: "single") if name == "25"

        prefix = name.to_s[0]
        segment = name.to_s[1..].to_i
        multiplier = case prefix
        when "T" then "triple"
        when "D" then "double"
        else "single"
        end

        new(segment: segment, multiplier: multiplier)
      end

      def initialize(segment:, multiplier:)
        @segment = segment.to_i
        @multiplier = multiplier.to_s
        validate!
      end

      def points
        return 0 if multiplier == "miss" || segment.zero?

        segment * MULTIPLIERS.fetch(multiplier)
      end

      def double?
        multiplier == "double"
      end

      def bull?
        segment == 25
      end

      def miss?
        segment.zero? || multiplier == "miss"
      end

      def to_attributes
        { segment: segment, multiplier: multiplier }
      end

      def name
        return "MISS" if miss?
        return "Bull" if segment == 25 && multiplier == "double"
        return "25" if segment == 25

        prefix = { "single" => "S", "double" => "D", "triple" => "T" }.fetch(multiplier)
        "#{prefix}#{segment}"
      end

      private

      def validate!
        raise ArgumentError, "invalid segment" unless ([ 0 ] + (1..20).to_a + [ 25 ]).include?(segment)
        raise ArgumentError, "invalid multiplier" unless MULTIPLIERS.key?(multiplier)
        raise ArgumentError, "bull can only be single or double" if segment == 25 && !%w[single double].include?(multiplier)
        raise ArgumentError, "miss must use segment 0" if multiplier == "miss" && !segment.zero?
      end
    end
  end
end
