class Recomendations < ActiveRecord::Migration
  def change
    create_table :recomendations do |r|
      r.integer :work_id
      r.decimal :score
      r.string  :title
    end
  end
end
