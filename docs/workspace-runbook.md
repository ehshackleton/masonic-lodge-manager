# Runbook: Google Workspace (buzón institucional)

Cuenta objetivo: `amentidiez31@granlogiamixta.cl`  
Modelo: OAuth de **usuario** (sin Domain-Wide Delegation ni admin del dominio).

## Configuración inicial

1. En Google Cloud Console, crear un OAuth client tipo **Web application**.
2. Authorized redirect URIs:
   - Local: `http://localhost:3000/backoffice/workspace/callback`
   - Prod: `https://logia.amenti.cl/backoffice/workspace/callback`
3. Variables de entorno (ver `.env.example`):
   - `GOOGLE_CLIENT_ID`
   - `GOOGLE_CLIENT_SECRET`
   - `GOOGLE_OAUTH_REDIRECT_URI` (recomendado explícito)
   - `GOOGLE_GMAIL_QUERY` (opcional)
   - `GOOGLE_DRIVE_FOLDER_ID` (opcional; carpeta compartida/creada por la app)
4. Scopes usados: `gmail.readonly`, `calendar.events`, `drive.file`, `openid`, `email`, `profile`.
5. Si la app está en modo Testing, añadir la cuenta institucional como test user.
6. En Secretaría → **Google Workspace** → **Conectar Google Workspace** e iniciar sesión con la cuenta institucional.

## Operación diaria

| Acción | Dónde |
|--------|--------|
| Importar correos → Correspondencia (draft) | Workspace UI / Importar Gmail |
| Abrir mensaje en Gmail | Detalle de correspondencia |
| Publicar Tenida en Calendar | Detalle Tenida / botón o sync automático al guardar |
| Archivar acta PDF en Drive | Al publicar acta o botón «Archivar en Drive» |

Rails guarda **metadatos + IDs + URLs**, no el cuerpo completo del buzón ni la biblioteca Drive.

## Reauth / refresh token inválido

Síntomas: health check falla; `workspace_connections.status = error`; jobs marcan `last_error`.

1. Secretaría → Google Workspace → **Desconectar**.
2. En [Google Account → Security → Third-party access](https://myaccount.google.com/permissions), revocar la app si aparece.
3. **Conectar** de nuevo (prompt consent) para emitir un refresh token nuevo.
4. Ejecutar **Comprobar conexión**.

## Rotar client secret

1. Crear nuevo secret en GCP OAuth client.
2. Actualizar `GOOGLE_CLIENT_SECRET` en el entorno (Compose/Kamal/host).
3. Reiniciar `web` (y worker si corre).
4. Reconectar OAuth desde la UI (tokens antiguos pueden quedar inválidos).

## Revocar OAuth / offboarding Secretario

1. Desconectar desde la UI (limpia tokens cifrados en BD).
2. Revocar acceso de la app en la cuenta Google institucional.
3. Rotar roles Rails del usuario saliente (`secretario` / `secretariat_manager`).
4. Auditar `AuditLog` acciones `workspace.*`.

## Jobs e idempotencia

- `WorkspaceImportGmailJob` — dedupe por `gmail_message_id` en `workspace_links`.
- `WorkspaceSyncTenidaCalendarJob` — upsert por link Calendar existente; cancelación borra evento.
- `WorkspaceArchiveMinuteJob` — omite si ya hay `drive_file` (usar force desde UI para re-subir).
- Reintentos: 3 intentos con backoff; errores persisten en `last_error` (sin tokens en logs).

## Seguridad

- Nunca versionar `.env` ni client secrets.
- Tokens en `workspace_connections` cifrados con `secret_key_base`.
- No loguear access/refresh tokens ni cuerpos de correo.
