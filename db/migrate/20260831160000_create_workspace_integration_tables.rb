class CreateWorkspaceIntegrationTables < ActiveRecord::Migration[8.1]
  def change
    create_table :workspace_connections do |t|
      t.references :lodge, null: false, foreign_key: true
      t.string :provider, null: false, default: "google"
      t.string :account_email
      t.text :access_token_ciphertext
      t.text :refresh_token_ciphertext
      t.datetime :expires_at
      t.text :scopes
      t.string :status, null: false, default: "disconnected"
      t.datetime :last_synced_at
      t.text :last_error
      t.timestamps
    end
    add_index :workspace_connections, [ :lodge_id, :provider ], unique: true

    create_table :workspace_links do |t|
      t.references :lodge, null: false, foreign_key: true
      t.string :linkable_type, null: false
      t.bigint :linkable_id, null: false
      t.string :provider, null: false, default: "google"
      t.string :resource_type, null: false
      t.string :external_id, null: false
      t.string :external_url
      t.jsonb :metadata, null: false, default: {}
      t.timestamps
    end
    add_index :workspace_links, [ :linkable_type, :linkable_id ]
    add_index :workspace_links, [ :provider, :resource_type, :external_id ], unique: true, name: "idx_workspace_links_external"
    add_index :workspace_links, [ :lodge_id, :resource_type ]
  end
end
