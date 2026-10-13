# frozen_string_literal: true

require "json"
require_relative "../app/services/skill_gap_evaluator"

begin
  fixtures = SkillGapEvaluator.load_fixtures(
    cases_json: File.read(File.expand_path("../spec/fixtures/skill_gap_evaluation_cases.json", __dir__)),
    actuals_json: File.read(File.expand_path("../spec/fixtures/skill_gap_evaluation_actuals.json", __dir__))
  )
  report = SkillGapEvaluator.call(**fixtures)
  puts JSON.pretty_generate(report.merge(agreement_basis: "simulated fixture agreement, not Gemini accuracy"))
rescue ArgumentError, JSON::GeneratorError
  warn "FAIL invalid_evaluation_fixtures"
  exit 1
rescue StandardError
  warn "FAIL evaluation_execution_failed"
  exit 1
end
