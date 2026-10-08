require "rails_helper"

RSpec.describe "Database connection" do
  it "uses PostgreSQL in the Rails test environment" do
    expect(Rails.env).to eq("test")
    expect(ActiveRecord::Base.connection.adapter_name).to eq("PostgreSQL")
    expect(ActiveRecord::Base.connection.current_database).to eq("pathfinder_test")
  end
end
