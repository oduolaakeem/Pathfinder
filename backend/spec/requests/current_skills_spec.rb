require "rails_helper"

RSpec.describe "Current skills creation", type: :request do
  it "persists current skills for the specified goal and returns the saved record" do
    goal = Goal.create!(description: "Become a backend developer")
    description = "Ruby, SQL, Git; built a Rails application"

    expect {
      post "/api/goals/#{goal.id}/current_skills",
        params: { current_skills: { description: description } }, as: :json
    }.to change { CurrentSkill.count }.by(1)

    expect(response).to have_http_status(:created)

    persisted_skill = CurrentSkill.order(:id).last
    expect(persisted_skill.goal).to eq(goal)
    expect(persisted_skill.description).to eq(description)
    expect(response.parsed_body).to eq(
      "current_skills" => {
        "id" => persisted_skill.id,
        "goal_id" => goal.id,
        "description" => persisted_skill.description
      }
    )
  end

  describe "validation and error contracts" do
    let(:goal) { Goal.create!(description: "Become a backend developer") }
    let(:path) { "/api/goals/#{goal.id}/current_skills" }

    {
      "missing" => {},
      "empty" => { description: "" },
      "whitespace-only" => { description: " \t\n " }
    }.each do |label, attributes|
      it "rejects a #{label} description without persistence" do
        expect {
          post path, params: { current_skills: attributes }, as: :json
        }.not_to change { CurrentSkill.count }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body).to eq("errors" => { "description" => ["can't be blank"] })
      end
    end

    { "null" => nil, "numeric" => 42, "array" => ["Ruby"], "object" => { name: "Ruby" } }.each do |label, value|
      it "rejects a #{label} description without persistence" do
        expect {
          post path, params: { current_skills: { description: value } }, as: :json
        }.not_to change { CurrentSkill.count }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body).to eq("errors" => { "description" => ["must be a string"] })
      end
    end

    {
      "supplementary" => "\u{1F680}" * 2000,
      "mixed ASCII and supplementary" => "a" * 1000 + "\u{1F680}" * 1000
    }.each do |label, description|
      it "persists exactly 2000 #{label} code points without truncation" do
        expect {
          post path, params: { current_skills: { description: description } }, as: :json
        }.to change { CurrentSkill.count }.by(1)

        expect(response).to have_http_status(:created)
        saved = CurrentSkill.find(response.parsed_body.dig("current_skills", "id"))
        expect(saved.goal).to eq(goal)
        expect(saved.description).to eq(description)
        expect(response.parsed_body).to eq(
          "current_skills" => { "id" => saved.id, "goal_id" => goal.id, "description" => description }
        )
      end
    end

    {
      "supplementary" => "\u{1F680}" * 2001,
      "mixed ASCII and supplementary" => "a" * 1001 + "\u{1F680}" * 1000
    }.each do |label, description|
      it "rejects 2001 #{label} code points without persistence" do
        expect {
          post path, params: { current_skills: { description: description } }, as: :json
        }.not_to change { CurrentSkill.count }

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.parsed_body).to eq(
          "errors" => { "description" => ["is too long (maximum is 2000 characters)"] }
        )
      end
    end

    {
      "missing" => {},
      "null" => { current_skills: nil },
      "string" => { current_skills: "Ruby" },
      "numeric" => { current_skills: 42 },
      "array" => { current_skills: ["Ruby"] }
    }.each do |label, payload|
      it "returns a JSON 400 for a #{label} wrapper without persistence" do
        expect {
          post path, params: payload, as: :json
        }.not_to change { CurrentSkill.count }

        expect(response).to have_http_status(:bad_request)
        expect(response.media_type).to eq("application/json")
        expect(response.parsed_body).to eq("errors" => { "current_skills" => ["is required"] })
      end
    end

    it "returns a JSON 404 for an unknown goal without persistence" do
      expect {
        post "/api/goals/-1/current_skills",
          params: { current_skills: { description: "Synthetic Ruby skills" } }, as: :json
      }.not_to change { CurrentSkill.count }

      expect(response).to have_http_status(:not_found)
      expect(response.media_type).to eq("application/json")
      expect(response.parsed_body).to eq("errors" => { "goal" => ["not found"] })
    end

    it "returns a JSON 409 for a duplicate submission and preserves the original record" do
      original = CurrentSkill.create!(goal: goal, description: "Synthetic original skills")
      original_attributes = original.attributes

      expect {
        post path, params: { current_skills: { description: "Synthetic replacement skills" } }, as: :json
      }.not_to change { CurrentSkill.count }

      expect(response).to have_http_status(:conflict)
      expect(response.parsed_body).to eq("errors" => { "current_skills" => ["already submitted for this goal"] })
      expect(original.reload.attributes).to eq(original_attributes)
      expect(CurrentSkill.where(goal_id: goal.id).count).to eq(1)
    end

    it "ignores client IDs, goal association, and timestamps" do
      other_goal = Goal.create!(description: "Synthetic other goal")
      description = "Synthetic Ruby and SQL skills"
      supplied_time = "2000-01-01T00:00:00Z"

      expect {
        post path, params: { current_skills: {
          description: description, id: -1, goal_id: other_goal.id,
          created_at: supplied_time, updated_at: supplied_time
        } }, as: :json
      }.to change { CurrentSkill.count }.by(1)

      expect(response).to have_http_status(:created)
      saved = CurrentSkill.find(response.parsed_body.dig("current_skills", "id"))
      expect(saved.id).not_to eq(-1)
      expect(saved.goal).to eq(goal)
      expect(saved.created_at).to be_present
      expect(saved.updated_at).to be_present
      expect(saved.created_at).not_to eq(Time.iso8601(supplied_time))
      expect(saved.updated_at).not_to eq(Time.iso8601(supplied_time))
      expect(saved.description).to eq(description)
      expect(CurrentSkill.where(goal_id: other_goal.id).count).to eq(0)
      expect(response.parsed_body).to eq(
        "current_skills" => { "id" => saved.id, "goal_id" => goal.id, "description" => description }
      )
    end
  end

  describe "database constraints" do
    let(:goal) { Goal.create!(description: "Synthetic constraint test goal") }

    it "requires a goal association at the model boundary" do
      skill = CurrentSkill.new(description: "Synthetic Ruby skills")
      expect(skill).not_to be_valid
      expect(skill.errors[:goal]).to include("must exist")
      expect { skill.save }.not_to change { CurrentSkill.count }
    end

    {
      "a null goal" => [nil, ActiveRecord::NotNullViolation],
      "a nonexistent goal" => [-1, ActiveRecord::InvalidForeignKey]
    }.each do |label, (goal_id, error)|
      it "rejects #{label} at the database boundary" do
        expect {
          expect {
            CurrentSkill.transaction(requires_new: true) do
              CurrentSkill.insert_all!([{ goal_id: goal_id, description: "Synthetic constraint skills" }])
            end
          }.to raise_error(error)
        }.not_to change { CurrentSkill.count }
      end
    end

    it "enforces one submission per goal even when model validation is bypassed" do
      original = CurrentSkill.create!(goal: goal, description: "Synthetic original skills")
      expect {
        expect {
          CurrentSkill.transaction(requires_new: true) do
            CurrentSkill.insert_all!([{ goal_id: goal.id, description: "Synthetic duplicate skills" }])
          end
        }.to raise_error(ActiveRecord::RecordNotUnique)
      }.not_to change { CurrentSkill.count }

      expect(original.reload.description).to eq("Synthetic original skills")
      expect(CurrentSkill.where(goal_id: goal.id).count).to eq(1)
    end
  end
end
