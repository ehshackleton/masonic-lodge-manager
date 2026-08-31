;;; masonic-lodge-manager.el --- ajustes Doom para este repo -*- lexical-binding: t; -*-
;;;
;;; Cargar desde ~/.doom.d/config.el con:
;;;   (load! "~/Proyectos/masonic-lodge-manager/emacs/doom.el")
;;; o copiar el contenido si prefieres no depender de la ruta.

(when (and (boundp 'doom-project-root)
           (string-match-p "masonic-lodge-manager" (or (doom-project-root) "")))
  (message "Doom: masonic-lodge-manager"))

;; Eglot + ruby-lsp dentro del contenedor Docker Compose
(after! eglot
  (defun mlm/ruby-lsp-via-docker ()
    (let ((root (locate-dominating-file default-directory "docker-compose.yml")))
      (when root
        (list "docker" "compose"
              "-f" (expand-file-name "docker-compose.yml" root)
              "exec" "-T" "web"
              "bundle" "exec" "ruby-lsp"))))

  (setq-default eglot-workspace-configuration
                '((:ruby . ((:useBundler . t)))))

  (add-to-list 'eglot-server-programs
               `((ruby-mode ruby-ts-mode)
                 . ,(lambda (&rest _)
                      (or (mlm/ruby-lsp-via-docker)
                          '("ruby-lsp"))))))

(provide 'masonic-lodge-manager)
