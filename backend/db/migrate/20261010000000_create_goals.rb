class CreateGoals < ActiveRecord::Migration[8.1]
  def change
    create_table :goals do |t|
      t.text :description, null: false

      t.timestamps
    end
  end
end
