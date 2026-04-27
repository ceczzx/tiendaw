# Sistema W

Aplicacion Flutter para ventas e inventario conectada a Supabase, manteniendo la separacion por capas que ya traia el proyecto:

- `presentation`
- `domain`
- `data`
- `Riverpod`

## Cambios realizados en orden

1. Se elimino el flujo demo en memoria.
   Ya no existe `shared/demo/system_w_store.dart` ni los datos estaticos de categorias, productos, ventas o compras de ejemplo.

2. Se agrego configuracion segura por entorno.
   Se creo `.env` para `SUPABASE_URL` y `SUPABASE_ANON_KEY`.
   Se agrego `.env.example` como referencia.
   Se actualizo `.gitignore` para ocultar `.env`.

3. Se inicializo Supabase desde Flutter.
   `lib/main.dart` ahora carga el `.env`, valida placeholders e inicializa `Supabase.initialize(...)`.
   Si faltan credenciales, la app muestra una pantalla de configuracion en lugar de romperse.

4. Se implemento autenticacion real.
   Se agrego la capa `auth` con:
   - `AuthRepository`
   - `AuthRemoteDataSource`
   - casos de uso para cargar usuario, iniciar sesion y cerrar sesion
   - pantalla `SignInPage`

5. Se conectaron los repositorios al proyecto real de Supabase.
   - Catalogo: `categories`, `products`, `inventory_stock`, `purchase_items`, `product_prices`, `inventory_movements`
   - Ventas: `sales`, `sale_items`, `cash_shifts`, `locations`
   - Compras: `purchases`, `purchase_items`, `suppliers`, `product_prices`

6. Se mantuvo la arquitectura actual.
   Los `repositories` siguen orquestando `local` y `remote`.
   Los `local data sources` quedaron como cache liviano en memoria sin datos sembrados.
   Los `remote data sources` son los que ahora hablan con Supabase.

7. Se adaptaron las pantallas a datos reales y estados vacios.
   Si todavia no tienes categorias, productos, compras o movimientos en Supabase, la UI ahora muestra estados vacios claros en vez de depender de mocks.

8. Se corrigio el overflow movil.
   El `RenderFlex overflowed` venia del header superior y de algunas filas estrechas en celular.
   Se rehizo el `shell` con `Wrap` responsivo y se compactaron varios bloques para pantallas angostas.

9. Se agrego una nueva migracion para que la app pueda operar con tu esquema.
   Archivo nuevo:
   - `supabase/migrations/20260427_supabase_app_policies.sql`

   Esta migracion:
   - habilita y completa politicas RLS faltantes
   - permite leer perfiles, ubicaciones, proveedores, precios y movimientos
   - permite ventas, items de venta, compras, items de compra y turnos
   - crea ubicaciones base si no existen:
     - `Almacen principal`
     - `Tienda principal`

## Archivos clave tocados

- `lib/main.dart`
- `lib/app/providers.dart`
- `lib/app/system_w_app.dart`
- `lib/features/auth/...`
- `lib/features/catalog/data/...`
- `lib/features/sales/data/...`
- `lib/features/purchases/data/...`
- `lib/features/home/presentation/system_w_shell.dart`
- `lib/features/sales/presentation/...`
- `lib/features/purchases/presentation/...`
- `lib/features/dashboard/presentation/...`
- `supabase/migrations/20260427_supabase_app_policies.sql`

## Variables de entorno

Usa este formato en `.env`:

```env
SUPABASE_URL=https://tu-proyecto.supabase.co
SUPABASE_ANON_KEY=tu_anon_key
```

## Migraciones a ejecutar

Ejecuta estas migraciones en este orden:

1. `supabase/migrations/20260426_system_w.sql`
2. `supabase/migrations/20260427_supabase_app_policies.sql`

Nota:
El archivo que existe en el proyecto es `20260426_system_w.sql`. Ese es el que tome como base para la integracion.

## Como probar

1. Completa `.env`
2. Ejecuta las migraciones
3. Crea al menos un usuario en Supabase Auth
4. Inicia la app con `flutter run`
5. Ingresa con ese usuario desde la pantalla de login

Si el usuario no tiene fila en `public.profiles`, la app intentara crearla automaticamente con rol `seller`.

## Verificacion local

- `flutter pub get`
- `flutter analyze`
- `flutter test`

## Estado actual

La app ya usa Supabase de verdad para login, catalogo, ventas, compras y movimientos.
La siguiente fase natural seria conectar el almacenamiento local SQLite para recuperar el modo offline real, pero ya no depende de datos de ejemplo para funcionar.
