module Api
  class GoalsController < ApplicationController
    wrap_parameters false

    def create
      goal_parameters = params[:goal]
      unless goal_parameters.is_a?(ActionController::Parameters)
        render json: { errors: { goal: ["is required"] } }, status: :bad_request
        return
      end

      if goal_parameters.key?(:description) && !goal_parameters[:description].is_a?(String)
        render json: { errors: { description: ["must be a string"] } }, status: :unprocessable_content
        return
      end

      goal = Goal.new(goal_parameters.permit(:description))

      if goal.save
        render json: { goal: { id: goal.id, description: goal.description } }, status: :created
      else
        render json: { errors: goal.errors.to_hash }, status: :unprocessable_content
      end
    end
  end
end
