# Emacs en Masonic Lodge Manager

Configuración para editar este proyecto Rails con Emacs 30+.

## Archivos del repo

| Archivo | Uso |
|---------|-----|
| `.editorconfig` | Indentación 2 espacios (Ruby, ERB, YAML) |
| `.dir-locals.el` | Ajustes al abrir archivos del proyecto |
| `emacs/project.el` | Projectile, Eglot vía Docker, rutas del repo |

## Configuración global

Se creó `~/.emacs.d/init.el` con:

- **MELPA** (magit, projectile, eglot, web-mode, flycheck, editorconfig)
- **Projectile** (`C-c p f` buscar archivo, `C-c p p` cambiar proyecto)
- **Magit** (`C-c g` estado git)
- **Eglot** + **ruby-lsp** (dentro del contenedor `web` de Docker)
- **web-mode** para `.erb`

La primera vez que abras Emacs, puede tardar instalando paquetes.

## Uso diario

1. **Levantar el stack** (necesario para LSP vía Docker):

   ```bash
   cd /home/shackleton/Proyectos/masonic-lodge-manager
   docker compose up -d
   ```

2. **Abrir Emacs** en el proyecto:

   ```bash
   emacs /home/shackleton/Proyectos/masonic-lodge-manager
   ```

3. Abre un `.rb` o `.erb` — Eglot debería conectar con `ruby-lsp` en el contenedor.

4. **Consola Rails** (terminal):

   ```bash
   docker compose exec web bash -lc './bin/rails console'
   ```

5. **Tests**:

   ```bash
   docker compose exec web bash -lc './bin/rails test'
   ```

## Desarrollo local (sin Emacs)

Ver `README.md`. Resumen:

```bash
cp .env.example .env   # si no existe
# Editar .env: RAILS_MASTER_KEY desde config/master.key
docker compose up --build
# http://localhost:3000
```

Credenciales admin por defecto (seed): ver `ADMIN_TEMP_PASSWORD` en `.env`.

## Solución de problemas

- **Eglot no conecta**: confirma `docker compose ps` y que el servicio `web` está `Up`.
- **Paquetes Emacs**: `M-x package-refresh-contents` y `M-x package-install RET magit RET`.
- **RuboCop en flycheck**: ejecuta tests/linter en el contenedor: `docker compose exec web bundle exec rubocop`.
