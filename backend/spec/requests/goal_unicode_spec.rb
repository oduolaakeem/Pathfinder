require "rails_helper"

RSpec.describe "Goal Unicode boundaries", type: :request do
  {
    "500 supplementary code points" => "\u{1F680}" * 500,
    "500 mixed ASCII and supplementary code points" => "a" * 250 + "\u{1F680}" * 250
  }.each do |boundary, description|
    it "persists #{boundary} without truncating the description" do
      expect {
        post "/api/goals", params: { goal: { description: description } }, as: :json
      }.to change { Goal.count }.by(1)

      expect(response).to have_http_status(:created)
      goal = Goal.find(response.parsed_body.dig("goal", "id"))
      expect(goal.description).to eq(description)
      expect(response.parsed_body).to eq("goal" => { "id" => goal.id, "description" => description })
    end
  end

  {
    "501 supplementary code points" => "\u{1F680}" * 501,
    "501 mixed ASCII and supplementary code points" => "a" * 251 + "\u{1F680}" * 250
  }.each do |boundary, description|
    it "rejects #{boundary} without persistence" do
      expect {
        post "/api/goals", params: { goal: { description: description } }, as: :json
      }.not_to change { Goal.count }

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.parsed_body).to eq(
        "errors" => { "description" => ["is too long (maximum is 500 characters)"] }
      )
    end
  end
end
