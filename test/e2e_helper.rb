# frozen_string_literal: true

ENV["RAILS_ENV"] ||= "test"
E2E_ENABLED = ENV["RUN_E2E"] == "true"
ENV["PARALLEL_WORKERS"] ||= "1" if E2E_ENABLED

require "open3"
require "pg"
require "securerandom"
require "testcontainers/postgres"
require "uri"

module E2EPostgres
  module_function

  def start!
    return @container if defined?(@container) && @container

    assert_docker_available!

    @container = Testcontainers::PostgresContainer.new(
      "postgres:16-alpine",
      username: "test",
      password: "test",
      database: "test"
    )
    @container.start

    ENV["DATABASE_URL"] = reachable_database_url(@container)
    ENV["DB_HOST"] = nil

    at_exit { stop! }
    @container
  rescue StandardError => error
    warn <<~MESSAGE

      E2E PostgreSQL container could not be started.
      Make sure Docker is installed and running, then retry with:
        RUN_E2E=true bin/rails test test/e2e

      #{error.class}: #{error.message}
    MESSAGE
    raise
  end

  def stop!
    return unless @container

    @container.stop(force: true)
    @container.remove("force" => true, "v" => true)
  rescue StandardError => error
    warn "Could not remove E2E PostgreSQL container: #{error.class}: #{error.message}"
  ensure
    @container = nil
  end

  def assert_docker_available!
    _stdout, stderr, status = Open3.capture3("docker", "info")
    return if status.success?

    message = stderr.to_s.strip
    raise "Docker is not available: #{message.empty? ? "`docker info` failed" : message}"
  rescue Errno::ENOENT
    raise "Docker CLI was not found on PATH"
  end

  def reachable_database_url(container)
    urls = database_url_candidates(container).uniq
    urls.each do |url|
      connection = PG.connect(url)
      connection.exec("SELECT 1")
      connection.close
      return url
    rescue PG::Error, SystemCallError
      connection&.close
      next
    end

    raise "PostgreSQL Testcontainer started but was not reachable from this process. Tried: #{urls.join(", ")}"
  end

  def database_url_candidates(container)
    mapped_port = container.mapped_port(container.port)
    username = container.username
    password = container.password
    database = container.database

    candidates = [ container.database_url ]
    candidates << postgres_url(ENV["TC_HOST"], mapped_port, username, password, database)
    candidates << postgres_url(ENV["TESTCONTAINERS_HOST_OVERRIDE"], mapped_port, username, password, database)
    candidates << postgres_url("host.docker.internal", mapped_port, username, password, database) if inside_container?
    candidates << postgres_url(default_gateway_ip, mapped_port, username, password, database) if inside_container?

    container_networks(container).each_value do |network|
      candidates << postgres_url(network["Gateway"], mapped_port, username, password, database)
      candidates << postgres_url(network["IPAddress"], container.port, username, password, database)
    end

    candidates.compact
  end

  def postgres_url(host, port, username, password, database)
    return if host.to_s.empty?

    "postgres://#{URI.encode_www_form_component(username)}:#{URI.encode_www_form_component(password)}@#{host}:#{port}/#{database}"
  end

  def container_networks(container)
    container.info.dig("NetworkSettings", "Networks") || {}
  end

  def inside_container?
    File.exist?("/.dockerenv")
  end

  def default_gateway_ip
    stdout, _stderr, status = Open3.capture3("sh", "-c", "ip route | awk '/default/ { print $3; exit }'")
    status.success? ? stdout.strip : nil
  rescue Errno::ENOENT
    nil
  end
end

E2EPostgres.start! if E2E_ENABLED

require_relative "test_helper"

module E2ETestHelpers
  def unique_email(prefix)
    "#{prefix}-#{SecureRandom.hex(6)}@example.test"
  end

  def json_response
    JSON.parse(response.body)
  end

  def create_guest_match(player1: "Alice", player2: "Bob", **settings)
    post matches_path, params: {
      player1_name: player1,
      player2_name: player2,
      best_of_legs: settings.fetch(:best_of_legs, 1),
      best_of_sets: settings.fetch(:best_of_sets, 1),
      starting_score: settings.fetch(:starting_score, 501),
      double_in: settings.fetch(:double_in, false),
      double_out: settings.fetch(:double_out, true)
    }
    Match.order(:created_at).last
  end

  def submit_turn_total(turn, total, **params)
    post turn_throws_path(turn), params: params.merge(throw: { total: total })
  end

  def submit_checkout_double(turn, segment: 20, **params)
    post turn_throws_path(turn), params: params.merge(throw: { segment: segment, multiplier: "double" })
  end

  def win_current_leg_for(match, player)
    match.reload
    until match.current_leg.current_turn.player == player
      submit_turn_total(match.current_leg.current_turn, 0)
      assert_response :redirect
      match.reload
    end

    submit_turn_total(match.current_leg.current_turn, match.starting_score - 40)
    assert_response :redirect
    match.reload

    until match.current_leg.current_turn.player == player
      submit_turn_total(match.current_leg.current_turn, 0)
      assert_response :redirect
      match.reload
    end

    submit_checkout_double(match.current_leg.current_turn)
    assert_response :redirect
    match.reload
  end
end

class E2EIntegrationTest < ActionDispatch::IntegrationTest
  include E2ETestHelpers

  setup do
    skip "Set RUN_E2E=true to run slow Testcontainers E2E tests" unless E2E_ENABLED
  end
end
