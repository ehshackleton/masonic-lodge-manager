# frozen_string_literal: true

require "test_helper"
require "ostruct"

class Certificates::ActiveMemberPdfTest < ActiveSupport::TestCase
  setup do
    lodge = OpenStruct.new(
      name: "Amenti Diez N°31",
      number: "31",
      orient: "Santiago",
      jurisdiction: "Chile"
    )
    brother = OpenStruct.new(
      lodge: lodge,
      full_name: "Sergio Eduardo Salinas Díaz",
      current_degree: OpenStruct.new(name: "Maestro"),
      registry_number: "64289179",
      initiation_date: Date.new(1996, 6, 13),
      symbolic_name: nil
    )
    @pdf = Certificates::ActiveMemberPdf.new(
      brother: brother,
      issue: OpenStruct.new,
      verification_url: "https://logia.amenti.cl/verificar/test",
      issued_on: Date.new(2026, 9, 4)
    )
  end

  test "compone el texto institucional aprobado con valores normalizados" do
    body = @pdf.send(:certificate_body)

    assert_includes body, "la Respetable Logia Simbólica Amenti Diez N°31"
    assert_includes body, "del Valle de Santiago"
    assert_includes body, "adscrita a la Gran Logia Mixta de Chile"
    assert_includes body, "miembro activo y regular de este Taller"
    assert_includes body, "ostentando actualmente el grado de Maestro"
    refute_includes body, "del Santiago"
    refute_includes body, "a la Chile"
  end

  test "presenta detalles y fecha de emisión en español" do
    details = @pdf.send(:member_details)
    issuance = @pdf.send(:issuance_paragraph)

    assert_includes details, "Número de registro logial: 64289179"
    assert_includes details, "Fecha de iniciación: 13 de junio de 1996"
    assert_equal(
      "Se extiende el presente certificado para los fines institucionales que correspondan, " \
      "en el Valle de Santiago, a 4 de septiembre de 2026.",
      issuance
    )
  end

  test "normaliza el subtítulo institucional" do
    assert_equal(
      "N°31 · Gran Logia Mixta de Chile · Valle de Santiago",
      @pdf.send(:lodge_subtitle)
    )
  end
end
