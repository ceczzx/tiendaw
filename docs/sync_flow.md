# Flujo de sincronizacion offline

## Reglas

- Si no hay internet, ventas y compras se guardan localmente con `pending`.
- Al recuperar conexion, se ejecuta la cola.
- Operaciones del mismo producto se sincronizan en secuencia.
- Operaciones de productos diferentes pueden viajar en paralelo.
- Si el envio falla, se incrementa `sync_attempts`.
- Si supera el limite operativo definido por negocio, se debe alertar en UI y log.

## Motor actual

Referencia:

- `lib/core/sync/sync_engine.dart`

## Pseudocodigo

```text
onConnectivityRestored():
  pending = loadPendingSales() + loadPendingPurchases()
  tasks = map pending -> SyncTask(productIds, execute)

  while tasks not empty:
    batch = []
    lockedProducts = set()

    for task in tasks:
      if task.productIds intersects lockedProducts:
        continue
      batch.add(task)
      lockedProducts.addAll(task.productIds)

    run batch in parallel
    remove batch from tasks

  cleanupSyncedOlderThan(7 days)
```

## Diagrama

```mermaid
flowchart TD
    A["Operacion offline"] --> B["Guardar en SQLite local"]
    B --> C["sync_status = pending"]
    C --> D["Conexion restaurada"]
    D --> E["Construir cola de SyncTask"]
    E --> F{"Comparte producto con otra tarea?"}
    F -- "Si" --> G["Ejecutar secuencial"]
    F -- "No" --> H["Ejecutar en paralelo"]
    G --> I["Actualizar sync_attempts"]
    H --> I
    I --> J{"Sync correcto?"}
    J -- "Si" --> K["Marcar synced"]
    J -- "No" --> L["Marcar failed / reintentar"]
    K --> M["Limpiar registros > 7 dias"]
```
