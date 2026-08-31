# Sistema de Gestion Logial

Base inicial del proyecto Rails + PostgreSQL para administracion integral de una logia masonica.

## Requisitos
- Docker y Docker Compose

## Inicio rapido
1. Copiar variables de entorno:
   - `cp .env.example .env`
   - En `.env`, `RAILS_MASTER_KEY` debe coincidir con `config/master.key` (no dejar `replace_me`).
   - Generar `SECRET_KEY_BASE`: `docker compose run --rm --no-deps web bundle exec rails secret`
2. Levantar servicios:
   - `docker compose up --build`
3. Abrir aplicacion en:
   - `http://localhost:3000`

Credenciales tras el seed (ver `ADMIN_TEMP_PASSWORD` en `.env`):
- Admin: `admin@logia.local`

## Emacs
Guia en [`emacs/README.md`](emacs/README.md). Incluye `~/.emacs.d/init.el`, Eglot con `ruby-lsp` en Docker y atajos del proyecto.

## Rutas base
- `/`
- `/sobre-nosotros`
- `/contacto`
- `/sobre-el-sistema`
- `/iniciar-sesion`
- `/backoffice`

## Estructura inicial entregada
- Proyecto Rails base
- Namespaces `Public` y `Backoffice`
- Modelo de datos inicial (migracion core)
- `Dockerfile` y `docker-compose.yml`
- Backlog tecnico de Sprint 1 en `docs/sprint-1-backlog.md`
