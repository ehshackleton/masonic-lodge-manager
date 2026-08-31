# Emacs (Doom) — Masonic Lodge Manager

Este proyecto se trabaja con **Doom Emacs** (`~/.emacs.d` + `~/.doom.d`).

## Archivos del repo

| Archivo | Uso |
|---------|-----|
| `.editorconfig` | Indentación 2 espacios (Ruby, ERB, YAML) |
| `.dir-locals.el` | Ajustes locales al abrir archivos del proyecto |
| `emacs/doom.el` | Eglot + `ruby-lsp` vía Docker Compose |
| `emacs/project.el` | Helpers legacy (opcional) |

## Credenciales GitHub (ya en Doom)

El PAT vive en:

```text
~/.doom.d/token/read-github-token/key.txt
```

`~/.doom.d/github.el` lo expone a Forge/Magit vía `auth-source` (usuario `ehshackleton`).

Para `git push` en terminal, el credential store usa ese mismo token (`~/.git-credentials`).

## Uso diario

1. Stack local:

   ```bash
   cd ~/Proyectos/masonic-lodge-manager
   docker compose up -d
   ```

2. Abrir Doom en el proyecto:

   ```bash
   emacs ~/Proyectos/masonic-lodge-manager
   ```

3. Magit / Forge: `SPC g g` (status), `SPC g i` (issues), `SPC g p` (PRs).

4. Consola / tests:

   ```bash
   docker compose exec web bash -lc './bin/rails console'
   docker compose exec web bash -lc './bin/rails test'
   ```

## Rama de desarrollo

- `amenti-diez-31` — desarrollo del sistema y sitio para la R∴L∴ Amenti Diez Nº 31  
- `main` — estable / despliegue

## Nota

No uses un `~/.emacs.d/init.el` vanilla encima de Doom: Doom arranca con `early-init.el` y la config de usuario está en `~/.doom.d/`.
