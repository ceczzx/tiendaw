# Sistema W - Arquitectura

## 1. Objetivo

`Sistema W` esta planteado como una base de produccion para ventas rapidas, control de inventario, compras, operacion offline y analitica administrativa.

## 2. Estructura de carpetas

```text
lib/
  app/
    providers.dart
    system_w_app.dart
  core/
    constants/
    sync/
    theme/
    utils/
  features/
    auth/
      domain/
      presentation/
    catalog/
      data/
      domain/
    dashboard/
      presentation/
    home/
      presentation/
    inventory/
      domain/
    purchases/
      data/
      domain/
      presentation/
    sales/
      data/
      domain/
      presentation/
  shared/
    demo/
    widgets/
```

## 3. Capas

### Presentation

- `Views`: dashboards y shell responsive.
- `ViewModels`: `AsyncNotifier` y `Notifier` con Riverpod.
- `MVVM`: el estado de pantalla queda encapsulado y la UI solo renderiza.

Archivos ejemplo:

- `lib/features/sales/presentation/seller_dashboard_page.dart`
- `lib/features/sales/presentation/seller_dashboard_view_model.dart`
- `lib/features/dashboard/presentation/admin_desktop_dashboard_page.dart`

### Domain

- Entidades puras y reglas de negocio.
- Casos de uso orquestan operaciones sin depender de Flutter.
- Interfaces de repositorio definen contratos estables.

Archivos ejemplo:

- `lib/features/catalog/domain/catalog_entities.dart`
- `lib/features/sales/domain/create_sale_use_case.dart`
- `lib/features/sales/domain/sales_repository.dart`

### Data

- Repositorios coordinan `local` + `remote`.
- Data sources separan lectura/escritura por origen.
- Se deja lista la sustitucion del store demo por `Supabase` y `SQLite`.

Archivos ejemplo:

- `lib/features/catalog/data/catalog_repository_impl.dart`
- `lib/features/sales/data/sales_sources.dart`
- `lib/features/purchases/data/purchase_repository_impl.dart`

## 4. Modulos principales

### Ventas

- Seleccion `categoria -> producto`.
- Muestra stock tienda y almacen.
- Venta en 4 pasos maximo.
- Cierre de caja por turno.

### Compras

- Alta de compras con proveedor, cantidad, costo y vencimiento.
- Historial de costos por producto.
- Alimenta alertas y stock de almacen.

### Inventario

- Stock separado para `almacen` y `tienda`.
- Transferencias rapidas de almacen a tienda.
- Movimientos trazables.

### Dashboard admin laptop

- KPIs.
- Alertas.
- Tablas tipo Excel.
- Filtros por vendedor y ventana de tiempo.

## 5. Deteccion de dashboard

La seleccion actual se hace en `lib/features/home/presentation/system_w_shell.dart`.

Reglas:

- `Laptop + admin` -> dashboard administrativo.
- `Laptop + vendedor` -> mensaje de restriccion.
- `Celular + vendedor` -> dashboard de ventas.
- `Celular + admin` -> dashboard operativo.

## 6. Ejemplos solicitados

### Entity

- `Product` en `lib/features/catalog/domain/catalog_entities.dart`

### UseCase

- `CreateSaleUseCase` en `lib/features/sales/domain/create_sale_use_case.dart`

### Repository

- `CatalogRepository` en `lib/features/catalog/domain/catalog_repository.dart`
- `CatalogRepositoryImpl` en `lib/features/catalog/data/catalog_repository_impl.dart`

### ViewModel con Riverpod

- `SellerDashboardViewModel` en `lib/features/sales/presentation/seller_dashboard_view_model.dart`
- `SessionViewModel` en `lib/features/auth/presentation/session_view_model.dart`

## 7. Modelo de datos

### Supabase

Revisar:

- `supabase/migrations/20260426_system_w.sql`

Incluye:

- `profiles`
- `categories`
- `suppliers`
- `products`
- `product_prices`
- `locations`
- `inventory_stock`
- `purchases`
- `purchase_items`
- `cash_shifts`
- `sales`
- `sale_items`
- `inventory_movements`

### SQLite local

Revisar:

- `docs/local_sqlite_schema.sql`

Separacion planteada:

- Permanentes: catalogo, categorias, precios, snapshots de stock
- Temporales: ventas, compras y cola de sincronizacion

Campos de sincronizacion obligatorios:

- `id`
- `sync_status`
- `timestamp`
- `sync_attempts`

## 8. Rendimiento y produccion

- Estado liviano con Riverpod.
- UI con scrolls simples y composicion sobria.
- Batch sync por lotes paralelos sin conflicto de producto.
- Limpieza de transacciones sincronizadas mayores a 7 dias.
- Sincronizacion offline-first para proteger ventas y compras.

## 9. Siguiente paso recomendado

Reemplazar `SystemWStore` por:

1. `SupabaseClient` real para `remote`.
2. repositorio SQLite real para `local`.
3. `connectivity_plus` para detectar red.
4. login real con `Supabase Auth`.
