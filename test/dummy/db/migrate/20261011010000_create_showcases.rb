# frozen_string_literal: true

class CreateShowcases < ActiveRecord::Migration[8.1]
  def change
    create_table :showcases, id: :uuid do |t|
      t.string :title, null: false
      t.datetime :created_at, null: false
      t.datetime :updated_at, null: false
    end
  end
end
