require "rails_helper"
require "stringio"
require "open3"

RSpec.describe "Goal logging privacy", type: :request do
  let(:description) { "PF008-LOG-PRIVACY-SYNTHETIC-20261010" }
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

  it "redacts goal descriptions from request parameter logs" do
    post "/api/goals", params: { goal: { description: description } }, as: :json

    expect(response).to have_http_status(:created)
    expect(response.parsed_body.dig("goal", "description")).to eq(description)
    expect(request_output.string).to include("Parameters:", "[FILTERED]", "Completed 201")
    expect(request_output.string).not_to include(description)
  end

  it "redacts description bind values while retaining useful SQL logs" do
    post "/api/goals", params: { goal: { description: description } }, as: :json

    expect(response).to have_http_status(:created)
    expect(Goal.find(response.parsed_body.dig("goal", "id")).description).to eq(description)
    expect(sql_output.string).to include('INSERT INTO "goals"', '"description", "[FILTERED]"')
    expect(sql_output.string).not_to include(description)
  end

  it "redacts SQL output with the actual development logging configuration" do
    runner = <<~RUBY
      require "stringio"
      ActiveRecord::Base.establish_connection(Rails.configuration.database_configuration.fetch("test"))
      abort "Expected the test database" unless ActiveRecord::Base.connection.current_database == "pathfinder_test"
      output = StringIO.new
      ActiveRecord::Base.logger = ActiveSupport::Logger.new(output)
      ActiveRecord::Base.logger.level = Logger::DEBUG
      Goal.transaction do
        Goal.create!(description: #{description.inspect})
        raise ActiveRecord::Rollback
      end
      puts output.string
    RUBY

    output, errors, status = Open3.capture3(
      { "RAILS_ENV" => "development" },
      RbConfig.ruby, Rails.root.join("bin/rails").to_s, "runner", runner
    )

    expect(status.success?).to be(true), errors
    expect(output).to include('INSERT INTO "goals"', '"description", "[FILTERED]"', "ROLLBACK")
    expect(output).not_to include(description)
  end
end
