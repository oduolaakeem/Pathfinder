# frozen_string_literal: true

require "json"
require_relative "gemini_skill_gap_provider"

class SkillGapEvaluator
  CATEGORIES = GeminiSkillGapProvider::CATEGORIES
  CLASSIFICATIONS = GeminiSkillGapProvider::CLASSIFICATIONS
  CASE_KEYS = %w[id goal_description skills_description expected rationale].freeze

  # Use the provider's established duplicate-key detector without invoking its
  # transport or response parser. Convert its typed error at this local boundary.
  def self.load_fixtures(cases_json:, actuals_json:)
    unless cases_json.is_a?(String) && actuals_json.is_a?(String)
      raise ArgumentError, "Invalid evaluation fixtures"
    end
    cases = JSON.parse(cases_json, object_class: GeminiSkillGapProvider::UniqueObject)
    actuals = JSON.parse(actuals_json, object_class: GeminiSkillGapProvider::UniqueObject)
    unless actuals.is_a?(Hash) && actuals.keys.sort == %w[mode real_model_accuracy_measured results] &&
        actuals["mode"] == "offline_simulated" && actuals["real_model_accuracy_measured"] == false
      raise ArgumentError, "Invalid simulated-results fixture"
    end
    validate_inputs!(cases, actuals["results"])
    { cases: cases, actual_results: actuals["results"] }
  rescue JSON::ParserError, JSON::NestingError, GeminiSkillGapProvider::InvalidResponse
    raise ArgumentError, "Invalid evaluation JSON", cause: nil
  end

  def self.call(cases:, actual_results:)
    validate_inputs!(cases, actual_results)
    per_category = CATEGORIES.to_h { |category| [ category, { matches: 0, mismatches: 0 } ] }
    rows = []
    differences = []
    cases.each do |test_case|
      CATEGORIES.each do |category|
        expected = test_case["expected"][category]
        actual = actual_results[test_case["id"]][category]
        match = expected == actual
        row = { case_id: test_case["id"], category: category, expected: expected, actual: actual }
        rows << row.merge(match: match)
        differences << row unless match
        per_category[category][match ? :matches : :mismatches] += 1
      end
    end
    { mode: "offline_simulated", real_model_accuracy_measured: false,
      cases: cases.length, comparisons: rows.length, matches: rows.length - differences.length,
      mismatches: differences.length, per_category: per_category, rows: rows, differences: differences }
  end

  def self.validate_inputs!(cases, actual_results)
    unless cases.is_a?(Array) && !cases.empty? && actual_results.is_a?(Hash) &&
        cases.all? { |test_case|
          test_case.is_a?(Hash) && test_case.keys.sort == CASE_KEYS.sort &&
            %w[id goal_description skills_description rationale].all? { |field|
              test_case[field].is_a?(String) && !test_case[field].strip.empty?
            } && valid_classifications?(test_case["expected"])
        }
      raise ArgumentError, "Invalid evaluation cases or classifications"
    end
    ids = cases.map { |test_case| test_case["id"] }
    unless ids.uniq.length == ids.length && actual_results.keys.all? { |id| id.is_a?(String) } &&
        actual_results.keys.sort == ids.sort && actual_results.values.all? { |labels| valid_classifications?(labels) }
      raise ArgumentError, "Invalid evaluation case coverage or classifications"
    end
  end

  def self.valid_classifications?(labels)
    labels.is_a?(Hash) && labels.keys.all? { |category| category.is_a?(String) } &&
      labels.keys.sort == CATEGORIES.sort && labels.values.all? { |label| CLASSIFICATIONS.include?(label) }
  end

  private_class_method :validate_inputs!, :valid_classifications?
end
