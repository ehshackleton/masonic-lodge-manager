# frozen_string_literal: true

module Amenti
  class ImportFromOds
    OFFICE_ALIASES = {
      "venerable maestro" => "venerable_maestro",
      "v:.m:." => "venerable_maestro",
      "primer vigilante" => "primer_vigilante",
      "p:.v:." => "primer_vigilante",
      "segundo vigilante" => "segundo_vigilante",
      "s:.v:." => "segundo_vigilante",
      "orador" => "orador",
      "secretario" => "secretario",
      "tesorero" => "tesorero",
      "hospitalario" => "hospitalario",
      "experto" => "experto",
      "maestro de ceremonias" => "maestro_de_ceremonias",
      "maestro de ceremonia" => "maestro_de_ceremonias",
      "guarda templo" => "guarda_templo"
    }.freeze

    DEGREE_ALIASES = {
      "aprendiz" => "aprendiz",
      "aa" => "aprendiz",
      "companero" => "companero",
      "compañero" => "companero",
      "cc" => "companero",
      "maestro" => "maestro",
      "mm" => "maestro"
    }.freeze

    def initialize(lodge:, ficha_path:, actas_path: nil)
      @lodge = lodge
      @ficha = OdsReader.new(ficha_path)
      @actas = actas_path.present? ? OdsReader.new(actas_path) : nil
      @stats = Hash.new(0)
      @brothers_by_name = {}
    end

    def call
      ActiveRecord::Base.transaction do
        import_ficha_members!
        import_cache_members! if @actas
        import_tenidas! if @actas
        import_correspondence! if @actas
        import_works! if @actas
      end
      @stats
    end

    private

    def import_ficha_members!
      forms = index_forms_by_rut
      @ficha.sheet_as_hashes("REVISION_SECRETARIA").each do |rev|
        next unless rev["Estado revisión"].to_s.upcase.include?("VALIDADO")

        rut = normalize_rut(rev["RUT"])
        form = forms[rut] || {}
        name = form["Nombre y apellido"].presence || rev["Nombre"]
        brother = upsert_brother!(
          full_name: name,
          national_id: rut,
          email: form["Correo electrónico personal"].presence || rev["Correo"],
          mobile_phone: form["Teléfono móvil"].presence || rev["Móvil"],
          birth_date: parse_date(form["Fecha de nacimiento"]),
          address: form["Dirección particular"],
          city: form["Comuna"],
          profession: form["Profesión, título(s) o especialidad(es)"],
          employer: form["Organización, empresa o institución donde desarrolla su actividad"],
          degree_key: degree_key_for(form["Grado actual"].presence || rev["Grado"]),
          initiation_date: parse_date(form["Fecha de iniciación"]),
          raising_date: parse_date(form["Fecha de aumento de salario"]),
          exaltation_date: parse_date(form["Fecha de exaltación"]),
          emergency_contact_name: form["Nombre de contacto de emergencia"],
          emergency_contact_phone: form["Teléfono del contacto de emergencia"],
          notes_private: build_notes(form, rev),
          office_label: rev["Cargo actual"].presence || form["Cargo o función actual en Amenti"]
        )
        index_brother(brother)
        @stats[:brothers_ficha] += 1
      end
    end

    def import_cache_members!
      @actas.sheet_as_hashes("18_MIEMBROS_CACHE").each do |row|
        name = row["Nombre"]
        next if name.blank?

        existing = find_brother_by_name(name)
        if existing
          assign_offices!(existing, row["Rol actual confirmado"])
          ensure_degree!(existing, degree_key_for(row["Condición fuente"]))
          index_brother(existing)
          @stats[:brothers_cache_updated] += 1
          next
        end

        brother = upsert_brother!(
          full_name: name,
          national_id: nil,
          email: nil,
          mobile_phone: nil,
          degree_key: degree_key_for(row["Condición fuente"]),
          office_label: row["Rol actual confirmado"],
          notes_private: "Importado desde cache de miembros (sin ficha validada completa)."
        )
        index_brother(brother)
        @stats[:brothers_cache_created] += 1
      end
    end

    def import_tenidas!
      @actas.sheet_as_hashes("02_TENIDAS").each do |row|
        code = row["tenida_id"].presence
        next if code.blank?

        held_on = parse_date(row["fecha"])
        next unless held_on

        degree = Degree.find_by(rank_order: row["grado"].to_i) || degree_from_rank(row["grado"])
        tenida = Tenida.find_or_initialize_by(lodge: @lodge, code: code)
        tenida.assign_attributes(
          held_on: held_on,
          tenida_type: "regular",
          place: row["lugar"].presence || "Templo",
          status: tenida_status_for(row["estado"]),
          degree: degree,
          notes: [
            ("VM fuente: #{row['venerable_maestro']}" if row["venerable_maestro"].present?),
            ("Orador fuente: #{row['orador']}" if row["orador"].present?),
            ("Secretario fuente: #{row['secretario']}" if row["secretario"].present?),
            ("Calendar: #{row['calendar_event_id']}" if row["calendar_event_id"].present?)
          ].compact.join("\n")
        )

        vm_row = @actas.sheet_as_hashes("03_OFICIALIDAD").find do |o|
          o["tenida_id"] == code && o["cargo_codigo"].to_s.upcase.in?(%w[VM])
        end
        if vm_row
          brother = find_brother_by_name(vm_row["miembro"])
          if brother
            tenida.presiding_brother = brother
            tenida.presiding_capacity = vm_row["condicion"].to_s.upcase.include?("P.T") ? "pt" : "titular"
          end
        end

        tenida.save!
        @stats[:tenidas] += 1
      end
    end

    def import_correspondence!
      @actas.sheet_as_hashes("07_CORRESPONDENCIA").each do |row|
        subject = row["asunto"].presence || "(sin asunto)"
        received_on = parse_date(row["fecha"]) || Date.current
        direction = row["direccion"].to_s.upcase.include?("SALIDA") ? "outgoing" : "incoming"

        exists = Correspondence.where(lodge: @lodge, subject: subject, received_on: received_on)
                               .or(Correspondence.where(lodge: @lodge, subject: subject, sent_on: received_on))
                               .exists?
        next if exists

        Correspondence.create!(
          lodge: @lodge,
          direction: direction,
          status: "draft",
          confidentiality_level: "internal",
          subject: subject.truncate(500),
          sender_name: (direction == "incoming" ? row["origen_destino"] : nil),
          recipient_name: (direction == "outgoing" ? row["origen_destino"] : nil),
          received_on: (direction == "incoming" ? received_on : nil),
          sent_on: (direction == "outgoing" ? received_on : nil),
          summary: [ row["resumen"], row["tenida_id"], row["drive_url"] ].compact.join(" — ").truncate(1000)
        )
        @stats[:correspondences] += 1
      end
    end

    def import_works!
      @actas.sheet_as_hashes("09_TRABAJOS").each do |row|
        title = row["titulo"].presence
        next if title.blank?

        brother = find_brother_by_name(row["autor"])
        next unless brother

        work = MasonicWork.find_or_initialize_by(lodge: @lodge, brother: brother, title: title)
        work.assign_attributes(
          status: work_status_for(row["estado"]),
          degree: Degree.find_by(rank_order: row["grado"].to_i),
          abstract: row["sentencia_orador"],
          private_notes: [ row["observacion"], row["drive_url"], row["tenida_id"] ].compact.join("\n"),
          presented_on: tenida_date_for(row["tenida_id"])
        )
        work.save!
        @stats[:works] += 1
      end
    end

    def index_forms_by_rut
      @ficha.sheet_as_hashes("Form Responses 1").each_with_object({}) do |row, acc|
        rut = normalize_rut(row["RUT"])
        acc[rut] = row if rut.present?
      end
    end

    def upsert_brother!(full_name:, national_id:, email:, mobile_phone:, degree_key:,
                        birth_date: nil, address: nil, city: nil, profession: nil, employer: nil,
                        initiation_date: nil, raising_date: nil, exaltation_date: nil,
                        emergency_contact_name: nil, emergency_contact_phone: nil,
                        notes_private: nil, office_label: nil)
      first_name, last_name = split_name(full_name)
      registry = national_id.presence || "A31-TMP-#{Digest::SHA1.hexdigest(full_name.to_s.downcase)[0, 8].upcase}"

      brother = if national_id.present?
                  Brother.find_or_initialize_by(national_id: national_id)
      else
                  Brother.where(lodge: @lodge).find { |b| normalize_name(b.full_name) == normalize_name(full_name) } ||
                    Brother.new(lodge: @lodge)
      end
      brother.lodge = @lodge
      brother.registry_number = brother.registry_number.presence || registry
      brother.first_name = first_name
      brother.last_name = last_name
      brother.national_id = national_id if national_id.present?
      brother.email = email if email.present?
      brother.mobile_phone = mobile_phone if mobile_phone.present?
      brother.birth_date = birth_date if birth_date
      brother.address = address if address.present?
      brother.city = city if city.present?
      brother.profession = profession if profession.present?
      brother.employer = employer if employer.present?
      brother.initiation_date = initiation_date if initiation_date
      brother.raising_date = raising_date if raising_date
      brother.exaltation_date = exaltation_date if exaltation_date
      brother.emergency_contact_name = emergency_contact_name if emergency_contact_name.present?
      brother.emergency_contact_phone = emergency_contact_phone if emergency_contact_phone.present?
      brother.notes_private = [ brother.notes_private, notes_private ].compact.reject(&:blank?).uniq.join("\n\n") if notes_private.present?
      brother.membership_status = "active"
      brother.active = true
      brother.save!

      ensure_degree!(brother, degree_key, initiation_date: initiation_date, raising_date: raising_date, exaltation_date: exaltation_date)
      assign_offices!(brother, office_label)
      brother
    end

    def ensure_degree!(brother, degree_key, initiation_date: nil, raising_date: nil, exaltation_date: nil)
      return if degree_key.blank?

      degree = Degree.find_by!(key: degree_key)
      brother.update!(current_degree: degree) if brother.current_degree_id != degree.id

      ceremony = case degree_key
                 when "aprendiz" then initiation_date || brother.initiation_date || Date.current
                 when "companero" then raising_date || brother.raising_date || Date.current
                 when "maestro" then exaltation_date || brother.exaltation_date || Date.current
                 else Date.current
      end

      BrotherDegreeHistory.find_or_create_by!(brother: brother, degree: degree) do |h|
        h.ceremony_date = ceremony
        h.notes = "Import ODS Amenti"
      end
    end

    def assign_offices!(brother, label)
      return if label.blank?
      return if label.to_s.match?(/sin cargo/i)

      label.split(/,|;/).each do |chunk|
        key = office_key_for(chunk)
        next unless key

        office = Office.find_by(key: key)
        next unless office

        existing = brother.brother_office_assignments.find { |a| a.office_id == office.id && a.end_date.nil? }
        next if existing

        brother.brother_office_assignments.create!(
          office: office,
          start_date: Date.current.beginning_of_year,
          notes: chunk.strip
        )
        @stats[:office_assignments] += 1
      end
    end

    def office_key_for(label)
      cleaned = label.to_s.downcase
                    .gsub(/\(.*?\)/, "")
                    .gsub(/adjunto|titular|past master|armonia|armonía/i, "")
                    .gsub(/\s+/, " ")
                    .strip
      OFFICE_ALIASES[cleaned]
    end

    def degree_key_for(label)
      DEGREE_ALIASES[label.to_s.downcase.strip]
    end

    def degree_from_rank(rank)
      Degree.find_by(rank_order: rank.to_i)
    end

    def tenida_status_for(raw)
      case raw.to_s.upcase
      when "ARCHIVADA" then "archived"
      when "EN_REDACCION", "EN REDACCION" then "minutes_draft"
      when "PLANIFICADA" then "planned"
      when "CITADA" then "cited"
      when "REALIZADA", "HELD" then "held"
      else "planned"
      end
    end

    def work_status_for(raw)
      case raw.to_s.upcase
      when "LEIDO", "LEÍDO", "PRESENTADO" then "presented"
      when "APROBADO" then "approved"
      when "ARCHIVADO" then "archived"
      else "assigned"
      end
    end

    def tenida_date_for(tenida_id)
      return if tenida_id.blank? || @actas.nil?

      row = @actas.sheet_as_hashes("02_TENIDAS").find { |r| r["tenida_id"] == tenida_id }
      parse_date(row&.dig("fecha"))
    end

    def build_notes(form, rev)
      bits = []
      bits << "Nacionalidad: #{form['Nacionalidad']}" if form["Nacionalidad"].present?
      bits << "Logia iniciación: #{form['Logia de iniciación']}" if form["Logia de iniciación"].present?
      bits << "Canal preferido: #{form['Canal preferido para comunicaciones']}" if form["Canal preferido para comunicaciones"].present?
      bits << "Cargo revisión: #{rev['Cargo actual']}" if rev["Cargo actual"].present?
      if form["Información adicional que quisiera comunicar a Secretaría"].present?
        bits << "Info adicional: #{form['Información adicional que quisiera comunicar a Secretaría']}"
      end
      bits.join("\n")
    end

    def split_name(full_name)
      parts = full_name.to_s.strip.split(/\s+/)
      return [ full_name.to_s.strip, "-" ] if parts.size < 2

      [ parts.first, parts[1..].join(" ") ]
    end

    def normalize_rut(value)
      value.to_s.upcase.gsub(/[^0-9K]/, "")
    end

    def normalize_name(name)
      I18n.transliterate(name.to_s).downcase.gsub(/[^a-z0-9]/, "")
    end

    def index_brother(brother)
      @brothers_by_name[normalize_name(brother.full_name)] = brother
      # common variants without middle names noise
      @brothers_by_name[normalize_name("#{brother.first_name} #{brother.last_name}")] = brother
    end

    def find_brother_by_name(name)
      return if name.blank?

      cleaned = name.to_s.sub(/\s*\(.*?\)\s*$/, "").strip
      key = normalize_name(cleaned)
      return @brothers_by_name[key] if @brothers_by_name[key]

      Brother.where(lodge: @lodge).find { |b| normalize_name(b.full_name) == key } ||
        Brother.where(lodge: @lodge).find { |b| normalize_name(b.full_name).include?(key) || key.include?(normalize_name(b.full_name)) }
    end

    def parse_date(value)
      return if value.blank?

      s = value.to_s.strip.split(/\s+/).first
      [
        "%m/%d/%Y",
        "%d/%m/%Y",
        "%Y-%m-%d",
        "%m/%d/%y",
        "%d-%m-%Y"
      ].each do |fmt|
        return Date.strptime(s, fmt)
      rescue ArgumentError
        next
      end
      Date.parse(s)
    rescue ArgumentError, TypeError
      nil
    end
  end
end
