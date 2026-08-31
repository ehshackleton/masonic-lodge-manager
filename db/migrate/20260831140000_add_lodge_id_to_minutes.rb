class AddLodgeIdToMinutes < ActiveRecord::Migration[8.1]
  def up
    add_reference :minutes, :lodge, foreign_key: true, null: true

    lodge_id = connection.select_value("SELECT id FROM lodges ORDER BY id ASC LIMIT 1")
    if lodge_id
      execute("UPDATE minutes SET lodge_id = #{connection.quote(lodge_id)} WHERE lodge_id IS NULL")
      change_column_null :minutes, :lodge_id, false
    end

    add_index :minutes, [ :lodge_id, :session_date ], name: "index_minutes_on_lodge_id_and_session_date"
  end

  def down
    remove_index :minutes, name: "index_minutes_on_lodge_id_and_session_date", if_exists: true
    remove_reference :minutes, :lodge, foreign_key: true
  end
end
