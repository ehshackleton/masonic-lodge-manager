# frozen_string_literal: true

module Amenti
  class ImportWorksProgram
    def initialize(lodge:, program_path:)
      @lodge = lodge
      @program_path = program_path
      @program = YAML.safe_load_file(program_path, permitted_classes: [ Date ])
      @brothers_by_name = {}
      Brother.where(lodge: @lodge).find_each { |brother| index_brother(brother) }
      @stats = { created: 0, updated: 0, skipped: 0, missing_brothers: [] }
    end

    def call
      degree = Degree.find_by(key: @program["degree_key"]) ||
               Degree.find_by(rank_order: 1)

      program_key = @program["program_key"]
      program_label = @program["label"]
      assigned_on = parse_date(@program["assigned_on"])

      @program.fetch("works", []).each do |entry|
        brother = find_brother_by_name(entry["brother"])
        unless brother
          @stats[:missing_brothers] << entry["brother"]
          @stats[:skipped] += 1
          next
        end

        topic = entry["topic"].to_s.strip
        title = "#{entry['number']}. #{topic}"
        due_on = parse_date(entry["due_on"])

        work = MasonicWork.find_or_initialize_by(
          lodge: @lodge,
          brother: brother,
          title: title
        )
        was_new = work.new_record?

        work.assign_attributes(
          topic: topic,
          degree: degree,
          status: work.status.presence || "assigned",
          assigned_on: assigned_on,
          due_on: due_on,
          private_notes: program_note(program_key, program_label)
        )
        work.save!

        if was_new
          @stats[:created] += 1
        else
          @stats[:updated] += 1
        end
      end

      @stats
    end

    private

    def program_note(program_key, program_label)
      [
        "Programa: #{program_label}",
        "Clave: #{program_key}",
        "Fuente: Trabajos Primer Grado - 2do Semestre 2026.pdf"
      ].join("\n")
    end

    def parse_date(value)
      return value if value.is_a?(Date)
      return if value.blank?

      Date.parse(value.to_s)
    rescue ArgumentError
      nil
    end

    def normalize_name(name)
      I18n.transliterate(name.to_s).downcase.gsub(/[^a-z0-9]/, "")
    end

    def index_brother(brother)
      @brothers_by_name[normalize_name(brother.full_name)] = brother
      @brothers_by_name[normalize_name("#{brother.first_name} #{brother.last_name}")] = brother
    end

    def find_brother_by_name(name)
      return if name.blank?

      cleaned = name.to_s.sub(/\s*\(.*?\)\s*$/, "").strip
      key = normalize_name(cleaned)
      return @brothers_by_name[key] if @brothers_by_name[key]

      exact = Brother.where(lodge: @lodge).find { |b| normalize_name(b.full_name) == key }
      return exact if exact

      fuzzy = Brother.where(lodge: @lodge).find do |b|
        normalized = normalize_name(b.full_name)
        normalized.include?(key) || key.include?(normalized)
      end
      return fuzzy if fuzzy

      match_by_name_parts(cleaned)
    end

    def match_by_name_parts(name)
      parts = name.split(/\s+/).reject(&:blank?)
      return if parts.size < 2

      first_token = normalize_name(parts.first)
      last_token = normalize_name(parts.last)

      matches = Brother.where(lodge: @lodge).select do |brother|
        first_match = normalize_name(brother.first_name).start_with?(first_token) ||
                      first_token.start_with?(normalize_name(brother.first_name)[0, 3].to_s)
        last_match = normalize_name(brother.last_name).include?(last_token) ||
                     last_token.include?(normalize_name(brother.last_name))
        first_match && last_match
      end

      return matches.first if matches.one?

      matches.find do |brother|
        middle_tokens = parts[1..-2].map { |part| normalize_name(part) }
        brother_key = normalize_name(brother.full_name)
        middle_tokens.all? { |token| brother_key.include?(token) }
      end || matches.first
    end
  end
end
