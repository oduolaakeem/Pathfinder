module Api
  class CurrentSkillsController < ApplicationController
    wrap_parameters false

    def create
      goal = Goal.find_by(id: params[:goal_id])
      unless goal
        render json: { errors: { goal: [ "not found" ] } }, status: :not_found
        return
      end

      attributes = params[:current_skills]
      unless attributes.is_a?(ActionController::Parameters)
        render json: { errors: { current_skills: [ "is required" ] } }, status: :bad_request
        return
      end

      if attributes.key?(:description) && !attributes[:description].is_a?(String)
        render json: { errors: { description: [ "must be a string" ] } }, status: :unprocessable_content
        return
      end

      if CurrentSkill.exists?(goal_id: goal.id)
        render_duplicate
        return
      end

      current_skill = CurrentSkill.new(attributes.permit(:description))
      current_skill.goal = goal
      saved = CurrentSkill.transaction(requires_new: true) { current_skill.save }
      unless saved
        render json: { errors: current_skill.errors.to_hash }, status: :unprocessable_content
        return
      end

      render json: {
        current_skills: {
          id: current_skill.id,
          goal_id: current_skill.goal_id,
          description: current_skill.description
        }
      }, status: :created
    rescue ActiveRecord::RecordNotUnique => error
      cause = error.cause
      unless cause.is_a?(PG::UniqueViolation) &&
          cause.result.error_field(PG::Result::PG_DIAG_CONSTRAINT_NAME) == "index_current_skills_on_goal_id"
        raise
      end

      render_duplicate
    end

    private

    def render_duplicate
      render json: { errors: { current_skills: [ "already submitted for this goal" ] } }, status: :conflict
    end
  end
end
