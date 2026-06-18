require "fileutils"

class RailsApiMaster
  def initialize
    require "tty-prompt"

    @prompt = TTY::Prompt.new
    @routes_file = "config/routes.rb"
  end

  def run
    @prompt.say("Rails API Master Toolkit", color: :cyan)

    action = @prompt.select("Main Menu:") do |menu|
      menu.choice "Convert ApplicationController to API", :convert
      menu.choice "Generate New Versioned Controller + Test + Route", :create
      menu.choice "Exit", :exit
    end

    case action
    when :convert then convert_base
    when :create then create_flow
    end
  end

  private

  def find_api_base
    candidates = [
      "app/controllers/application_controller.rb",
      "app/controllers/api/base_controller.rb",
      "app/controllers/api_controller.rb"
    ]
    existing = candidates.find { |f| File.exist?(f) && File.read(f).include?("ActionController::API") }
    existing ? File.read(existing).match(/class\s+([\w:]+)/)[1] : nil
  end

  def create_flow
    # Setup Inheritance
    detected_base = find_api_base
    base_class = detected_base || @prompt.ask("Base class?", default: "ApplicationController")

    # Controller Details
    raw_name = @prompt.ask("Resource Name (e.g. 'posts'):") { |q| q.required true }.downcase
    name = raw_name.split("_").map(&:capitalize).join

    use_api_ns = @prompt.yes?("Namespace under 'API'?")
    version = @prompt.select("Version:", %w[None V1 V2 V3])

    # Test Framework Selection
    test_framework = @prompt.select("Select Testing Framework:", %w[RSpec Minitest None])

    # Path Calculations
    ns_parts = []
    ns_parts << "api" if use_api_ns
    ns_parts << version.downcase unless version == "None"

    dir_path = File.join("app", "controllers", *ns_parts)
    file_path = File.join(dir_path, "#{raw_name}_controller.rb")
    class_name = (ns_parts.map(&:upcase) + [ "#{name}Controller" ]).join("::")

    # Execute Generation
    FileUtils.mkdir_p(dir_path)
    File.write(file_path, controller_template(class_name, base_class, raw_name))
    @prompt.ok("Created Controller: #{file_path}")

    generate_test(test_framework, ns_parts, name, raw_name) unless test_framework == "None"
    inject_route(use_api_ns, version, raw_name) if @prompt.yes?("Inject into routes.rb?")
  end

  def controller_template(class_name, base_class, resource)
    <<~RUBY
      class #{class_name} < #{base_class}
        def index
          render json: { data: [], message: 'Listing #{resource}' }
        end
      end
    RUBY
  end

  def generate_test(framework, ns_parts, name, raw_name)
    if framework == "RSpec"
      dir = File.join("spec", "requests", *ns_parts)
      file = File.join(dir, "#{raw_name}_spec.rb")
      content = <<~RUBY
        require 'rails_helper'

        RSpec.describe "#{ns_parts.join('/').upcase}/#{name}", type: :request do
          describe "GET /index" do
            it "returns http success" do
              get "/#{ns_parts.join('/')}/#{raw_name}"
              expect(response).to have_http_status(:success)
            end
          end
        end
      RUBY
    else # Minitest
      dir = File.join("test", "controllers", *ns_parts)
      file = File.join(dir, "#{raw_name}_controller_test.rb")
      class_name = (ns_parts.map(&:upcase) + [ "#{name}ControllerTest" ]).join("::")
      content = <<~RUBY
        require "test_helper"

        class #{class_name} < ActionDispatch::IntegrationTest
          test "should get index" do
            get #{ns_parts.join('_')}_#{raw_name}_url
            assert_response :success
          end
        end
      RUBY
    end

    FileUtils.mkdir_p(dir)
    File.write(file, content)
    @prompt.ok("Created #{framework} test: #{file}")
  end

  def inject_route(use_api, version, resource)
    return unless File.exist?(@routes_file)
    content = File.read(@routes_file)

    route_line = "    resources :#{resource}, only: [:index, :show]"

    if use_api && version != "None"
      new_route = "\n  namespace :api do\n    namespace :#{version.downcase} do\n  #{route_line}\n    end\n  end"
    else
      new_route = "\n  #{route_line}"
    end

    updated = content.sub(/Rails\.application\.routes\.draw do/, "Rails.application.routes.draw do#{new_route}")
    File.write(@routes_file, updated)
    @prompt.ok("Routes updated.")
  end

  def convert_base
    path = "app/controllers/application_controller.rb"
    return @prompt.error("Not found") unless File.exist?(path)
    File.write(path, File.read(path).gsub("ActionController::Base", "ActionController::API"))
    @prompt.ok("Converted ApplicationController to API.")
  end
end

RailsApiMaster.new.run if __FILE__ == $PROGRAM_NAME
