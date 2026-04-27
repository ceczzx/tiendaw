# Sistema W

Base Flutter para un sistema de ventas e inventario con enfoque en:

- `Clean Architecture + MVVM`
- `Riverpod`
- `Supabase`
- `SQLite offline`
- dashboards diferenciados por rol y dispositivo

## Documentacion clave

- [Arquitectura](./docs/system_w_architecture.md)
- [Flujo de sincronizacion](./docs/sync_flow.md)
- [Esquema SQLite local](./docs/local_sqlite_schema.sql)
- [Migracion Supabase](./supabase/migrations/20260426_system_w.sql)

## Nota de implementacion

La app queda ejecutable con un `store` demo en memoria para poder validar flujo, UI y capas sin depender de credenciales. Los contratos, repositorios y esquemas ya estan preparados para sustituir el `store` por adaptadores reales de `Supabase` y `SQLite`.
