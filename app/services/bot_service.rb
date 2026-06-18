class BotService
  THROW_VALUES = {
    "MISS" => 0,
    "Bull" => 50,
    "25"   => 25
  }.merge(
    (1..20).flat_map { |n| [ [ "S#{n}", n ], [ "D#{n}", n * 2 ], [ "T#{n}", n * 3 ] ] }.to_h
  ).freeze

  NEIGHBORS = {
    20 => [ 1, 5 ], 1 => [ 20, 18 ], 18 => [ 1, 4 ], 4 => [ 18, 13 ], 13 => [ 4, 6 ],
    6 => [ 13, 10 ], 10 => [ 6, 15 ], 15 => [ 10, 2 ], 2 => [ 15, 17 ], 17 => [ 2, 3 ],
    3 => [ 17, 19 ], 19 => [ 3, 7 ], 7 => [ 19, 16 ], 16 => [ 7, 8 ], 8 => [ 16, 11 ],
    11 => [ 8, 14 ], 14 => [ 11, 9 ], 9 => [ 14, 12 ], 12 => [ 9, 5 ], 5 => [ 12, 20 ]
  }.freeze

  class << self
    def play_turn(score:, level:, double_in: false, double_out: true, has_doubled_in: true)
      remaining = score
      throws = []
      in_play = !double_in || has_doubled_in

      3.times do |index|
        break if remaining <= 1

        darts_left = 3 - index
        target = in_play ? select_target(remaining, level, darts_left, double_out: double_out) : opening_double_target(level)
        actual = resolve_throw(target, level)
        throws << actual

        unless in_play || double_throw?(actual)
          next
        end

        in_play = true
        points = points_for(actual)

        break if bust?(remaining, points, actual, double_out: double_out)

        remaining -= points
        break if remaining.zero?
      end

      { "throws" => throws, "remaining" => remaining }
    end

    def throw_to_attributes(throw_name)
      return { segment: 0, multiplier: "miss" } if throw_name == "MISS"
      return { segment: 25, multiplier: "double" } if throw_name == "Bull"
      return { segment: 25, multiplier: "single" } if throw_name == "25"

      prefix = throw_name[0]
      segment = throw_name[1..].to_i
      multiplier = case prefix
      when "T" then "triple"
      when "D" then "double"
      else "single"
      end

      { segment: segment, multiplier: multiplier }
    end

    private

    def select_target(score, level, darts_left, double_out: true)
      checkout = double_out ? CheckoutCalculator.suggest(score, darts_remaining: darts_left) : nil
      return checkout.first if checkout.present?
      return straight_out_target(score) unless double_out

      if score > 170
        high_scoring_target(score, level)
      elsif score > 60
        setup_target(score, level)
      else
        finish_builder_target(score)
      end
    end

    def high_scoring_target(score, level)
      return "T19" if score == 181
      return "T18" if score == 182
      return "T17" if score == 183
      return "T20" if level >= 8

      [ "T20", "S20", "T19", "S19", "T18" ].sample
    end

    def setup_target(score, level)
      preferred = [ 40, 32, 24, 16, 8 ]

      preferred.each do |leave|
        hit = score - leave
        next unless THROW_VALUES.value?(hit)

        return THROW_VALUES.key(hit)
      end

      return "T20" if score >= 100 && level >= 10
      return "T19" if score >= 95 && level >= 7
      return "S20" if score > 80

      finish_builder_target(score)
    end

    def finish_builder_target(score)
      return "Bull" if score == 50
      return "25" if score == 25
      return "D#{score / 2}" if score.even? && score <= 40

      if score > 40
        checkout = CheckoutCalculator.suggest(score, darts_remaining: 3)
        return checkout.first if checkout.present?
      end

      singles = [ 1, 3, 5, 7, 9, 11, 13, 15, 17, 19 ]
      leave = singles.find { |single| score - single <= 40 && (score - single).even? && score - single > 0 }
      return "S#{leave}" if leave

      "S1"
    end

    def resolve_throw(target, level)
      ring, number = parse_target(target)
      return miss_or_single_bull(level) if ring == :bull

      roll = rand
      hit_chance = hit_probability(ring, level)

      return target if roll < hit_chance
      return ring_falloff(ring, number, level) if roll < hit_chance + secondary_probability(ring, level)

      wild_miss(number, level)
    end

    def hit_probability(ring, level)
      base = case ring
      when :triple then 0.14 + (level * 0.028)
      when :double then 0.12 + (level * 0.025)
      when :single then 0.45 + (level * 0.022)
      else 0.20 + (level * 0.02)
      end

      [ [ base, 0.94 ].min, 0.05 ].max
    end

    def secondary_probability(ring, level)
      case ring
      when :triple then 0.30 - (level * 0.006)
      when :double then 0.24 - (level * 0.004)
      when :single then 0.22 - (level * 0.004)
      else 0.10
      end.clamp(0.06, 0.30)
    end

    def ring_falloff(ring, number, level)
      case ring
      when :triple
        rand < 0.72 ? "S#{number}" : "T#{NEIGHBORS[number].sample}"
      when :double
        rand < 0.75 ? "S#{number}" : "D#{NEIGHBORS[number].sample}"
      when :single
        rand < (0.78 + level * 0.005) ? "S#{NEIGHBORS[number].sample}" : "MISS"
      else
        miss_or_single_bull(level)
      end
    end

    def wild_miss(number, level)
      return "MISS" if rand < (0.45 - level * 0.01).clamp(0.12, 0.45)
      return "S#{number}" if rand < 0.65

      neighbor = NEIGHBORS[number].sample
      rand < 0.8 ? "S#{neighbor}" : "D#{neighbor}"
    end

    def miss_or_single_bull(level)
      roll = rand
      return "Bull" if roll < (0.08 + level * 0.02).clamp(0.08, 0.45)
      return "25" if roll < 0.78

      "MISS"
    end

    def opening_double_target(level)
      return "D20" if level >= 8

      [ "D20", "D16", "D12", "D10" ].sample
    end

    def straight_out_target(score)
      return THROW_VALUES.key(score) if THROW_VALUES.value?(score)

      finish_builder_target(score)
    end

    def bust?(score, points, throw_name, double_out: true)
      new_score = score - points
      return true if new_score < 0 || new_score == 1
      return false unless new_score.zero?
      return false unless double_out

      !double_throw?(throw_name)
    end

    def legacy_bust?(score, points, throw_name)
      bust?(score, points, throw_name, double_out: true)
    end

    def double_throw?(throw_name)
      throw_name == "Bull" || throw_name.start_with?("D")
    end

    def points_for(throw_name)
      THROW_VALUES.fetch(throw_name, 0)
    end

    def parse_target(target)
      return [ :bull, 25 ] if target == "Bull" || target == "25"
      return [ :miss, 0 ] if target == "MISS"

      ring = case target[0]
      when "T" then :triple
      when "D" then :double
      else :single
      end

      [ ring, target[1..].to_i ]
    end
  end
end
