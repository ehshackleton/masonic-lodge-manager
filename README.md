# Amenti Diez N°31 — Gestion logial

Aplicacion Rails + PostgreSQL para la **Respetable Logia Simbolica Amenti Diez N°31**
(Gran Logia Mixta de Chile). Rama de desarrollo: `amenti-diez-31`.

Contexto rector: [`literate.org`](literate.org) · Arquitectura: [`arquitectura.org`](arquitectura.org) · Vision amplia: [`CONTEXT_MASTER_AMENTI_DIGITAL_2026.org`](CONTEXT_MASTER_AMENTI_DIGITAL_2026.org).

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
4. (Opcional) Reaplicar semillas de identidad Amenti:
   - `docker compose exec web bash -lc './bin/rails db:seed'`

Credenciales tras el seed (ver `ADMIN_TEMP_PASSWORD` en `.env`):
- Admin: `admin@logia.local`

## Emacs (Doom)
Guia en [`emacs/README.md`](emacs/README.md).

## Rutas base
- `/`
- `/sobre-nosotros`
- `/contacto`
- `/sobre-el-sistema`
- `/iniciar-sesion`
- `/backoffice`

## Produccion
- Host documentado: `logia.amenti.cl`
- Compose: `docker-compose.production.yml` (Traefik)
