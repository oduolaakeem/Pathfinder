# frozen_string_literal: true

# Exactly one endpoint request, only when separately authorized with --live.
# Invoke with Ruby, not rails runner: the safety gates must precede Rails boot.
require "json"
require "logger"

module SkillGapLiveTest
  CATEGORIES = [ "Programming language", "SQL", "Git", "HTTP/API concepts", "Automated testing" ].freeze
  GROUPS = [ "identified_skills", "not_identified_skills", "uncertain_skills" ].freeze
  RESPONSE_KEYS = [ "goal_id", "current_skill_id", "profile", "profile_version", "method", *GROUPS ].freeze
  PATH_PRIORITY = [ "Programming language", "Git", "SQL", "HTTP/API concepts", "Automated testing" ].freeze
  STEP_KEYS = [ "category", "order", "title", "instruction", "completion_evidence" ].freeze

  class Failure < StandardError; end

  class UniqueObject < Hash
    def []=(key, value)
      raise Failure, "invalid_response" if key?(key)
      super
    end
  end

  def self.run
    started = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    status = nil
    model = ENV.fetch("GEMINI_MODEL", "gemini-3.5-flash-lite")
    unless model.match?(/\Agemini-[a-z0-9.-]{1,80}\z/)
      model = "invalid"
      raise Failure, "configuration"
    end
    raise Failure, "opt_in_required" unless ARGV == [ "--live" ]
    raise Failure, "test_environment_required" unless ENV["RAILS_ENV"] == "test"
    key = ENV["GEMINI_API_KEY"]
    raise Failure, "missing_api_key" if key.nil? || key.strip.empty?

    # Suppress logs in this disposable harness process before initializing Rails.
    # Application logging configuration and existing log files are not changed.
    require_relative "../config/application"
    quiet_logger = Logger.new(File::NULL)
    Rails.application.config.logger = quiet_logger
    require_relative "../config/environment"
    Rails.logger = quiet_logger
    ActiveRecord::Base.logger = quiet_logger
    ActionController::Base.logger = quiet_logger
    require "action_dispatch/testing/integration"

    config = ActiveRecord::Base.connection_db_config
    unless Rails.env.test? && config.database.end_with?("_test")
      raise Failure, "test_database_required"
    end

    goal_id = nil
    skill_id = nil
    failure = nil
    # Integration sessions execute synchronously in this thread and share the
    # Active Record connection used by the enclosing transaction (as request specs do).
    ActiveRecord::Base.connection_pool.with_connection do
      ActiveRecord::Base.transaction(requires_new: true) do
        failure = "integration_failed"
        begin
          goal = Goal.create!(description: "Become a backend developer")
          skills = CurrentSkill.create!(goal: goal, description: "Ruby, SQL, Git; built a small Rails application.")
          goal_id = goal.id
          skill_id = skills.id
          session = ActionDispatch::Integration::Session.new(Rails.application)
          session.post("/api/goals/#{goal.id}/skill_gap", params: {}, as: :json)
          status = session.response.status
          raise Failure, "endpoint_failed" unless status == 200
          raise Failure, "invalid_response" unless session.response.media_type == "application/json"
          raise Failure, "invalid_response" if session.response.body.bytesize > 64 * 1024
          validate_response(session.response.body, goal_id, skill_id)
          failure = nil
        rescue Failure => error
          failure = error.message
        rescue StandardError
          failure = "integration_failed"
        ensure
          # Runs on success, response failure, and exceptions; never commits fixtures.
          raise ActiveRecord::Rollback
        end
      end
      if (goal_id && Goal.exists?(goal_id)) || (skill_id && CurrentSkill.exists?(skill_id))
        raise Failure, "rollback_failed"
      end
    end
    raise Failure, failure if failure
    report("PASS", status, model, started)
    0
  rescue Failure => error
    report("FAIL", status, model, started, error.message)
    1
  rescue StandardError
    report("FAIL", status, model, started, "setup_or_integration_failed")
    1
  end

  def self.validate_response(body, goal_id, skill_id)
    parsed = JSON.parse(body, object_class: UniqueObject)
    valid = parsed.is_a?(Hash) && parsed.keys.sort == [ "learning_path", "skill_gap" ]
    result = parsed["skill_gap"] if valid
    valid &&= result.is_a?(Hash) && result.keys.sort == RESPONSE_KEYS.sort &&
      result["goal_id"] == goal_id && result["current_skill_id"] == skill_id &&
      result["profile"] == "backend_development" && result["profile_version"] == "1" &&
      result["method"] == "ai_assisted" && GROUPS.all? { |group|
        result[group].is_a?(Array) && result[group].all? { |category| category.is_a?(String) }
      }
    if valid
      categories = GROUPS.flat_map { |group| result[group] }
      valid = categories.length == 5 && categories.uniq.length == 5 && categories.sort == CATEGORIES.sort
    end
    raise Failure, "invalid_response" unless valid
    validate_learning_path(parsed["learning_path"], result)
  rescue JSON::ParserError
    raise Failure, "invalid_response", cause: nil
  end

  def self.validate_learning_path(path, assessment)
    valid = path.is_a?(Hash) && path.keys.sort == [ "catalogue_version", "method", "next_action", "steps" ] &&
      path["method"] == "curated" && path["catalogue_version"] == "1"
    raise Failure, "invalid_response" unless valid

    selected = PATH_PRIORITY.select { |category|
      assessment["not_identified_skills"].include?(category) || assessment["uncertain_skills"].include?(category)
    }
    expected = selected.empty? ? [ "Integrated practice" ] : selected
    steps = path["steps"]
    valid = steps.is_a?(Array) && steps.length == expected.length && steps.each_with_index.all? { |step, index|
      step.is_a?(Hash) && step.keys.sort == STEP_KEYS.sort &&
        step["category"] == expected[index] && step["order"].is_a?(Integer) && step["order"] == index + 1 &&
        [ "title", "instruction", "completion_evidence" ].all? { |field|
          step[field].is_a?(String) && !step[field].strip.empty? && step[field].length <= 2000
        }
    }
    next_action = path["next_action"]
    valid &&= next_action.is_a?(Hash) && next_action.keys.sort == STEP_KEYS.sort &&
      next_action["order"].is_a?(Integer) && next_action == steps.first
    raise Failure, "invalid_response" unless valid
  end

  def self.report(outcome, status, model, started, category = nil)
    elapsed = Process.clock_gettime(Process::CLOCK_MONOTONIC) - started
    puts [ outcome, ("HTTP=#{status}" if status), "model=#{model}", format("elapsed=%.2fs", elapsed), category ].compact.join(" ")
  end

  private_class_method :validate_response, :validate_learning_path, :report
end

exit SkillGapLiveTest.run if $PROGRAM_NAME == __FILE__
