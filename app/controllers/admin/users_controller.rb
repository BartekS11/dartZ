module Admin
  class UsersController < BaseController
    PER_PAGE = 25
    MATCHES_PER_PAGE = 25

    before_action :set_user, only: %i[show matches tier]

    def index
      scope = User.order(created_at: :desc)
      if params[:query].present?
        query = params[:query].to_s.strip.first(100)
        term = "%#{ActiveRecord::Base.sanitize_sql_like(query)}%"
        scope = scope.where("email_address ILIKE :term OR nickname ILIKE :term", term: term)
      end

      @total_users = scope.count
      @total_pages = page_count(@total_users, PER_PAGE)
      @page = [ positive_page, @total_pages ].min
      @users = scope.offset((@page - 1) * PER_PAGE).limit(PER_PAGE).to_a
      @metrics = Admin::UserMetrics.for(@users)
    end

    def show
      @metrics = Admin::UserMetrics.for([ @user ]).fetch(@user, Admin::UserMetrics::EMPTY)
      @tier_changes = @user.admin_tier_changes.includes(:admin_user).order(created_at: :desc)
    end

    def matches
      scope = @user_matches
      scope = filter_matches(scope)
      @filter = params[:filter].presence_in(%w[all casual invitation tournament bot]) || "all"
      @total_matches = scope.count(:id)
      @total_pages = page_count(@total_matches, MATCHES_PER_PAGE)
      @page = [ positive_page, @total_pages ].min
      @matches = scope.preload(:players).order(created_at: :desc)
        .offset((@page - 1) * MATCHES_PER_PAGE).limit(MATCHES_PER_PAGE)
      @tournaments_by_match_id = TournamentMatch.includes(:tournament)
        .where(linked_match_id: @matches.map(&:id)).index_by(&:linked_match_id)
    end

    def tier
      AdminTierOverride.call(
        user: @user,
        admin_user: current_admin_user,
        override: params[:manual_tier_override],
        reason: params[:reason]
      )
      redirect_to admin_user_path(@user), notice: "Tier override updated."
    rescue AdminTierOverride::ReasonRequired, AdminTierOverride::NoChange, ArgumentError, ActiveRecord::RecordInvalid => error
      redirect_to admin_user_path(@user), alert: error.message
    end

    private

    def set_user
      @user = User.find(params[:id])
      @user_matches = Match.joins(:players).where(players: { user_id: @user.id }).distinct
    end

    def filter_matches(scope)
      case params[:filter]
      when "casual"
        scope.where(invite_created_at: nil).where.not(id: TournamentMatch.where.not(linked_match_id: nil).select(:linked_match_id))
      when "invitation"
        scope.where.not(invite_created_at: nil)
      when "tournament"
        scope.where(id: TournamentMatch.where.not(linked_match_id: nil).select(:linked_match_id))
      when "bot"
        scope.where(id: Player.where(bot: true).select(:match_id))
      else
        scope
      end
    end

    def positive_page
      [ params.fetch(:page, 1).to_i, 1 ].max
    end

    def page_count(total, per_page)
      [ (total.to_f / per_page).ceil, 1 ].max
    end
  end
end
