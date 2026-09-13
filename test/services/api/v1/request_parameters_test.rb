require "test_helper"

class Api::V1::RequestParametersTest < ActiveSupport::TestCase
  test "uses stable pagination defaults and metadata" do
    pagination = build.pagination

    assert_equal 1, pagination.page
    assert_equal 25, pagination.per_page
    assert_equal 0, pagination.offset
    assert_equal({ page: 1, per_page: 25, total_count: 0, total_pages: 0 }, pagination.metadata(total_count: 0))
    assert_equal({ page: 1, per_page: 25, total_count: 26, total_pages: 2 }, pagination.metadata(total_count: 26))
  end

  test "calculates an offset from valid pagination parameters" do
    pagination = build(page: "3", per_page: "10").pagination

    assert_equal 3, pagination.page
    assert_equal 10, pagination.per_page
    assert_equal 20, pagination.offset
  end

  test "rejects invalid or excessive pagination parameters" do
    error = assert_raises(Api::V1::RequestParameters::InvalidParameter) do
      build(page: "0").pagination
    end
    assert_equal "page", error.parameter

    error = assert_raises(Api::V1::RequestParameters::InvalidParameter) do
      build(per_page: "101").pagination
    end
    assert_equal "per_page", error.parameter
  end

  test "parses strict inclusive date ranges" do
    range = build(from: "2026-01-02", to: "2026-01-31").date_range

    assert_equal Date.new(2026, 1, 2), range.from
    assert_equal Date.new(2026, 1, 31), range.to
    assert_equal (range.from.beginning_of_day..range.to.end_of_day), range.as_time_range
  end

  test "allows either date boundary to be omitted" do
    assert_nil build(to: "2026-01-31").date_range.from
    assert_nil build(from: "2026-01-02").date_range.to
  end

  test "rejects malformed and reversed date ranges" do
    error = assert_raises(Api::V1::RequestParameters::InvalidParameter) do
      build(from: "01/02/2026").date_range
    end
    assert_equal "from", error.parameter

    error = assert_raises(Api::V1::RequestParameters::InvalidParameter) do
      build(from: "2026-02-01", to: "2026-01-31").date_range
    end
    assert_equal "from", error.parameter
  end

  private

  def build(values = {})
    Api::V1::RequestParameters.new(ActionController::Parameters.new(values))
  end
end
