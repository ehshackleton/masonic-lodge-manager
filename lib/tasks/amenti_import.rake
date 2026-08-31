# frozen_string_literal: true

namespace :amenti do
  desc "Importa Ficha Maestra (+ Actas ODS opcional) a la BD. Uso: FICHA=/path.ods ACTAS=/path.ods bin/rails amenti:import_ods"
  task import_ods: :environment do
    require Rails.root.join("lib/amenti/ods_reader")
    require Rails.root.join("lib/amenti/import_from_ods")

    ficha = ENV.fetch("FICHA") do
      Dir.glob(Rails.root.join("Amenti*_Ficha*.ods")).first ||
        Dir.glob(Rails.root.join("Amenti _ Ficha*.ods")).first
    end
    actas = ENV["ACTAS"].presence || Dir.glob(Rails.root.join("Amenti*—Gesti*.ods")).first ||
            Dir.glob(Rails.root.join("Amenti — Gesti*.ods")).first

    abort "Defina FICHA=/ruta/ficha.ods (archivo local, no versionado)" if ficha.blank? || !File.exist?(ficha)

    lodge = Lodge.find_by(number: "31") || Lodge.order(:id).first
    abort "No hay Lodge en BD; ejecute db:seed primero" unless lodge

    puts "Importando ficha: #{File.basename(ficha)}"
    puts "Importando actas: #{actas ? File.basename(actas) : '(omitido)'}"

    stats = Amenti::ImportFromOds.new(lodge: lodge, ficha_path: ficha, actas_path: actas).call
    puts "Listo: #{stats.inspect}"
    puts "Brothers=#{Brother.where(lodge: lodge).count} Tenidas=#{Tenida.where(lodge: lodge).count} " \
         "Correspondencias=#{Correspondence.where(lodge: lodge).count} Trabajos=#{MasonicWork.where(lodge: lodge).count}"
  end
end
