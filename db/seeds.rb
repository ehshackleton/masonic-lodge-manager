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
