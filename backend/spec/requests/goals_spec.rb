require "rails_helper"

RSpec.describe "Goal creation", type: :request do
  it "persists a valid goal and returns its ID and description" do
    description = "Become a backend developer"

    expect {
      post "/api/goals", params: { goal: { description: description } }, as: :json
    }.to change { Goal.count }.by(1)

    expect(response).to have_http_status(:created)

    persisted_goal = Goal.order(:id).last
    expect(persisted_goal.description).to eq(description)
    expect(response.parsed_body).to eq(
      "goal" => { "id" => persisted_goal.id, "description" => persisted_goal.description }
    )
  end

  it "rejects a missing description without creating a goal" do
    expect {
      post "/api/goals", params: { goal: {} }, as: :json
    }.not_to change { Goal.count }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body).to eq("errors" => { "description" => ["can't be blank"] })
  end

  it "rejects an empty description without creating a goal" do
    expect {
      post "/api/goals", params: { goal: { description: "" } }, as: :json
    }.not_to change { Goal.count }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body).to eq("errors" => { "description" => ["can't be blank"] })
  end

  it "rejects a whitespace-only description without creating a goal" do
    expect {
      post "/api/goals", params: { goal: { description: " \t\n " } }, as: :json
    }.not_to change { Goal.count }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body).to eq("errors" => { "description" => ["can't be blank"] })
  end

  it "persists a description of exactly 500 characters" do
    description = "a" * 500

    expect {
      post "/api/goals", params: { goal: { description: description } }, as: :json
    }.to change { Goal.count }.by(1)

    expect(response).to have_http_status(:created)
    persisted_goal = Goal.order(:id).last
    expect(persisted_goal.description).to eq(description)
    expect(response.parsed_body).to eq(
      "goal" => { "id" => persisted_goal.id, "description" => description }
    )
  end

  it "rejects a description longer than 500 characters without creating a goal" do
    expect {
      post "/api/goals", params: { goal: { description: "a" * 501 } }, as: :json
    }.not_to change { Goal.count }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body).to eq(
      "errors" => { "description" => ["is too long (maximum is 500 characters)"] }
    )
  end

  it "rejects a non-string description without creating a goal" do
    expect {
      post "/api/goals", params: { goal: { description: ["Become a backend developer"] } }, as: :json
    }.not_to change { Goal.count }

    expect(response).to have_http_status(:unprocessable_entity)
    expect(response.parsed_body).to eq("errors" => { "description" => ["must be a string"] })
  end

  it "returns a predictable JSON error when the goal parameter is missing" do
    expect {
      post "/api/goals", params: {}, as: :json
    }.not_to change { Goal.count }

    expect(response).to have_http_status(:bad_request)
    expect(response.media_type).to eq("application/json")
    expect(response.parsed_body).to eq("errors" => { "goal" => ["is required"] })
  end

  it "ignores unpermitted ID and creation timestamp attributes" do
    description = "Become a backend developer"
    supplied_id = -1
    supplied_created_at = "2000-01-01T00:00:00Z"

    expect {
      post "/api/goals", params: {
        goal: { description: description, id: supplied_id, created_at: supplied_created_at }
      }, as: :json
    }.to change { Goal.count }.by(1)

    expect(response).to have_http_status(:created)
    persisted_goal = Goal.order(:id).last
    expect(persisted_goal.id).not_to eq(supplied_id)
    expect(persisted_goal.created_at).not_to eq(Time.iso8601(supplied_created_at))
    expect(persisted_goal.created_at).to be_present
    expect(persisted_goal.description).to eq(description)
    expect(response.parsed_body).to eq(
      "goal" => { "id" => persisted_goal.id, "description" => description }
    )
  end
end
