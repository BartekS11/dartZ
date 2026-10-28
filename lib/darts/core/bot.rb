require_relative "checkout_calculator"
require_relative "throw"

module Darts
  module Core
    class Bot
      MIN_LEVEL = 1
      MAX_LEVEL = 10
      DEFAULT_LEVEL = 5

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

      # Probabilities are per dart, not per visit. Level 10 targets strong club
      # scoring (roughly 90 before doubles), rather than professional accuracy.
      # Explicit profiles keep every step meaningful and easy to recalibrate.
      SKILL_PROFILES = [
        # single triple double bull  wild miss  decision
        [ 0.30, 0.01, 0.02, 0.01, 0.65, 0.08 ],
        [ 0.37, 0.03, 0.04, 0.02, 0.59, 0.17 ],
        [ 0.44, 0.06, 0.07, 0.04, 0.53, 0.26 ],
        [ 0.51, 0.09, 0.10, 0.06, 0.47, 0.35 ],
        [ 0.58, 0.13, 0.13, 0.08, 0.41, 0.44 ],
        [ 0.65, 0.17, 0.16, 0.10, 0.35, 0.53 ],
        [ 0.71, 0.21, 0.20, 0.12, 0.29, 0.63 ],
        [ 0.77, 0.25, 0.24, 0.15, 0.23, 0.73 ],
        [ 0.82, 0.29, 0.28, 0.18, 0.17, 0.83 ],
        [ 0.87, 0.33, 0.32, 0.21, 0.11, 0.93 ]
      ].map do |values|
        %i[single triple double bull wild_miss decision].zip(values).to_h.freeze
      end.freeze

      LEVEL_LABELS = {
        1 => "Rookie",
        2 => "Beginner",
        3 => "Casual",
        4 => "Improver",
        5 => "Regular",
        6 => "Club",
        7 => "League",
        8 => "Advanced club",
        9 => "Experienced club",
        10 => "Strong club"
      }.freeze

      class << self
        def normalize_level(level)
          level.to_i.clamp(MIN_LEVEL, MAX_LEVEL)
        end

        def play_turn(score:, level:, double_in: false, double_out: true, has_doubled_in: true)
          level = normalize_level(level)
          remaining = score
          throws = []
          in_play = !double_in || has_doubled_in

          3.times do |index|
            break if remaining <= 1

            darts_left = 3 - index
            pressure = pressure_score?(remaining)
            target = in_play ? select_target(remaining, level, darts_left, double_out: double_out) : opening_double_target(level)
            actual = resolve_throw(target, level, pressure: pressure)
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
          Throw.from_name(throw_name).to_attributes
        end

        private

        def pressure_score?(score)
          score <= 170
        end

        def select_target(score, level, darts_left, double_out: true)
          checkout = double_out ? CheckoutCalculator.suggest(score, darts_remaining: darts_left) : nil
          return checkout.first if checkout && !checkout.empty? && attempt_checkout_route?(level, score)
          return score > 60 ? high_scoring_target(score, level) : straight_out_target(score) unless double_out

          if score > 170
            high_scoring_target(score, level)
          elsif score > 60
            smart_decision?(level) ? setup_target(score, level) : casual_setup_target(score)
          else
            smart_decision?(level) ? finish_builder_target(score) : casual_setup_target(score)
          end
        end

        def attempt_checkout_route?(level, score)
          # Even beginners recognize a direct double; multi-dart routes and
          # odd-score setup shots increasingly depend on decision quality.
          return true if score == 50 || (score <= 40 && score.even?)

          smart_decision?(level)
        end

        def high_scoring_target(score, level)
          return "T19" if score == 181
          return "T18" if score == 182
          return "T17" if score == 183
          return "T20" if smart_decision?(level)

          [ "S20", "S19", "S18", "T19", "T18" ].sample
        end

        def skill_profile(level)
          SKILL_PROFILES.fetch(normalize_level(level) - 1)
        end

        def smart_decision?(level)
          rand < skill_profile(level).fetch(:decision)
        end

        def casual_setup_target(score)
          # A legal but less deliberate single, instead of always finding the
          # best double leave. Never deliberately overshoot the remaining score.
          "S#{rand(1..[20, score - 2].min)}"
        end

        def setup_target(score, level)
          preferred = [ 40, 32, 24, 16, 8 ]

          preferred.each do |leave|
            hit = score - leave
            next unless THROW_VALUES.value?(hit)

            return THROW_VALUES.key(hit)
          end

          return "T20" if score >= 100 && level >= 6
          return "T19" if score >= 95 && level >= 4
          return "S20" if score > 80

          finish_builder_target(score)
        end

        def finish_builder_target(score)
          return "Bull" if score == 50
          return "25" if score == 25
          return "D#{score / 2}" if score.even? && score <= 40

          if score > 40
            checkout = CheckoutCalculator.suggest(score, darts_remaining: 3)
            return checkout.first if checkout && !checkout.empty?
          end

          singles = [ 1, 3, 5, 7, 9, 11, 13, 15, 17, 19 ]
          leave = singles.find { |single| score - single <= 40 && (score - single).even? && score - single > 0 }
          return "S#{leave}" if leave

          "S1"
        end

        def resolve_throw(target, level, pressure: false)
          ring, number = parse_target(target)
          return miss_or_single_bull(level, pressure: pressure) if ring == :bull

          roll = rand
          hit_chance = hit_probability(ring, level, pressure: pressure)

          return target if roll < hit_chance
          return ring_falloff(ring, number, level) if roll < hit_chance + secondary_probability(ring, level)

          wild_miss(number, level)
        end

        def hit_probability(ring, level, pressure: false)
          base = skill_profile(level).fetch(ring, 0.0)
          # Beginners lose more composure near a finish; club players still
          # experience pressure, rather than becoming more accurate under it.
          base *= 0.72 + normalize_level(level) * 0.025 if pressure && %i[triple double bull].include?(ring)
          base
        end

        def secondary_probability(ring, level)
          case ring
          when :triple then 0.20 + (level * 0.025)
          when :double then 0.18 + (level * 0.02)
          when :single then 0.14 - (level * 0.005)
          else 0.10
          end.clamp(0.06, 0.48)
        end

        def ring_falloff(ring, number, level)
          case ring
          when :triple
            rand < 0.72 ? "S#{number}" : "T#{NEIGHBORS[number].sample}"
          when :double
            rand < 0.75 ? "S#{number}" : "D#{NEIGHBORS[number].sample}"
          when :single
            rand < (0.78 + level * 0.01) ? "S#{NEIGHBORS[number].sample}" : "MISS"
          else
            miss_or_single_bull(level)
          end
        end

        def wild_miss(number, level)
          return "MISS" if rand < skill_profile(level).fetch(:wild_miss)
          return "S#{number}" if rand < 0.65

          neighbor = NEIGHBORS[number].sample
          rand < 0.8 ? "S#{neighbor}" : "D#{neighbor}"
        end

        def miss_or_single_bull(level, pressure: false)
          roll = rand
          bull_chance = hit_probability(:bull, level, pressure: pressure)
          return "Bull" if roll < bull_chance
          return "25" if roll < bull_chance + 0.20 + level * 0.025

          "MISS"
        end

        def opening_double_target(level)
          return "D20" if level >= 6

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
  end
end
