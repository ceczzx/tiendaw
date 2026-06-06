# Contexto del Frontend - Sistema W (tiendaw)

## 1) Resumen rapido

- App Flutter multiplataforma para ventas, compras e inventario con Supabase.
- UI separada por rol (admin vs vendedor) y por ancho de pantalla.
- Arquitectura por capas: presentation, domain y data, con Riverpod para estado.

## 2) Stack y dependencias clave

- Flutter + Dart (SDK ^3.7.2).
- Riverpod para estado y ViewModels.
- Supabase (auth + datos) con `supabase_flutter`.
- `.env` con `flutter_dotenv` para credenciales.
- `intl` para formatos, `google_fonts` para tipografia.
- `geolocator` para ubicaciones de turnos.
- `sqlite3` + `sqlite3_flutter_libs` (cache local planificada).

## 3) Estructura general

- `lib/app`: bootstrap y providers globales.
- `lib/core`: theme, utils, constants, sync.
- `lib/features`: modulos por dominio.
- `lib/shared/widgets`: componentes reutilizables.
- `android`, `ios`, `web`, `windows`, `macos`, `linux`: targets de plataforma.

## 4) Arquitectura y flujo principal

- `main.dart` carga `.env`, valida claves y llama `Supabase.initialize`.
- `SystemWApp` crea `MaterialApp` con tema y localizaciones.
- `_SessionGate` decide la vista inicial:
  - `SignInPage` si no hay sesion.
  - `OfflineSessionPage` si hay sesion pero sin internet.
  - `SystemWShell` si hay sesion activa.
  - `SetupRequiredPage` si faltan credenciales.
- `SystemWShell` usa breakpoints + rol para elegir dashboard.

## 5) Modulos (features) y responsabilidades

- **auth**
  - Domain: `AppUser`, casos de uso `LoadCurrentUser`, `SignIn`, `SignOut`.
  - Data: `AuthRepositoryImpl`, `AuthRemoteDataSource`, source de invite (deshabilitado).
  - Presentation: `SignInPage`, `OfflineSessionPage`, `SessionViewModel`.
- **catalog**
  - Domain: entidades de catalogo, reglas de pricing.
  - Data: `CatalogRepositoryImpl`, `CatalogRemoteDataSource`.
  - No tiene UI propia; lo consumen dashboards.
- **dashboard**
  - Presentation: `AdminDesktopDashboardPage` y view model.
- **home**
  - Presentation: `SystemWShell` y orquestacion de vistas.
- **inventory**
  - Domain: entidades de stock y movimientos.
- **purchases**
  - Domain + Data + Presentation para compras y operaciones admin mobile.
  - UI operativa: compras, proveedores, promociones, packs, perdidas y movimientos.
- **sales**
  - Domain + Data + Presentation para ventas.
  - UI vendedor: caja, busqueda, categorias, productos, packs y promos.

## 6) Dashboards y vistas

Dashboards (3):

- **Admin Desktop**: secciones ventas, compras, productos, movimientos y operaciones.
- **Admin Mobile**: secciones home, compras, proveedores, promociones, packs, perdidas y movimientos.
- **Seller**: venta rapida con caja/turnos, buscador, categorias y productos.

Otras vistas:

- `SignInPage` (login por DNI -> email `dni@tiendaw.com`).
- `OfflineSessionPage` (sesion detectada sin internet).
- `SetupRequiredPage` (falta `.env`).
- `SystemWShell` (layout y routing interno por rol/ancho).

## 7) Vinculacion y navegacion

- No hay rutas separadas: se renderiza la vista segun sesion, rol y ancho.
- Admin desktop usa botones de AppBar para cambiar secciones.
- Admin mobile usa un strip inferior para cambiar secciones.
- Seller usa scroll con secciones y acciones de caja/ventas.

## 8) Datos y reglas de negocio clave

- Stock separado por ubicacion (`almacen` / `tienda`) y por lote (`batch_id`).
- Promociones por lote; un lote puede estar `pending_transfer` hasta estar en tienda.
- Caja/turnos para ventas con aprobaciones y rechazos.
- Compras generan lotes y movimientos; perdidas se registran en `losses`.
- Tablas clave: `products`, `categories`, `inventory_stock`, `inventory_movements`,
  `purchases`, `purchase_items`, `sales`, `sale_items`, `cash_shifts`,
  `locations`, `lot_promotions`, `sale_item_lot_allocations`, `losses`.

## 9) Estado, repositorios y casos de uso

- Providers globales en `lib/app/providers.dart`.
- Use cases expuestos:
  - `LoadCurrentUser`, `SignIn`, `SignOut`.
  - `LoadCatalogOverview`.
  - `CreateSale`.
  - `RegisterPurchase`.
- Data sources locales son in-memory; remotos usan Supabase.

## 10) Tema, UI y utilidades

- Tema central en `core/theme/system_w_theme.dart`.
- Formateadores y helpers en `core/utils/formatters.dart`.
- Widgets reutilizables en `shared/widgets/system_w_widgets.dart`.
- Breakpoints en `core/constants/app_breakpoints.dart`.

## 11) Configuracion y assets

- `.env` con:
  - `SUPABASE_URL`
  - `SUPABASE_PUBLISHABLE_KEY` o `SUPABASE_ANON_KEY`
- `.env` esta declarado como asset en `pubspec.yaml`.

## 12) Pruebas y calidad

- Prueba base en `test/widget_test.dart`.
- Reglas de lint en `analysis_options.yaml`.
