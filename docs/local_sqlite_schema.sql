-- Datos permanentes
CREATE TABLE IF NOT EXISTS categories (
  id TEXT PRIMARY KEY,
  name TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS products (
  id TEXT PRIMARY KEY,
  category_id TEXT NOT NULL,
  name TEXT NOT NULL,
  sale_price REAL NOT NULL,
  last_purchase_cost REAL NOT NULL,
  low_stock_threshold INTEGER NOT NULL DEFAULT 20,
  next_expiry_date TEXT,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS product_prices (
  id TEXT PRIMARY KEY,
  product_id TEXT NOT NULL,
  supplier_name TEXT NOT NULL,
  unit_cost REAL NOT NULL,
  registered_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS stock_snapshots (
  id TEXT PRIMARY KEY,
  product_id TEXT NOT NULL,
  location_code TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  updated_at TEXT NOT NULL
);

-- Datos temporales
CREATE TABLE IF NOT EXISTS local_sales (
  id TEXT PRIMARY KEY,
  seller_id TEXT NOT NULL,
  seller_name TEXT NOT NULL,
  payment_method TEXT NOT NULL,
  total REAL NOT NULL,
  sync_status TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  sync_attempts INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS local_sale_items (
  id TEXT PRIMARY KEY,
  sale_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  product_name TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_price REAL NOT NULL
);

CREATE TABLE IF NOT EXISTS local_purchases (
  id TEXT PRIMARY KEY,
  supplier_name TEXT NOT NULL,
  registered_by TEXT NOT NULL,
  total REAL NOT NULL,
  sync_status TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  sync_attempts INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS local_purchase_items (
  id TEXT PRIMARY KEY,
  purchase_id TEXT NOT NULL,
  product_id TEXT NOT NULL,
  product_name TEXT NOT NULL,
  quantity INTEGER NOT NULL,
  unit_cost REAL NOT NULL,
  expiry_date TEXT
);

CREATE TABLE IF NOT EXISTS sync_queue (
  id TEXT PRIMARY KEY,
  entity_type TEXT NOT NULL,
  entity_id TEXT NOT NULL,
  sync_status TEXT NOT NULL,
  timestamp TEXT NOT NULL,
  sync_attempts INTEGER NOT NULL DEFAULT 0
);

-- Limpieza segura
DELETE FROM local_sales
WHERE sync_status = 'synced'
  AND timestamp < datetime('now', '-7 day');

DELETE FROM local_purchases
WHERE sync_status = 'synced'
  AND timestamp < datetime('now', '-7 day');
