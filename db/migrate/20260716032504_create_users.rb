class CreateUsers < ActiveRecord::Migration[6.0]
  def change
    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest
      t.string :uid
      t.string :otp_code
      t.datetime :otp_expires_at
      t.boolean :is_verified, default: false

      t.timestamps
    end
    add_index :users, :email, unique: true
    add_index :users, :uid, unique: true
  end
end
