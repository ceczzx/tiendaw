# CODEX

## Proyecto

- Nombre: `tiendaw` / `Sistema W`
- Stack principal: Flutter + Riverpod + Supabase
- Enfoque: operacion de tienda, compras, inventario por lote, promociones por lote, ventas y dashboards admin/vendedor

## Arquitectura

- `lib/app`: bootstrap de la app y providers globales.
- `lib/core`: utilidades transversales, sync, tema y compatibilidad Supabase/PostgREST.
- `lib/features/*/domain`: entidades y contratos.
- `lib/features/*/data`: repositorios y data sources.
- `lib/features/*/presentation`: pantallas y view models con Riverpod.
- `lib/shared/widgets`: widgets reutilizables.

## Modulos clave

- `features/catalog`: catalogo, pricing, promociones por lote, movimientos y stock.
- `features/purchases`: registro de compras, proveedores y dashboard operativo admin mobile.
- `features/sales`: dashboard de vendedor, caja y ventas.
- `features/dashboard`: dashboard admin desktop.
- `features/inventory/domain`: entidades de movimientos y lotes para UI.

## Supabase actual

Migraciones relevantes del repo:

- `supabase/migrations/20260520_tables_in_supabase.sql`
- `supabase/migrations/20260522_registrar_compra.sql`
- `supabase/migrations/20260523_new_changes_in_supbase.sql`

Tablas importantes para este flujo:

- `inventory_stock`: stock por `product_id + location_id + batch_id + storage_condition`
- `inventory_movements`: bitacora de compras, ventas, traslados y perdidas
- `lot_promotions`: promo por lote con estados `pending_transfer`, `active_store`, `exhausted`, `cancelled`
- `sale_item_lot_allocations`: asignacion por lote al vender
- `losses`: nueva tabla para perdidas especificas por lote

## Reglas de negocio visibles en codigo

- El stock se separa por ubicacion: `warehouse` y `store`.
- El stock se separa por lote usando `purchase_items.id` como `batch_id`.
- Las promociones son por lote, no por producto agregado.
- Un lote puede quedar en promo pero seguir `pending_transfer` hasta que exista stock de ese lote en tienda.
- El vendedor trabaja con el stock de tienda; la UI debe dejar claro promo vs stock regular.

## Archivos mas sensibles

- `lib/features/catalog/data/catalog_sources.dart`
  - lectura/escritura remota de catalogo, lotes, promociones, movimientos, perdidas y traslados.
- `lib/features/purchases/presentation/admin_mobile_dashboard_view_model.dart`
  - acumula compras, movimientos y acciones operativas del admin mobile.
- `lib/features/purchases/presentation/admin_mobile_dashboard_page.dart`
  - UI operativa para promos, perdidas y traslados.
- `lib/features/sales/presentation/seller_dashboard_page.dart`
  - UI del vendedor y lectura de stock promo/normal.
- `lib/features/sales/data/sales_sources.dart`
  - persistencia remota de ventas y caja.

## Convenciones utiles

- El repo usa entidades puras en `domain`, coordinacion en `data` y Riverpod en `presentation`.
- La cache local actual es en memoria; la documentacion habla de SQLite como siguiente fase, pero aun no esta implementado completo.
- Cuando se edite codigo manualmente, se esta usando `apply_patch`.
- Para buscar texto rapido en el repo, `rg` funciona bien.

## Ajustes aplicados en esta sesion

- `inventory_movements` ahora considera `batch_id` desde Flutter.
- Registro de perdidas alineado con la nueva tabla `losses`.
- Traslados de almacen a tienda respetan el lote seleccionado y no mezclan promo con stock normal.
- El estado de `lot_promotions` se sincroniza despues de mover o perder stock para reflejar `active_store` o `pending_transfer`.
- La UI admin y vendedor ahora deja mas claro que stock esta en promo y cual es regular.
