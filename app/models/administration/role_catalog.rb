# frozen_string_literal: true

module Administration
  module RoleCatalog
    ROLE_MATRIX = {
      "Cuadro logial" => %w[registry_manager registry_editor registry_viewer],
      "Secretaria" => %w[secretario secretariat_manager minute_editor minute_approver correspondence_editor correspondence_approver],
      "Tesoreria" => %w[tesoreria_manager tesoreria_operator tesoreria_closer tesoreria_exporter],
      "Trabajos" => %w[work_reviewer work_approver work_presenter work_archiver],
      "Hospitalario" => %w[hospitalario_manager hospitalario_operator hospitalario_exporter]
    }.freeze

    ROLE_TEMPLATES = {
      "secretario" => {
        name: "Plantilla Secretario",
        role_keys: %w[
          secretario secretariat_manager minute_editor minute_approver correspondence_editor correspondence_approver
          registry_manager registry_editor
          work_reviewer work_approver work_presenter work_archiver
        ]
      },
      "cuadro" => {
        name: "Plantilla Cuadro logial",
        role_keys: %w[registry_manager registry_editor]
      },
      "tesorero" => {
        name: "Plantilla Tesorero",
        role_keys: %w[tesoreria_manager tesoreria_operator tesoreria_closer tesoreria_exporter]
      },
      "revisor" => {
        name: "Plantilla Revisor",
        role_keys: %w[work_reviewer]
      },
      "hospitalario" => {
        name: "Plantilla Hospitalario",
        role_keys: %w[hospitalario_manager hospitalario_operator hospitalario_exporter]
      }
    }.freeze

    SUPERADMIN_ROLE_KEY = "superadmin"
    MANAGEABLE_ROLE_KEYS = ROLE_MATRIX.values.flatten.freeze

    module_function

    def manageable_roles
      Role.where(key: MANAGEABLE_ROLE_KEYS).order(:name)
    end

    def role_matrix_grouped
      roles_by_key = manageable_roles.index_by(&:key)
      ROLE_MATRIX.transform_values do |keys|
        keys.filter_map { |key| roles_by_key[key] }
      end
    end

    def assignable_role_ids(selected_ids:, superadmin: false)
      allowed_ids = Role.where(key: MANAGEABLE_ROLE_KEYS).pluck(:id)
      if superadmin
        allowed_ids += Role.where(key: SUPERADMIN_ROLE_KEY).pluck(:id)
      end
      Array(selected_ids).map(&:to_i) & allowed_ids
    end

    def apply_template!(user:, template_key:)
      template = ROLE_TEMPLATES[template_key.to_s]
      return false unless template

      allowed_ids = Role.where(key: MANAGEABLE_ROLE_KEYS).pluck(:id)
      template_role_ids = Role.where(key: template[:role_keys]).pluck(:id)

      user.user_roles.where(role_id: allowed_ids).delete_all
      template_role_ids.each do |role_id|
        UserRole.find_or_create_by!(user_id: user.id, role_id: role_id)
      end
      true
    end

    def sync_roles!(user:, role_ids:, superadmin: false, preserve_superadmin: false)
      allowed_ids = Role.where(key: MANAGEABLE_ROLE_KEYS).pluck(:id)
      superadmin_role = Role.find_by(key: SUPERADMIN_ROLE_KEY)
      final_role_ids = assignable_role_ids(selected_ids: role_ids, superadmin: false)

      user.user_roles.where(role_id: allowed_ids).delete_all
      final_role_ids.each do |role_id|
        UserRole.find_or_create_by!(user_id: user.id, role_id: role_id)
      end

      return unless superadmin_role

      if superadmin
        UserRole.find_or_create_by!(user_id: user.id, role_id: superadmin_role.id)
      elsif !preserve_superadmin
        user.user_roles.where(role_id: superadmin_role.id).delete_all
      end
    end
  end
end
