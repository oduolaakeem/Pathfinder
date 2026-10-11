require "rails_helper"
require "net/http"

RSpec.describe "Skill gap identification", type: :request do
  it "returns a transient AI-assisted assessment for the persisted goal and current skills" do
    goal = Goal.create!(description: "Become a backend developer")
    current_skill = CurrentSkill.create!(
      goal: goal, description: "Ruby, SQL, Git; built a small Rails application"
    )
    classifications = {
      "Programming language" => "identified",
      "SQL" => "identified",
      "Git" => "identified",
      "HTTP/API concepts" => "uncertain",
      "Automated testing" => "not_identified"
    }

    # Planned provider boundary: GeminiSkillGapProvider.classify accepts only
    # server-loaded descriptions and returns category/classification pairs.
    # This fake tests API orchestration, not the accuracy of an AI assessment.
    provider = Class.new do
      def self.classify(goal_description:, current_skills_description:)
        raise "Provider must be stubbed in this request spec"
      end
    end
    stub_const("GeminiSkillGapProvider", provider)
    allow(provider).to receive(:classify).with(
      goal_description: goal.description,
      current_skills_description: current_skill.description
    ).and_return(classifications)
    allow(Net::HTTP).to receive(:new).and_raise("External HTTP is forbidden in this request spec")
    allow(Net::HTTP).to receive(:start).and_raise("External HTTP is forbidden in this request spec")

    expect {
      post "/api/goals/#{goal.id}/skill_gap", params: {}, as: :json
    }.not_to change { [ Goal.count, CurrentSkill.count ] }

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body).to eq(
      "skill_gap" => {
        "goal_id" => goal.id,
        "current_skill_id" => current_skill.id,
        "profile" => "backend_development",
        "profile_version" => "1",
        "method" => "ai_assisted",
        "identified_skills" => [ "Programming language", "SQL", "Git" ],
        "not_identified_skills" => [ "Automated testing" ],
        "uncertain_skills" => [ "HTTP/API concepts" ]
      }
    )
    expect(provider).to have_received(:classify).with(
      goal_description: goal.description,
      current_skills_description: current_skill.description
    ).once
  end

  describe "validation and error contracts" do
    let(:goal) { Goal.create!(description: "Become a backend developer") }
    let(:current_skill) { CurrentSkill.create!(goal: goal, description: "SYNTHETIC_SKILLS_7C Ruby, SQL, Git") }
    let(:classifications) do
      {
        "Programming language" => "identified", "SQL" => "identified", "Git" => "identified",
        "HTTP/API concepts" => "uncertain", "Automated testing" => "not_identified"
      }
    end

    before do
      allow(Net::HTTP).to receive(:new).and_raise("External HTTP forbidden")
      allow(Net::HTTP).to receive(:start).and_raise("External HTTP forbidden")
      allow(GeminiSkillGapProvider).to receive(:classify).and_return(classifications)
    end

    # Includes full attributes so updates, as well as new records, are detected.
    def persisted_state
      [ Goal.order(:id).map(&:attributes), CurrentSkill.order(:id).map(&:attributes) ]
    end

    def submit(goal_id, payload = {})
      expect {
        post "/api/goals/#{goal_id}/skill_gap", params: payload, as: :json
      }.not_to change { persisted_state }
    end

    def expect_error(status, field, message)
      expect(response).to have_http_status(status)
      expect(response.media_type).to eq("application/json")
      expect(response.parsed_body).to eq("errors" => { field => [ message ] })
    end

    it "returns 404 for an unknown goal without invoking the provider" do
      submit(-1)
      expect_error(:not_found, "goal", "not found")
      expect(GeminiSkillGapProvider).not_to have_received(:classify)
    end

    it "requires saved current skills without invoking the provider" do
      submit(goal.id)
      expect_error(:unprocessable_content, "current_skills", "must be saved before identifying skill gaps")
      expect(GeminiSkillGapProvider).not_to have_received(:classify)
    end

    [ "Become a frontend developer", "Become a developer", "Maybe backend development or design", "Become a nurse" ].each do |description|
      it "rejects the unsupported or ambiguous goal #{description.inspect}" do
        unsupported = Goal.create!(description: description)
        CurrentSkill.create!(goal: unsupported, description: "Synthetic Ruby, SQL, Git")
        submit(unsupported.id)
        expect_error(:unprocessable_content, "goal", "is not supported for skill gap identification")
        expect(GeminiSkillGapProvider).not_to have_received(:classify)
      end
    end

    [ "BECOME A BACKEND DEVELOPER", "  Become a backend developer \t\n", "  bEcOmE a BaCkEnD dEvElOpEr  " ].each do |description|
      it "accepts case and surrounding whitespace in #{description.inspect}" do
        supported = Goal.create!(description: description)
        skills = CurrentSkill.create!(goal: supported, description: "Synthetic Ruby, SQL, Git")
        submit(supported.id)
        expect(response).to have_http_status(:ok)
        expect(response.parsed_body).to eq("skill_gap" => {
          "goal_id" => supported.id, "current_skill_id" => skills.id,
          "profile" => "backend_development", "profile_version" => "1", "method" => "ai_assisted",
          "identified_skills" => [ "Programming language", "SQL", "Git" ],
          "not_identified_skills" => [ "Automated testing" ], "uncertain_skills" => [ "HTTP/API concepts" ]
        })
        expect(GeminiSkillGapProvider).to have_received(:classify).with(
          goal_description: supported.description, current_skills_description: skills.description
        ).once
      end
    end

    it "uses persisted descriptions rather than client replacements and leaves both records unchanged" do
      current_skill
      submit(goal.id, goal: { description: "CLIENT_GOAL_REPLACEMENT" },
        current_skills: { description: "CLIENT_SKILLS_REPLACEMENT" })
      expect(response).to have_http_status(:ok)
      expect(GeminiSkillGapProvider).to have_received(:classify).with(
        goal_description: goal.description, current_skills_description: current_skill.description
      ).once
    end

    # Generic contract: all unusable classification results return exactly this 502.
    [
      "missing category", "unexpected category", "invalid classification", "null classification",
      "mixed key types", "duplicate category pairs", "nil", "empty object", "array", "raw text"
    ].each do |label|
      it "returns a generic 502 for #{label} without a partial assessment" do
        current_skill
        invalid = case label
        when "missing category" then classifications.except("SQL")
        when "unexpected category" then classifications.merge("Deployment" => "identified")
        when "invalid classification" then classifications.merge("SQL" => "proficient")
        when "null classification" then classifications.merge("SQL" => nil)
        when "mixed key types" then classifications.except("SQL").merge(SQL: "identified")
        # Hashes cannot represent duplicate keys; pairs retain duplicates at the fake boundary.
        when "duplicate category pairs" then classifications.to_a + [[ "SQL", "uncertain" ]]
        when "nil" then nil
        when "empty object" then {}
        when "array" then []
        when "raw text" then "SYNTHETIC_RAW_PROVIDER_7C SYNTHETIC_SECRET_7C #{current_skill.description} #{goal.description}"
        end
        allow(GeminiSkillGapProvider).to receive(:classify).and_return(invalid)
        submit(goal.id)
        expect_error(:bad_gateway, "skill_gap", "invalid provider result")
        [ goal.description, current_skill.description, "SYNTHETIC_RAW_PROVIDER_7C", "SYNTHETIC_SECRET_7C" ].each do |sensitive|
          expect(response.body).not_to include(sensitive)
        end
      end
    end

    # Generic contract: availability and timeout failures share the same safe 503.
    [ "unavailable", "connect timeout", "read timeout" ].each do |label|
      it "returns a private generic 503 for #{label}" do
        current_skill
        sensitive = "SYNTHETIC_SECRET_7C SYNTHETIC_RAW_PROVIDER_7C #{goal.description} #{current_skill.description}"
        error_class = case label
        when "unavailable" then GeminiSkillGapProvider::Unavailable
        when "connect timeout" then Net::OpenTimeout
        when "read timeout" then Net::ReadTimeout
        end
        allow(GeminiSkillGapProvider).to receive(:classify).and_raise(error_class, sensitive)
        submit(goal.id)
        expect_error(:service_unavailable, "skill_gap", "provider unavailable")
        [ "SYNTHETIC_SECRET_7C", "SYNTHETIC_RAW_PROVIDER_7C", goal.description, current_skill.description ].each do |text|
          expect(response.body).not_to include(text)
        end
      end
    end
  end
end
