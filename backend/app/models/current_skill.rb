class CurrentSkill < ApplicationRecord
  belongs_to :goal

  validate :validate_description

  private

  def validate_description
    value = description_before_type_cast
    if value.nil? || value.is_a?(String) && value.blank?
      errors.add(:description, :blank)
    elsif !value.is_a?(String)
      errors.add(:description, "must be a string")
    elsif value.length > 2000
      errors.add(:description, :too_long, count: 2000)
    end
  end
end
