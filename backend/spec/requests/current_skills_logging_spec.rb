require "rails_helper"
require "stringio"
require "open3"

RSpec.describe "Current skills logging privacy", type: :request do
  let(:description) { "PF009-SKILLS-PRIVACY-SYNTHETIC-20261010" }
  let(:goal) { Goal.create!(description: "PF009-SYNTHETIC-GOAL") }
  let(:request_output) { StringIO.new }
  let(:sql_output) { StringIO.new }

  around do |example|
    original_rails_logger = Rails.logger
    original_controller_logger = ActionController::Base.logger
    original_api_logger = ActionController::API.logger
    original_record_logger = ActiveRecord::Base.logger

    request_logger = ActiveSupport::Logger.new(request_output)
    request_logger.level = Logger::DEBUG
    sql_logger = ActiveSupport::Logger.new(sql_output)
    sql_logger.level = Logger::DEBUG

    Rails.logger = request_logger
    ActionController::Base.logger = request_logger
    ActionController::API.logger = request_logger
    ActiveRecord::Base.logger = sql_logger
    example.run
  ensure
    Rails.logger = original_rails_logger
    ActionController::Base.logger = original_controller_logger
    ActionController::API.logger = original_api_logger
    ActiveRecord::Base.logger = original_record_logger
  end

  it "filters nested skills descriptions from request logs without changing the saved response" do
    post "/api/goals/#{goal.id}/current_skills",
      params: { current_skills: { description: description } }, as: :json

    expect(response).to have_http_status(:created)
    saved = CurrentSkill.find(response.parsed_body.dig("current_skills", "id"))
    expect(saved.description).to eq(description)
    expect(response.parsed_body).to eq(
      "current_skills" => { "id" => saved.id, "goal_id" => goal.id, "description" => description }
    )
    expect(request_output.string).to include("Parameters:", "current_skills", "[FILTERED]", "Completed 201")
    expect(request_output.string).not_to include(description)
  end

  it "filters SQL bind values while retaining current skills INSERT logging" do
    post "/api/goals/#{goal.id}/current_skills",
      params: { current_skills: { description: description } }, as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("current_skills", "description")).to eq(description)
    expect(CurrentSkill.find(response.parsed_body.dig("current_skills", "id")).description).to eq(description)
    expect(sql_output.string).to include('INSERT INTO "current_skills"', '"description", "[FILTERED]"')
    expect(sql_output.string).not_to include(description)
  end

  it "filters real development request and SQL logs while returning the persisted description" do
    runner = <<~RUBY
      require "stringio"
      ActiveRecord::Base.establish_connection(Rails.configuration.database_configuration.fetch("test"))
      abort "Expected the test database" unless ActiveRecord::Base.connection.current_database == "pathfinder_test"
      request_output = StringIO.new
      sql_output = StringIO.new
      request_logger = ActiveSupport::Logger.new(request_output)
      request_logger.level = Logger::DEBUG
      Rails.logger = request_logger
      ActionController::Base.logger = request_logger
      ActionController::API.logger = request_logger
      ActiveRecord::Base.logger = ActiveSupport::Logger.new(sql_output)
      ActiveRecord::Base.logger.level = Logger::DEBUG
      result = {}
      Goal.transaction do
        goal = Goal.create!(description: "PF009-SYNTHETIC-DEVELOPMENT-GOAL")
        session = ActionDispatch::Integration::Session.new(Rails.application)
        session.host! "localhost"
        session.post "/api/goals/\#{goal.id}/current_skills",
          params: { current_skills: { description: #{description.inspect} } }, as: :json
        result[:status] = session.response.status
        result[:response] = session.response.parsed_body
        result[:goal_id] = goal.id
        result[:persisted_description] = CurrentSkill.find(result[:response].dig("current_skills", "id")).description
        raise ActiveRecord::Rollback
      end
      result[:request_log] = request_output.string
      result[:sql_log] = sql_output.string
      puts JSON.generate(result)
    RUBY

    output, errors, status = Open3.capture3(
      { "RAILS_ENV" => "development" },
      RbConfig.ruby, Rails.root.join("bin/rails").to_s, "runner", runner
    )

    expect(status.success?).to be(true), errors
    result = JSON.parse(output)
    expect(result.fetch("status")).to eq(201)
    expect(result.fetch("persisted_description")).to eq(description)
    saved = result.fetch("response").fetch("current_skills")
    expect(saved.fetch("id")).to be_positive
    expect(result.fetch("response")).to eq(
      "current_skills" => { "id" => saved.fetch("id"), "goal_id" => result.fetch("goal_id"), "description" => description }
    )
    expect(result.fetch("request_log")).to include("Parameters:", "current_skills", "[FILTERED]", "Completed 201")
    expect(result.fetch("request_log")).not_to include(description)
    expect(result.fetch("sql_log")).to include('INSERT INTO "current_skills"', '"description", "[FILTERED]"', "ROLLBACK")
    expect(result.fetch("sql_log")).not_to include(description)
  end
end
