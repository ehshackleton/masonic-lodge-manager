;;; Directory-local settings for Masonic Lodge Manager (Rails 8)

((erb-mode
 . ((indent-tabs-mode . nil)
    (tab-width . 2)))

 (ruby-mode
 . ((indent-tabs-mode . nil)
    (ruby-indent-level . 2)
    (ruby-insert-encoding-magic-comment . nil)))

 (ruby-ts-mode
 . ((indent-tabs-mode . nil)
    (ruby-indent-level . 2)))

 (yaml-mode
 . ((indent-tabs-mode . nil)
    (yaml-indent-offset . 2)))

 (nil
 . ((eval . (progn
              (when (fboundp 'projectile-mode)
                (projectile-mode 1))
              (when (and (fboundp 'eglot-ensure)
                         (or (derived-mode-p 'ruby-mode)
                             (derived-mode-p 'ruby-ts-mode)
                             (derived-mode-p 'erb-mode)))
                (eglot-ensure)))))))
