# Contexto Acumulado

## Estado del proyecto al revisar

- La arquitectura esta bien separada por capas y por features.
- La documentacion `docs/system_w_architecture.md` todavia menciona una migracion antigua (`20260426_system_w.sql`) que ya no existe en el repo.
- El esquema real vive en las migraciones `20260520`, `20260522` y `20260523`.

## Hallazgos tecnicos importantes

- `CatalogRemoteDataSource.transferWarehouseToStore(...)` recibia `purchaseItemId`, pero no lo usaba para filtrar el lote exacto.
- Eso permitia mezclar lotes del mismo producto al mover stock, incluyendo lotes en promo y lotes normales.
- `CatalogRemoteDataSource.getWarehouseSupplierLots(...)` no estaba enriqueciendo los lotes con la promo activa del lote, aunque la UI ya esperaba esos datos.
- El admin mobile ya construia notas de movimiento con informacion del lote y promo, pero el insert remoto de transferencias no guardaba `notes`.
- `registerInventoryLoss(...)` solo escribia `inventory_movements`; con la nueva migracion tambien debe poblar `losses`.

## Cambios de Supabase que afectan el codigo

- `inventory_movements.batch_id` se agrego para relacionar el movimiento con el lote exacto.
- Existe una nueva tabla `losses` que exige:
  - `product_id`
  - `batch_id`
  - `location_id`
  - `quantity`
  - `reason`
  - `financial_impact`
  - `storage_condition`
  - `reported_by`
- La funcion SQL `registrar_compra` del repo necesitaba incluir `batch_id` al registrar movimientos de compra.

## Criterios de negocio preservados

- Se mantiene la arquitectura actual: dominio limpio, data source remoto, repositorios y Riverpod.
- No se cambio el flujo alto nivel de ventas ni compras.
- La separacion promo/normal se corrige desde el lote y se refleja en UI, sin convertir el sistema a otro modelo distinto.

## Riesgos o siguientes pasos recomendables

- Si Supabase productivo ya tiene desplegada una version vieja de `registrar_compra`, conviene volver a publicar la funcion con el SQL actualizado.
- La documentacion de arquitectura del repo deberia alinearse luego con las migraciones reales y con la fase actual del offline cache.
- Si se quiere trazabilidad aun mas fina, despues se puede mostrar `batch_id` o un alias de lote en dashboard desktop de movimientos.
