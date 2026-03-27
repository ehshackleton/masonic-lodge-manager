# Sistema de Gestion Logial

Base inicial del proyecto Rails + PostgreSQL para administracion integral de una logia masonica.

## Requisitos
- Docker y Docker Compose

## Inicio rapido
1. Copiar variables de entorno:
   - `cp .env.example .env`
2. Levantar servicios:
   - `docker compose up --build`
3. Abrir aplicacion en:
   - `http://localhost:3000`

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
