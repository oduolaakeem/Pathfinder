require "net/http"

module Api
  class SkillGapsController < ApplicationController
    wrap_parameters false

    CATEGORIES = [ "Programming language", "SQL", "Git", "HTTP/API concepts", "Automated testing" ].freeze
    CLASSIFICATIONS = [ "identified", "not_identified", "uncertain" ].freeze

    def create
      goal = Goal.find_by(id: params[:goal_id])
      unless goal
        render json: { errors: { goal: [ "not found" ] } }, status: :not_found
        return
      end

      # This first slice supports only this explicit goal, ignoring case and outer whitespace.
      unless goal.description.strip.casecmp?("Become a backend developer")
        render json: { errors: { goal: [ "is not supported for skill gap identification" ] } }, status: :unprocessable_content
        return
      end
      current_skill = goal.current_skill
      unless current_skill
        render json: { errors: { current_skills: [ "must be saved before identifying skill gaps" ] } }, status: :unprocessable_content
        return
      end

      classifications = GeminiSkillGapProvider.classify(
        goal_description: goal.description,
        current_skills_description: current_skill.description
      )
      unless classifications.is_a?(Hash) && classifications.keys.all? { |key| key.is_a?(String) } &&
          classifications.keys.sort == CATEGORIES.sort &&
          classifications.values.all? { |value| CLASSIFICATIONS.include?(value) }
        render json: { errors: { skill_gap: [ "invalid provider result" ] } }, status: :bad_gateway
        return
      end

      render json: {
        skill_gap: {
          goal_id: goal.id,
          current_skill_id: current_skill.id,
          profile: "backend_development",
          profile_version: "1",
          method: "ai_assisted",
          identified_skills: CATEGORIES.select { |category| classifications[category] == "identified" },
          not_identified_skills: CATEGORIES.select { |category| classifications[category] == "not_identified" },
          uncertain_skills: CATEGORIES.select { |category| classifications[category] == "uncertain" }
        }
      }, status: :ok
    rescue GeminiSkillGapProvider::InvalidResponse
      render json: { errors: { skill_gap: [ "invalid provider result" ] } }, status: :bad_gateway
    rescue GeminiSkillGapProvider::Unavailable, Net::OpenTimeout, Net::ReadTimeout
      render json: { errors: { skill_gap: [ "provider unavailable" ] } }, status: :service_unavailable
    end
  end
end
