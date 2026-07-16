class CreateSearchHistories < ActiveRecord::Migration[6.0]
  def change
    create_table :search_histories do |t|
      t.references :user, null: false, foreign_key: true
      t.string :city_name, null: false

      t.timestamps
    end
  end
end
