module Api
  module V1
    class RequestParameters
      DEFAULT_PER_PAGE = 25
      MAX_PER_PAGE = 100

      Pagination = Data.define(:page, :per_page) do
        def offset
          (page - 1) * per_page
        end

        def metadata(total_count:)
          {
            page: page,
            per_page: per_page,
            total_count: total_count,
            total_pages: total_count.zero? ? 0 : (total_count.to_f / per_page).ceil
          }
        end
      end

      DateRange = Data.define(:from, :to) do
        def as_time_range
          (from&.beginning_of_day)..(to&.end_of_day)
        end
      end

      class InvalidParameter < StandardError
        attr_reader :parameter

        def initialize(parameter, message)
          @parameter = parameter.to_s
          super(message)
        end
      end

      def initialize(params)
        @params = params
      end

      def pagination(default_per_page: DEFAULT_PER_PAGE, max_per_page: MAX_PER_PAGE)
        page = positive_integer(:page, default: 1)
        per_page = positive_integer(:per_page, default: default_per_page)

        if per_page > max_per_page
          raise InvalidParameter.new(:per_page, "per_page must be less than or equal to #{max_per_page}")
        end

        Pagination.new(page: page, per_page: per_page)
      end

      def date_range(from_key: :from, to_key: :to)
        from = iso_date(from_key)
        to = iso_date(to_key)

        if from && to && from > to
          raise InvalidParameter.new(from_key, "#{from_key} must be on or before #{to_key}")
        end

        DateRange.new(from: from, to: to)
      end

      private

      attr_reader :params

      def positive_integer(key, default:)
        value = params[key]
        return default if value.blank?

        integer = Integer(value.to_s, 10, exception: false)
        return integer if integer&.positive?

        raise InvalidParameter.new(key, "#{key} must be a positive integer")
      end

      def iso_date(key)
        value = params[key]
        return if value.blank?

        Date.iso8601(value.to_s)
      rescue Date::Error
        raise InvalidParameter.new(key, "#{key} must use YYYY-MM-DD format")
      end
    end
  end
end
