# frozen_string_literal: true

class CreateCertificateIssues < ActiveRecord::Migration[8.1]
  def change
    create_table :certificate_issues do |t|
      t.references :lodge, null: false, foreign_key: true
      t.references :brother, null: false, foreign_key: true
      t.references :issued_by_user, null: false, foreign_key: { to_table: :users }
      t.string :certificate_type, null: false, default: "active_member"
      t.string :folio, null: false
      t.string :token, null: false
      t.string :verification_code, null: false
      t.string :digest, null: false
      t.date :issued_on, null: false
      t.datetime :revoked_at

      t.timestamps
    end

    add_index :certificate_issues, :folio, unique: true
    add_index :certificate_issues, :token, unique: true
    add_index :certificate_issues, :verification_code, unique: true
    add_index :certificate_issues, %i[lodge_id certificate_type issued_on]
  end
end
