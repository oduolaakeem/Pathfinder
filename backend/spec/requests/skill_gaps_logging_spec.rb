require "rails_helper"
require "net/http"
require "stringio"
require "open3"

RSpec.describe "Skill gap logging privacy", type: :request do
  # Distinctive case/whitespace keeps this synthetic goal within the supported profile.
  let(:goal_description) { "  bEcOmE a BaCkEnD dEvElOpEr  " }
  let(:skills_description) { "PF010_SYNTHETIC_SKILLS_PRIVACY Ruby, SQL, Git" }
  let(:fake_key) { "PF010_SYNTHETIC_KEY_PRIVACY" }
  let(:raw_marker) { "PF010_SYNTHETIC_PROVIDER_PRIVACY" }
  let(:goal) { Goal.create!(description: goal_description) }
  let(:skills) { CurrentSkill.create!(goal: goal, description: skills_description) }
  let(:request_output) { StringIO.new }
  let(:sql_output) { StringIO.new }
  let(:http) { double("offline Gemini HTTP") }
  let(:classifications) do
    { "Programming language" => "identified", "SQL" => "identified", "Git" => "identified",
      "HTTP/API concepts" => "uncertain", "Automated testing" => "not_identified" }
  end
  let(:provider_body) do
    JSON.generate("candidates" => [{ "finishReason" => "STOP", "content" => {
      "parts" => [{ "text" => JSON.generate(classifications), "partMetadata" => { "synthetic" => raw_marker } }]
    } }])
  end

  around do |example|
    original = [ Rails.logger, ActionController::Base.logger, ActionController::API.logger, ActiveRecord::Base.logger ]
    request_logger = ActiveSupport::Logger.new(request_output)
    request_logger.level = Logger::DEBUG
    Rails.logger = ActionController::Base.logger = ActionController::API.logger = request_logger
    ActiveRecord::Base.logger = ActiveSupport::Logger.new(sql_output)
    ActiveRecord::Base.logger.level = Logger::DEBUG
    example.run
  ensure
    Rails.logger, ActionController::Base.logger, ActionController::API.logger, ActiveRecord::Base.logger = original
  end

  before do
    allow(ENV).to receive(:[]).and_call_original
    allow(ENV).to receive(:fetch).and_call_original
    allow(ENV).to receive(:[]).with("GEMINI_API_KEY").and_return(fake_key)
    allow(ENV).to receive(:fetch).with("GEMINI_MODEL", any_args).and_return("gemini-3.5-flash-lite")
    allow(Net::HTTP).to receive(:new).and_return(http)
    allow(Net::HTTP).to receive(:start).and_raise("External HTTP forbidden")
    %i[use_ssl= verify_mode= open_timeout= read_timeout= write_timeout= max_retries=].each do |setter|
      allow(http).to receive(setter)
    end
    allow(http).to receive(:start).and_yield(http)
    allow(http).to receive(:request) do |request, &block|
      @prompt = JSON.parse(request.body).fetch("systemInstruction").fetch("parts").first.fetch("text")
      reply = Net::HTTPOK.new("1.1", "200", "Synthetic")
      allow(reply).to receive(:read_body).and_yield(provider_body)
      block.call(reply)
    end
  end

  def submit
    skills # Setup is outside the captured request, including INSERT statements.
    request_output.truncate(0)
    request_output.rewind
    sql_output.truncate(0)
    sql_output.rewind
    post "/api/goals/#{goal.id}/skill_gap", params: {
      goal: { description: goal_description }, current_skills: { description: skills_description }
    }, as: :json
  end

  def expect_private
    [ goal_description, skills_description, fake_key, raw_marker, @prompt ].compact.each do |text|
      [ request_output.string, sql_output.string, response.body ].each do |output|
        expect(output.include?(text)).to be(false), "Sensitive synthetic data escaped the assessed boundary"
      end
    end
  end

  it "filters request parameters and SQL retrieval logs and returns only the approved assessment" do
    submit
    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq("skill_gap" => {
      "goal_id" => goal.id, "current_skill_id" => skills.id, "profile" => "backend_development",
      "profile_version" => "1", "method" => "ai_assisted",
      "identified_skills" => [ "Programming language", "SQL", "Git" ],
      "not_identified_skills" => [ "Automated testing" ], "uncertain_skills" => [ "HTTP/API concepts" ]
    })
    expect(request_output.string).to include("Parameters:", "[FILTERED]", "Completed 200")
    expect(sql_output.string).to include('FROM "goals"', 'FROM "current_skills"')
    expect_private
  end

  context "with malformed provider output" do
    let(:provider_body) { "#{raw_marker} #{fake_key} #{goal_description} #{skills_description}" }
    it "returns a generic private 502 without logging the provider body" do
      submit
      expect(response).to have_http_status(:bad_gateway)
      expect(response.parsed_body).to eq("errors" => { "skill_gap" => [ "invalid provider result" ] })
      expect_private
    end
  end

  it "returns a private 503 for a transport exception containing sensitive synthetic content" do
    allow(http).to receive(:request) do |request|
      @prompt = JSON.parse(request.body).fetch("systemInstruction").fetch("parts").first.fetch("text")
      raise Net::ReadTimeout, "#{fake_key} #{goal_description} #{skills_description} #{raw_marker} #{@prompt}"
    end
    submit
    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to eq("errors" => { "skill_gap" => [ "provider unavailable" ] })
    expect_private
  end

  it "returns a private 503 for an authentication failure without logging its response body" do
    allow(http).to receive(:request) do |request, &block|
      @prompt = JSON.parse(request.body).fetch("systemInstruction").fetch("parts").first.fetch("text")
      reply = Net::HTTPUnauthorized.new("1.1", "401", "Synthetic")
      allow(reply).to receive(:read_body).and_yield("#{fake_key} #{raw_marker} #{@prompt}")
      block.call(reply)
    end
    submit
    expect(response).to have_http_status(:service_unavailable)
    expect(response.parsed_body).to eq("errors" => { "skill_gap" => [ "provider unavailable" ] })
    expect_private
  end

  it "protects request and SQL retrieval logs with actual development configuration" do
    runner = <<~RUBY
      require "stringio"
      require "net/http"
      Net::HTTP.define_singleton_method(:new) { |*| raise "External HTTP forbidden" }
      Net::HTTP.define_singleton_method(:start) { |*| raise "External HTTP forbidden" }
      ActiveRecord::Base.establish_connection(Rails.configuration.database_configuration.fetch("test"))
      abort "FAIL wrong_database" unless ActiveRecord::Base.connection.current_database == "pathfinder_test"
      request_output = StringIO.new
      sql_output = StringIO.new
      logger = ActiveSupport::Logger.new(request_output)
      logger.level = Logger::DEBUG
      Rails.logger = ActionController::Base.logger = ActionController::API.logger = logger
      ActiveRecord::Base.logger = ActiveSupport::Logger.new(sql_output)
      ActiveRecord::Base.logger.level = Logger::DEBUG
      GeminiSkillGapProvider.define_singleton_method(:classify) { |**| #{classifications.inspect} }
      result = {}
      Goal.transaction do
        goal = Goal.create!(description: #{goal_description.inspect})
        CurrentSkill.create!(goal: goal, description: #{skills_description.inspect})
        request_output.truncate(0); request_output.rewind
        sql_output.truncate(0); sql_output.rewind
        session = ActionDispatch::Integration::Session.new(Rails.application)
        session.host! "localhost"
        session.post "/api/goals/\#{goal.id}/skill_gap", params: {
          goal: { description: #{goal_description.inspect} }, current_skills: { description: #{skills_description.inspect} }
        }, as: :json
        result[:status] = session.response.status
        result[:request_logging_present] = request_output.string.include?("Parameters:") && request_output.string.include?("[FILTERED]")
        result[:sql_logging_present] = sql_output.string.include?('FROM "goals"') && sql_output.string.include?('FROM "current_skills"')
        result[:private] = [#{goal_description.inspect}, #{skills_description.inspect}].none? { |text|
          [request_output.string, sql_output.string, session.response.body].any? { |output| output.include?(text) }
        }
        raise ActiveRecord::Rollback
      end
      puts JSON.generate(result)
    RUBY
    output, _errors, status = Open3.capture3(
      { "RAILS_ENV" => "development", "GEMINI_API_KEY" => "" },
      RbConfig.ruby, Rails.root.join("bin/rails").to_s, "runner", runner
    )
    expect(status.success?).to be(true), "Development privacy subprocess failed; raw output withheld"
    result = JSON.parse(output)
    expect(result).to eq("status" => 200, "request_logging_present" => true, "sql_logging_present" => true, "private" => true)
  end
end
