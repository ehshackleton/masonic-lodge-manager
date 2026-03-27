admin_email = "admin@logia.local"
admin_password = ENV.fetch("ADMIN_TEMP_PASSWORD", "Logia.Temp.2026!A9")

lodge = Lodge.find_or_create_by!(name: "Logia Demo") do |record|
  record.number = "001"
  record.orient = "Santiago"
  record.rite = "Escoces Antiguo y Aceptado"
  record.jurisdiction = "Chile"
  record.active = true
end

superadmin_role = Role.find_or_create_by!(key: "superadmin") do |record|
  record.name = "Superadmin"
  record.description = "Control total del sistema"
end

Role.find_or_create_by!(key: "secretario") do |record|
  record.name = "Secretario"
  record.description = "Puede aprobar y archivar trabajos masonicos"
end

[
  { key: "secretariat_manager", name: "Gestor de Secretaria", description: "Acceso total a Secretaria" },
  { key: "minute_editor", name: "Editor de actas", description: "Puede crear y editar actas" },
  { key: "minute_approver", name: "Aprobador de actas", description: "Puede aprobar y publicar actas" },
  { key: "correspondence_editor", name: "Editor de correspondencia", description: "Puede crear y editar correspondencia" },
  { key: "correspondence_approver", name: "Aprobador de correspondencia", description: "Puede aprobar y publicar correspondencia" },
  { key: "tesoreria_manager", name: "Gestor de tesoreria", description: "Acceso total a Tesoreria" },
  { key: "tesoreria_operator", name: "Operador de tesoreria", description: "Puede operar cargos y pagos" },
  { key: "tesoreria_closer", name: "Cierre de tesoreria", description: "Puede cerrar y reabrir periodos" },
  { key: "tesoreria_exporter", name: "Exportador de tesoreria", description: "Puede exportar reportes financieros" },
  { key: "work_reviewer", name: "Revisor de trabajos", description: "Puede enviar a revision y gestionar revisiones" },
  { key: "work_approver", name: "Aprobador de trabajos", description: "Puede aprobar trabajos masonicos" },
  { key: "work_presenter", name: "Presentador de trabajos", description: "Puede marcar trabajos como presentados" },
  { key: "work_archiver", name: "Archivador de trabajos", description: "Puede archivar trabajos masonicos" }
].each do |role_attrs|
  Role.find_or_create_by!(key: role_attrs[:key]) do |record|
    record.name = role_attrs[:name]
    record.description = role_attrs[:description]
  end
end

admin = User.find_or_initialize_by(email: admin_email)
admin.password = admin_password
admin.password_confirmation = admin_password
admin.active = true
admin.locked_at = nil
admin.failed_attempts = 0
admin.save!

UserRole.find_or_create_by!(user_id: admin.id, role_id: superadmin_role.id)

[
  { key: "aprendiz", name: "Aprendiz", rank_order: 1 },
  { key: "companero", name: "Companero", rank_order: 2 },
  { key: "maestro", name: "Maestro", rank_order: 3 }
].each do |degree_attrs|
  degree = Degree.find_or_initialize_by(key: degree_attrs[:key])
  degree.assign_attributes(name: degree_attrs[:name], rank_order: degree_attrs[:rank_order])
  degree.save!
end

[
  { key: "venerable_maestro", name: "Venerable Maestro", description: "Direccion de la logia" },
  { key: "primer_vigilante", name: "Primer Vigilante", description: "Supervision de columna" },
  { key: "segundo_vigilante", name: "Segundo Vigilante", description: "Apoyo de columna" },
  { key: "orador", name: "Orador", description: "Guia de doctrina y legalidad" },
  { key: "secretario", name: "Secretario", description: "Gestion documental y actas" },
  { key: "tesorero", name: "Tesorero", description: "Gestion financiera de la logia" }
].each do |office_attrs|
  office = Office.find_or_initialize_by(key: office_attrs[:key])
  office.assign_attributes(name: office_attrs[:name], description: office_attrs[:description])
  office.save!
end

treasury_setting = TreasurySetting.find_or_initialize_by(lodge: lodge)
treasury_setting.monthly_fee = 15000
treasury_setting.currency = "CLP"
treasury_setting.due_day = 10
treasury_setting.active = true
treasury_setting.save!

puts "Seed listo."
puts "Usuario admin: #{admin_email}"
puts "Contrasena temporal: #{admin_password}"
puts "Lodge base: #{lodge.name}"
puts "Cuota mensual base: #{treasury_setting.monthly_fee} #{treasury_setting.currency}"
