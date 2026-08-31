;;; project.el — ajustes al abrir este repositorio en Emacs
;;; Se carga desde ~/.emacs.d/init.el cuando el archivo está en el árbol del proyecto.

(defvar mlm/project-root
  (locate-dominating-file (or buffer-file-name default-directory) ".git")
  "Raíz del repositorio masonic-lodge-manager.")

(when mlm/project-root
  (setq mlm/project-root (expand-file-name mlm/project-root))

  ;; Projectile reconoce el proyecto
  (when (fboundp 'projectile-add-known-project)
    (projectile-add-known-project mlm/project-root))

  ;; Docker Compose de desarrollo
  (setq mlm/docker-compose-file
        (expand-file-name "docker-compose.yml" mlm/project-root))

  ;; Eglot: LSP vía contenedor web (ruby-lsp en bundle)
  (when (fboundp 'eglot-ensure)
    (setq eglot-server-programs
          `((ruby-mode . ,(mlm/eglot-server-program 'ruby-mode))
            (ruby-ts-mode . ,(mlm/eglot-server-program 'ruby-ts-mode))
            (web-mode . ,(mlm/eglot-server-program 'web-mode)))))

  (message "emacs/project.el: %s" mlm/project-root))
