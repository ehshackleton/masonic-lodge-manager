class CreateCoreTables < ActiveRecord::Migration[8.1]
  def change
    create_table :lodges do |t|
      t.string :name, null: false
      t.string :number
      t.string :orient
      t.string :rite
      t.string :jurisdiction
      t.string :public_email
      t.string :public_phone
      t.string :address
      t.text :description
      t.boolean :active, null: false, default: true
      t.timestamps
    end

    create_table :users do |t|
      t.string :email, null: false
      t.string :password_digest
      t.boolean :active, null: false, default: true
      t.datetime :last_sign_in_at
      t.integer :failed_attempts, null: false, default: 0
      t.datetime :locked_at
      t.string :locale, default: "es"
      t.string :time_zone, default: "America/Santiago"
      t.timestamps
    end
    add_index :users, :email, unique: true

    create_table :roles do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.string :description
      t.timestamps
    end
    add_index :roles, :key, unique: true

    create_table :user_roles do |t|
      t.references :user, null: false, foreign_key: true
      t.references :role, null: false, foreign_key: true
      t.timestamps
    end
    add_index :user_roles, %i[user_id role_id], unique: true

    create_table :degrees do |t|
      t.string :key, null: false
      t.string :name, null: false
      t.integer :rank_order, null: false
      t.timestamps
    end
    add_index :degrees, :key, unique: true

    create_table :brothers do |t|
      t.references :lodge, null: false, foreign_key: true
      t.string :registry_number
      t.string :symbolic_name
      t.string :first_name
      t.string :last_name
      t.string :national_id
      t.date :birth_date
      t.string :email
      t.string :phone
      t.string :mobile_phone
      t.string :membership_status
      t.references :current_degree, foreign_key: { to_table: :degrees }
      t.text :notes_private
      t.boolean :active, null: false, default: true
      t.timestamps
    end
    add_index :brothers, :registry_number
    add_index :brothers, :symbolic_name
    add_index :brothers, :membership_status

    create_table :charges do |t|
      t.references :brother, null: false, foreign_key: true
      t.integer :period_year, null: false
      t.integer :period_month, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.date :due_on
      t.string :status, null: false, default: "pending"
      t.text :notes
      t.timestamps
    end
    add_index :charges, %i[brother_id status due_on]

    create_table :payments do |t|
      t.references :brother, null: false, foreign_key: true
      t.date :paid_on, null: false
      t.decimal :amount, precision: 12, scale: 2, null: false
      t.string :currency, null: false, default: "CLP"
      t.string :payment_method
      t.string :reference
      t.bigint :received_by_user_id
      t.text :notes
      t.timestamps
    end
    add_foreign_key :payments, :users, column: :received_by_user_id
    add_index :payments, %i[brother_id paid_on]

    create_table :minutes do |t|
      t.string :title, null: false
      t.date :session_date
      t.string :folio
      t.text :summary
      t.text :body
      t.string :status, default: "draft"
      t.string :visibility, default: "internal"
      t.bigint :created_by_user_id
      t.timestamps
    end
    add_foreign_key :minutes, :users, column: :created_by_user_id
    add_index :minutes, :session_date

    create_table :correspondences do |t|
      t.references :lodge, null: false, foreign_key: true
      t.string :direction, null: false
      t.string :document_type
      t.string :folio
      t.string :subject, null: false
      t.string :sender_name
      t.string :recipient_name
      t.date :sent_on
      t.date :received_on
      t.string :status, default: "draft"
      t.text :summary
      t.text :body
      t.string :confidentiality_level, default: "internal"
      t.bigint :created_by_user_id
      t.timestamps
    end
    add_foreign_key :correspondences, :users, column: :created_by_user_id
    add_index :correspondences, :folio

    create_table :masonic_works do |t|
      t.references :lodge, null: false, foreign_key: true
      t.references :brother, null: false, foreign_key: true
      t.string :title, null: false
      t.string :topic
      t.references :degree, foreign_key: true
      t.string :status, null: false, default: "assigned"
      t.date :assigned_on
      t.date :due_on
      t.date :presented_on
      t.bigint :reviewer_user_id
      t.text :abstract
      t.text :body
      t.text :private_notes
      t.timestamps
    end
    add_foreign_key :masonic_works, :users, column: :reviewer_user_id
    add_index :masonic_works, %i[brother_id status]

    create_table :public_pages do |t|
      t.string :slug, null: false
      t.string :title, null: false
      t.text :body
      t.boolean :published, null: false, default: false
      t.datetime :published_at
      t.string :seo_title
      t.string :seo_description
      t.timestamps
    end
    add_index :public_pages, :slug, unique: true

    create_table :contact_messages do |t|
      t.string :name, null: false
      t.string :email, null: false
      t.string :phone
      t.string :subject
      t.text :message, null: false
      t.string :status, null: false, default: "new"
      t.bigint :handled_by_user_id
      t.timestamps
    end
    add_foreign_key :contact_messages, :users, column: :handled_by_user_id

    create_table :audit_logs do |t|
      t.references :user, foreign_key: true
      t.string :action, null: false
      t.string :auditable_type, null: false
      t.bigint :auditable_id, null: false
      t.jsonb :metadata, default: {}
      t.string :ip_address
      t.string :user_agent
      t.timestamps
    end
    add_index :audit_logs, %i[auditable_type auditable_id]
  end
end
