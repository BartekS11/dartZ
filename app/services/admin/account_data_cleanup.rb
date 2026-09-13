module Admin
  class AccountDataCleanup
    class Error < StandardError; end
    class ConfirmationError < Error; end
    class NoEligibleData < Error; end
    class InvalidTransition < Error; end
    class RestoreConflict < Error; end

    ELIGIBLE_TRAINING_STATUSES = %w[completed abandoned].freeze
    ELIGIBLE_PLAN_STATUSES = %w[completed archived].freeze
    ELIGIBLE_TOURNAMENT_STATUSES = %w[complete archived].freeze

    class << self
      def clear!(user:, admin_user:, categories:, reason:, confirmation_email:, acknowledged:)
        selected = normalize_categories(categories)
        validate_confirmation!(user, reason, confirmation_email, acknowledged)

        ApplicationRecord.transaction do
          user.lock!
          cleanup = user.admin_data_cleanups.create!(
            categories: selected,
            counts: {},
            status: "cleared",
            cleared_at: Time.current
          )
          counts = clear_categories!(cleanup, selected)
          raise NoEligibleData, "No eligible data was found in the selected categories." if counts.values.sum.zero?

          cleanup.update!(counts: counts)
          record_event!(cleanup, admin_user, "clear", reason)
          cleanup
        end
      end

      def restore!(cleanup:, admin_user:, reason:, confirmation_email:, acknowledged:)
        validate_confirmation!(cleanup.user, reason, confirmation_email, acknowledged)

        ApplicationRecord.transaction do
          cleanup.lock!
          cleanup.user.lock!
          raise InvalidTransition, "Only a cleared batch can be restored." unless cleanup.cleared?

          validate_batch_integrity!(cleanup)
          validate_restore_conflicts!(cleanup)
          restore_categories!(cleanup)
          cleanup.update!(status: "restored", restored_at: Time.current)
          record_event!(cleanup, admin_user, "restore", reason)
          cleanup
        end
      rescue ActiveRecord::RecordNotUnique
        raise RestoreConflict, "Restore blocked by newer custom training drill or dart setup data."
      end

      def purge!(cleanup:, admin_user:, reason:, confirmation_email:, acknowledged:)
        validate_confirmation!(cleanup.user, reason, confirmation_email, acknowledged)

        ApplicationRecord.transaction do
          cleanup.lock!
          cleanup.user.lock!
          raise InvalidTransition, "Only a cleared batch can be permanently purged." unless cleanup.cleared?

          validate_batch_integrity!(cleanup)
          purge_categories!(cleanup)
          cleanup.update!(status: "purged", purged_at: Time.current)
          record_event!(cleanup, admin_user, "purge", reason)
          cleanup
        end
      end

      private

      def normalize_categories(categories)
        values = Array(categories).map(&:to_s).uniq
        values = AdminDataCleanup::CATEGORIES if values.include?("all")
        unsupported = values - AdminDataCleanup::CATEGORIES
        raise Error, "Select at least one data category." if values.empty?
        raise Error, "Unsupported data category." if unsupported.any?

        AdminDataCleanup::CATEGORIES.select { |category| values.include?(category) }
      end

      def validate_confirmation!(user, reason, confirmation_email, acknowledged)
        raise ConfirmationError, "Enter the user's email address exactly." unless confirmation_email.to_s == user.email_address
        raise ConfirmationError, "A reason is required." if reason.to_s.strip.blank?
        raise ConfirmationError, "Complete the second confirmation step." unless ActiveModel::Type::Boolean.new.cast(acknowledged)
        raise ConfirmationError, "Reason is too long." if reason.to_s.length > 2000
      end

      def clear_categories!(cleanup, categories)
        categories.index_with { |category| send("clear_#{category}!", cleanup) }
      end

      def clear_matches!(cleanup)
        players = Player.joins(:match).where(user_id: cleanup.user_id, admin_data_cleanup_id: nil)
          .where.not(matches: { finished_at: nil })
        count = players.distinct.count(:match_id)
        players.update_all(user_id: nil, admin_data_cleanup_id: cleanup.id, updated_at: Time.current)
        count
      end

      def clear_training_sessions!(cleanup)
        records = TrainingSession.where(user_id: cleanup.user_id, admin_data_cleanup_id: nil, status: ELIGIBLE_TRAINING_STATUSES)
        count = records.count
        records.update_all(admin_data_cleanup_id: cleanup.id, updated_at: Time.current)
        count
      end

      def clear_practice_plans!(cleanup)
        records = PracticePlan.where(user_id: cleanup.user_id, admin_data_cleanup_id: nil, status: ELIGIBLE_PLAN_STATUSES)
        count = records.count
        records.update_all(admin_data_cleanup_id: cleanup.id, updated_at: Time.current)
        count
      end

      def clear_training_drills!(cleanup)
        records = TrainingDrill.where(user_id: cleanup.user_id, admin_data_cleanup_id: nil)
        count = records.count
        records.update_all(admin_data_cleanup_id: cleanup.id, updated_at: Time.current)
        count
      end

      def clear_dart_setup!(cleanup)
        records = DartSetup.where(user_id: cleanup.user_id, admin_data_cleanup_id: nil)
        count = records.count
        records.update_all(admin_data_cleanup_id: cleanup.id, updated_at: Time.current)
        count
      end

      def clear_tournaments!(cleanup)
        eligible = Tournament.where(status: ELIGIBLE_TOURNAMENT_STATUSES)
        owned_ids = eligible.where(owner_user_id: cleanup.user_id, owner_admin_data_cleanup_id: nil).pluck(:id)
        entered_ids = eligible.joins(:entries)
          .where(tournament_entries: { user_id: cleanup.user_id, admin_data_cleanup_id: nil }).distinct.pluck(:id)
        tournament_ids = (owned_ids + entered_ids).uniq

        Tournament.where(id: owned_ids).update_all(
          owner_user_id: nil, owner_admin_data_cleanup_id: cleanup.id, updated_at: Time.current
        )
        TournamentEntry.where(tournament_id: tournament_ids, user_id: cleanup.user_id, admin_data_cleanup_id: nil).update_all(
          user_id: nil, admin_data_cleanup_id: cleanup.id, updated_at: Time.current
        )
        tournament_ids.size
      end

      def validate_batch_integrity!(cleanup)
        actual = {
          "matches" => Player.where(admin_data_cleanup_id: cleanup.id, user_id: nil).distinct.count(:match_id),
          "training_sessions" => TrainingSession.where(admin_data_cleanup_id: cleanup.id, user_id: cleanup.user_id).count,
          "practice_plans" => PracticePlan.where(admin_data_cleanup_id: cleanup.id, user_id: cleanup.user_id).count,
          "training_drills" => TrainingDrill.where(admin_data_cleanup_id: cleanup.id, user_id: cleanup.user_id).count,
          "dart_setup" => DartSetup.where(admin_data_cleanup_id: cleanup.id, user_id: cleanup.user_id).count,
          "tournaments" => cleared_tournament_count(cleanup)
        }
        expected = cleanup.categories.index_with { |category| cleanup.counts.fetch(category, 0).to_i }
        return if actual.slice(*cleanup.categories) == expected

        raise Error, "Cleanup batch data changed unexpectedly; no action was applied."
      end

      def cleared_tournament_count(cleanup)
        owner_ids = Tournament.where(owner_admin_data_cleanup_id: cleanup.id, owner_user_id: nil).pluck(:id)
        entry_ids = TournamentEntry.where(admin_data_cleanup_id: cleanup.id, user_id: nil).distinct.pluck(:tournament_id)
        (owner_ids + entry_ids).uniq.size
      end

      def validate_restore_conflicts!(cleanup)
        drill_names = TrainingDrill.where(admin_data_cleanup_id: cleanup.id).pluck(:name)
        drill_conflict = TrainingDrill.where(user_id: cleanup.user_id, admin_data_cleanup_id: nil, name: drill_names).exists?
        setup_conflict = DartSetup.where(admin_data_cleanup_id: cleanup.id).exists? &&
          DartSetup.where(user_id: cleanup.user_id, admin_data_cleanup_id: nil).exists?
        conflicts = []
        conflicts << "custom training drill" if drill_conflict
        conflicts << "dart setup" if setup_conflict
        return if conflicts.empty?

        raise RestoreConflict, "Restore blocked by newer #{conflicts.to_sentence} data."
      end

      def restore_categories!(cleanup)
        user_id = cleanup.user_id
        Player.where(admin_data_cleanup_id: cleanup.id, user_id: nil)
          .update_all(user_id: user_id, admin_data_cleanup_id: nil, updated_at: Time.current)
        TrainingSession.where(admin_data_cleanup_id: cleanup.id, user_id: user_id)
          .update_all(admin_data_cleanup_id: nil, updated_at: Time.current)
        PracticePlan.where(admin_data_cleanup_id: cleanup.id, user_id: user_id)
          .update_all(admin_data_cleanup_id: nil, updated_at: Time.current)
        TrainingDrill.where(admin_data_cleanup_id: cleanup.id, user_id: user_id)
          .update_all(admin_data_cleanup_id: nil, updated_at: Time.current)
        DartSetup.where(admin_data_cleanup_id: cleanup.id, user_id: user_id)
          .update_all(admin_data_cleanup_id: nil, updated_at: Time.current)
        Tournament.where(owner_admin_data_cleanup_id: cleanup.id, owner_user_id: nil)
          .update_all(owner_user_id: user_id, owner_admin_data_cleanup_id: nil, updated_at: Time.current)
        TournamentEntry.where(admin_data_cleanup_id: cleanup.id, user_id: nil)
          .update_all(user_id: user_id, admin_data_cleanup_id: nil, updated_at: Time.current)
      end

      def purge_categories!(cleanup)
        PracticePlan.where(admin_data_cleanup_id: cleanup.id).destroy_all

        session_ids = TrainingSession.where(admin_data_cleanup_id: cleanup.id).pluck(:id)
        PracticePlanTaskEvent.where(training_session_id: session_ids).update_all(training_session_id: nil) if session_ids.any?
        TrainingSession.where(id: session_ids).destroy_all

        TrainingDrill.where(admin_data_cleanup_id: cleanup.id).destroy_all

        setup_ids = DartSetup.where(admin_data_cleanup_id: cleanup.id).pluck(:id)
        Player.where(dart_setup_id: setup_ids).update_all(dart_setup_id: nil, updated_at: Time.current) if setup_ids.any?
        DartSetup.where(id: setup_ids).destroy_all

        Player.where(admin_data_cleanup_id: cleanup.id, user_id: nil)
          .update_all(admin_data_cleanup_id: nil, updated_at: Time.current)
        Tournament.where(owner_admin_data_cleanup_id: cleanup.id, owner_user_id: nil)
          .update_all(owner_admin_data_cleanup_id: nil, updated_at: Time.current)
        TournamentEntry.where(admin_data_cleanup_id: cleanup.id, user_id: nil)
          .update_all(admin_data_cleanup_id: nil, updated_at: Time.current)
      end

      def record_event!(cleanup, admin_user, action, reason)
        cleanup.events.create!(
          admin_user: admin_user,
          user: cleanup.user,
          action: action,
          categories: cleanup.categories,
          counts: cleanup.counts,
          reason: reason.to_s.strip
        )
      end
    end
  end
end
