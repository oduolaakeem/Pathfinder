require "spec_helper"
require "json"
require "net/http"
require_relative "../../app/services/gemini_skill_gap_provider"
require_relative "../../app/services/skill_gap_evaluator" if File.exist?(File.expand_path("../../app/services/skill_gap_evaluator.rb", __dir__))

RSpec.describe "SkillGapEvaluator" do
  let(:cases_json) { File.read(File.expand_path("../fixtures/skill_gap_evaluation_cases.json", __dir__)) }
  let(:actuals_json) { File.read(File.expand_path("../fixtures/skill_gap_evaluation_actuals.json", __dir__)) }
  let(:cases) { JSON.parse(cases_json) }
  let(:actuals) { JSON.parse(actuals_json).fetch("results") }
  let(:categories) { [ "Programming language", "SQL", "Git", "HTTP/API concepts", "Automated testing" ] }
  let(:case_ids) { %w[explicit_evidence explicit_absence mixed_evidence ambiguous_evidence instruction_like] }

  before do
    allow(Net::HTTP).to receive(:new).and_raise("External transport forbidden")
    allow(Net::HTTP).to receive(:start).and_raise("External transport forbidden")
    allow(GeminiSkillGapProvider).to receive(:classify).and_raise("Gemini invocation forbidden")
  end

  def evaluate(data = cases, results = actuals)
    SkillGapEvaluator.call(cases: data, actual_results: results)
  end

  it "reports exact agreement for the explicit-evidence case" do
    report = evaluate([ cases.first ], { "explicit_evidence" => actuals.fetch("explicit_evidence") })
    expect(report).to include(cases: 1, comparisons: 5, matches: 5, mismatches: 0)
    expect(report.fetch(:differences)).to eq([])
  end

  it "reports the two deliberately simulated mismatches and aggregate totals" do
    report = evaluate
    expect(report).to include(cases: 5, comparisons: 25, matches: 23, mismatches: 2)
    expect(report.fetch(:differences)).to eq([
      { case_id: "ambiguous_evidence", category: "SQL", expected: "uncertain", actual: "identified" },
      { case_id: "ambiguous_evidence", category: "HTTP/API concepts", expected: "uncertain", actual: "not_identified" }
    ])
  end

  it "retains all comparison rows in fixture case order and provider category order" do
    rows = evaluate.fetch(:rows)
    expect(rows.length).to eq(25)
    expect(rows.map { |row| [ row[:case_id], row[:category] ] }).to eq(case_ids.product(categories))
    expect(rows.first).to eq(case_id: "explicit_evidence", category: "Programming language",
      expected: "identified", actual: "identified", match: true)
    expect(rows[16]).to eq(case_id: "ambiguous_evidence", category: "SQL",
      expected: "uncertain", actual: "identified", match: false)
  end

  it "reports explicit per-category counts" do
    expect(evaluate.fetch(:per_category)).to eq(
      "Programming language" => { matches: 5, mismatches: 0 }, "SQL" => { matches: 4, mismatches: 1 },
      "Git" => { matches: 5, mismatches: 0 }, "HTTP/API concepts" => { matches: 4, mismatches: 1 },
      "Automated testing" => { matches: 5, mismatches: 0 }
    )
  end

  it "explicitly labels results simulated rather than measured model accuracy" do
    expect(evaluate).to include(mode: "offline_simulated", real_model_accuracy_measured: false)
  end

  it "does not mutate the inputs" do
    before = Marshal.dump([ cases, actuals ])
    evaluate
    expect(Marshal.dump([ cases, actuals ])).to eq(before)
  end

  it "is deterministic and independent of actual-map insertion order" do
    expect(evaluate).to eq(evaluate(cases, actuals.to_a.reverse.to_h))
    expect(evaluate).to eq(evaluate)
  end

  it "never invokes Gemini or external transport" do
    evaluate
    expect(GeminiSkillGapProvider).not_to have_received(:classify)
    expect(Net::HTTP).not_to have_received(:new)
    expect(Net::HTTP).not_to have_received(:start)
  end

  # Proposed fixture-loading boundary validates both raw JSON documents before
  # ordinary parsing can overwrite duplicate keys. No file/network I/O is needed.
  it "loads valid fixture JSON through the explicit loading boundary" do
    expect(SkillGapEvaluator.load_fixtures(cases_json: cases_json, actuals_json: actuals_json)).to eq(
      cases: cases, actual_results: actuals
    )
  end

  [ "cases", "actuals" ].each do |source|
    it "rejects duplicate JSON keys in #{source}" do
      duplicated = source == "cases" ? cases_json.sub('"id": "explicit_evidence"', '"id": "explicit_evidence", "id": "other"') :
        actuals_json.sub('"SQL":"identified"', '"SQL":"identified","SQL":"uncertain"')
      expect {
        SkillGapEvaluator.load_fixtures(cases_json: source == "cases" ? duplicated : cases_json,
          actuals_json: source == "actuals" ? duplicated : actuals_json)
      }.to raise_error(ArgumentError)
    end
  end

  it "rejects malformed JSON and actual fixtures not labelled simulated" do
    expect { SkillGapEvaluator.load_fixtures(cases_json: "{", actuals_json: actuals_json) }.to raise_error(ArgumentError)
    unsafe = JSON.parse(actuals_json).merge("real_model_accuracy_measured" => true)
    expect { SkillGapEvaluator.load_fixtures(cases_json: cases_json, actuals_json: JSON.generate(unsafe)) }.to raise_error(ArgumentError)
  end

  %w[missing_case unexpected_case missing_expected_category unexpected_expected_category missing_actual_category
    unexpected_actual_category invalid_expected_label invalid_actual_label duplicate_case_ids empty_cases
    empty_actuals nil_cases nil_actuals].each do |kind|
    it "rejects #{kind} without reporting misleading agreement" do
      data = JSON.parse(cases_json)
      results = JSON.parse(actuals_json).fetch("results")
      case kind
      when "missing_case" then results.delete("explicit_evidence")
      when "unexpected_case" then results["extra"] = results.fetch("explicit_evidence").dup
      when "missing_expected_category" then data.first.fetch("expected").delete("SQL")
      when "unexpected_expected_category" then data.first.fetch("expected")["Deployment"] = "identified"
      when "missing_actual_category" then results.fetch("explicit_evidence").delete("SQL")
      when "unexpected_actual_category" then results.fetch("explicit_evidence")["Deployment"] = "identified"
      when "invalid_expected_label" then data.first.fetch("expected")["SQL"] = "expert"
      when "invalid_actual_label" then results.fetch("explicit_evidence")["SQL"] = nil
      when "duplicate_case_ids" then data << data.first.dup
      when "empty_cases" then data = []
      when "empty_actuals" then results = {}
      when "nil_cases" then data = nil
      when "nil_actuals" then results = nil
      end
      expect { evaluate(data, results) }.to raise_error(ArgumentError)
    end
  end
end
