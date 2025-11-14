# Lab Personal

Aplicacion Flutter para gestionar dispositivos IoT del laboratorio personal. La base parte de Cultivemos, pero aqui apunta a experimentos, Thing Groups de AWS IoT y un proyecto independiente en Supabase.

## Entornos y variables

- `.env` configura el entorno principal del laboratorio (tablas `lab_devices`, `lab_user_settings`, `lab_setpoints`).
- `.env_personal` actua como plantilla alternativa para credenciales o datos simulados.
- `.env.example` contiene placeholders seguros para compartir el repo.

Puedes alternar entre entornos exportando variables o usando `--dart-define`. Ejemplo para Supabase:

```bash
flutter run \
  --dart-define=SUPABASE_URL=https://your-lab-project.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=public-anon-key \
  --dart-define=SUPABASE_TABLE_DEVICES=lab_devices \
  --dart-define=SUPABASE_TABLE_USER_SETTINGS=lab_user_settings \
  --dart-define=SUPABASE_TABLE_SETPOINTS=lab_setpoints
```

Agrega tambien variables para AWS IoT (`AWS_IOT_ENDPOINT`, `AWS_THING_GROUP`, certificados, etc.) cuando las necesites.

## Configuracion rapida

```bash
flutter pub get
flutter run
```

Los tests inicializan Supabase en memoria; puedes pasar claves especificas con `--dart-define=SUPABASE_TEST_URL=...` y `--dart-define=SUPABASE_TEST_ANON_KEY=...`.

## Modulos principales

- `features/home`: dashboard del laboratorio con KPIs rapidos.
- `features/modify`: pantallas para editar setpoints (pH, TDS, etc.).
- `features/devices`: emparejamiento BLE y sincronizacion con Thing Groups.

La estructura modular permite conectar sensores reales sin modificar la navegacion principal.
