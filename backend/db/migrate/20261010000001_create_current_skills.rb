class CreateCurrentSkills < ActiveRecord::Migration[8.1]
  def change
    create_table :current_skills do |t|
      t.references :goal, null: false, foreign_key: true, index: { unique: true }
      t.text :description, null: false

      t.timestamps
    end
  end
end
