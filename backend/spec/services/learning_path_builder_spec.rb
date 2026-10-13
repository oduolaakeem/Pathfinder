require "rails_helper"
require "net/http"

RSpec.describe "LearningPathBuilder" do
  let(:categories) { [ "Programming language", "Git", "SQL", "HTTP/API concepts", "Automated testing" ] }
  let(:identified) { categories.to_h { |category| [ category, "identified" ] } }
  let(:mixed) do
    identified.merge("Programming language" => "uncertain", "SQL" => "not_identified",
      "HTTP/API concepts" => "uncertain")
  end

  before do
    allow(Net::HTTP).to receive(:new).and_raise("External HTTP forbidden in builder specs")
    allow(Net::HTTP).to receive(:start).and_raise("External HTTP forbidden in builder specs")
  end

  def build(input)
    LearningPathBuilder.call(classifications: input)
  end

  it "derives a curated version-one path from a mixed assessment" do
    path = build(mixed)
    expect(path.keys).to match_array([ :method, :catalogue_version, :steps, :next_action ])
    expect(path).to include(method: "curated", catalogue_version: "1")
    expect(path[:steps].map { |step| step[:category] }).to eq([ "Programming language", "SQL", "HTTP/API concepts" ])
  end

  it "returns one practice activity for a single not-identified category" do
    steps = build(identified.merge("SQL" => "not_identified"))[:steps]
    expect(steps.length).to eq(1)
    expect(steps.first[:category]).to eq("SQL")
    expect(steps.first[:instruction]).to match(/quer|database/i)
    expect(steps.first[:completion_evidence]).to match(/quer|result/i)
  end

  it "frames a single uncertain category as clarification and demonstration" do
    steps = build(identified.merge("Git" => "uncertain"))[:steps]
    expect(steps.length).to eq(1)
    expect(steps.first[:category]).to eq("Git")
    expect(steps.first[:title]).to match(/clarif/i)
    expect(steps.first[:instruction]).to match(/prior|previous|experience/i)
    expect(steps.first[:instruction]).to match(/demonstrat|exercise|practice|reproduce/i)
    expect(steps.first.values.grep(String).join(" ")).not_to match(/proven deficiency|you lack|mastered|job.ready/i)
  end

  it "returns five clarification activities when all classifications are uncertain" do
    steps = build(categories.to_h { |category| [ category, "uncertain" ] })[:steps]
    expect(steps.map { |step| step[:category] }).to eq(categories)
    steps.each { |step| expect(step[:title]).to match(/clarif/i) }
  end

  it "returns five practice activities when all categories are not identified" do
    steps = build(categories.to_h { |category| [ category, "not_identified" ] })[:steps]
    expect(steps.map { |step| step[:category] }).to eq(categories)
    steps.each { |step| expect(step[:title]).not_to match(/clarif/i) }
  end

  it "returns exactly one integrated activity without mastery or job-readiness claims" do
    path = build(identified)
    expect(path[:steps].length).to eq(1)
    step = path[:steps].first
    expect(step).to include(category: "Integrated practice", order: 1)
    expect(step[:title]).to match(/backend/i)
    expect(step[:instruction]).to match(/API|endpoint/i)
    expect(step[:completion_evidence]).to match(/code|source/i)
    expect(step.values.grep(String).join(" ")).not_to match(/you have mastered|you are job.ready|all competencies.*mastered/i)
    expect(path[:next_action]).to eq(step)
  end

  it "omits identified categories from immediate gap activities" do
    expect(build(mixed)[:steps].map { |step| step[:category] }).not_to include("Git", "Automated testing")
  end

  it "uses prerequisite priority rather than input hash order or classification grouping" do
    input = categories.reverse.to_h { |category| [ category, category == "Programming language" ? "uncertain" : "not_identified" ] }
    expect(build(input)[:steps].map { |step| step[:category] }).to eq(categories)
  end

  it "renumbers selected activities contiguously after skipping categories" do
    expect(build(mixed)[:steps].map { |step| step[:order] }).to eq([ 1, 2, 3 ])
  end

  it "never repeats a category" do
    labels = build(mixed)[:steps].map { |step| step[:category] }
    expect(labels.length).to eq(3)
    expect(labels.uniq).to eq(labels)
  end

  it "makes next_action exactly equal to the complete first step" do
    path = build(mixed)
    expect(path[:next_action]).to eq(path[:steps].first)
    expect(path[:next_action].keys).to match_array([ :category, :order, :title, :instruction, :completion_evidence ])
  end

  it "provides the exact step fields and nonblank activity content for every mode" do
    %w[not_identified uncertain identified].each do |classification|
      steps = build(categories.to_h { |category| [ category, classification ] })[:steps]
      steps.each do |step|
        expect(step.keys).to match_array([ :category, :order, :title, :instruction, :completion_evidence ])
        %i[title instruction completion_evidence].each do |field|
          expect(step[field]).to be_a(String)
          expect(step[field].strip).not_to be_empty
        end
        expect(step.values.grep(String).join(" ")).not_to match(/Ruby|Rails|JavaScript|Node\.js|RSpec/)
      end
    end
  end

  # Public invalid-input contract: a complete string-keyed map is required.
  # Pair arrays retain duplicates which ordinary Hash construction would erase.
  [ "missing category", "unexpected category", "mixed key overlap", "duplicate pairs",
    "unknown classification", "nil classification", "symbol classification", "empty map", "nil input", "array input" ].each do |label|
    it "rejects #{label} rather than deriving a partial path" do
      input = case label
      when "missing category" then identified.except("SQL")
      when "unexpected category" then identified.merge("Deployment" => "identified")
      when "mixed key overlap" then identified.merge(SQL: "uncertain")
      when "duplicate pairs" then identified.to_a + [ [ "SQL", "uncertain" ] ]
      when "unknown classification" then identified.merge("SQL" => "expert")
      when "nil classification" then identified.merge("SQL" => nil)
      when "symbol classification" then identified.merge("SQL" => :identified)
      when "empty map" then {}
      when "nil input" then nil
      when "array input" then []
      end
      expect { build(input) }.to raise_error(ArgumentError)
    end
  end

  it "does not mutate input classifications, including frozen input" do
    input = mixed.transform_keys { |key| key.dup.freeze }.transform_values { |value| value.dup.freeze }.freeze
    original = input.dup
    build(input)
    expect(input).to eq(original)
  end
end
