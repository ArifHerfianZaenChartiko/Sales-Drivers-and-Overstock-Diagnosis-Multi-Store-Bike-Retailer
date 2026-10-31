-- =============================================================
-- File     : 02_import_data.sql
-- Purpose  : Load the 9 raw CSV files into the bike_store tables
-- Database : PostgreSQL — bike_store
-- Date     : 2026-10-02
-- =============================================================

-- -------------------------------------------------------------
-- How to run:
-- \copy is a psql client command, not SQL, so this file must be
-- run with psql (or the PSQL Tool in pgAdmin), NOT the Query Tool.
-- CSV paths are relative to the project root folder ("Sales Drivers and Overstock Diagnosis Multi-Store Bike Retailer/").
--
--   Option A - terminal, from the project root folder:
--       psql -U postgres -d bike_store -f process/01_sql/02_import_data.sql
--
--   Option B - pgAdmin PSQL Tool (connected to bike_store).
--   Every new PSQL Tool session starts in the pgAdmin folder,
--   so run \cd first each time:
--       \cd 'C:/path/to/Sales Drivers and Overstock Diagnosis Multi-Store Bike Retailer'
--       \i process/01_sql/02_import_data.sql
--
-- Notes:
-- 1. Run 01_create_schema.sql first.
-- 2. Order matters: parent tables first (foreign keys are already set).
-- 3. The raw CSVs use the text NULL for missing values.
-- -------------------------------------------------------------


\copy brands FROM 'data_and_questions/raw_data/brands.csv' WITH (FORMAT csv, HEADER true, NULL 'NULL');
\copy categories  FROM 'data_and_questions/raw_data/categories.csv'  WITH (FORMAT csv, HEADER true, NULL 'NULL');
\copy stores      FROM 'data_and_questions/raw_data/stores.csv'      WITH (FORMAT csv, HEADER true, NULL 'NULL');
\copy products    FROM 'data_and_questions/raw_data/products.csv'    WITH (FORMAT csv, HEADER true, NULL 'NULL');
\copy customers   FROM 'data_and_questions/raw_data/customers.csv'   WITH (FORMAT csv, HEADER true, NULL 'NULL');
\copy staffs      FROM 'data_and_questions/raw_data/staffs.csv'      WITH (FORMAT csv, HEADER true, NULL 'NULL');
\copy orders      FROM 'data_and_questions/raw_data/orders.csv'      WITH (FORMAT csv, HEADER true, NULL 'NULL');
\copy order_items FROM 'data_and_questions/raw_data/order_items.csv' WITH (FORMAT csv, HEADER true, NULL 'NULL');
\copy stocks      FROM 'data_and_questions/raw_data/stocks.csv'      WITH (FORMAT csv, HEADER true, NULL 'NULL');


-- Validation: row count per table (must match CSV row counts)
SELECT 'brands' AS table_name, COUNT(*) FROM brands
UNION ALL SELECT 'categories',  COUNT(*) FROM categories
UNION ALL SELECT 'stores',      COUNT(*) FROM stores
UNION ALL SELECT 'products',    COUNT(*) FROM products
UNION ALL SELECT 'customers',   COUNT(*) FROM customers
UNION ALL SELECT 'staffs',      COUNT(*) FROM staffs
UNION ALL SELECT 'orders',      COUNT(*) FROM orders
UNION ALL SELECT 'order_items', COUNT(*) FROM order_items
UNION ALL SELECT 'stocks',      COUNT(*) FROM stocks;

-- Result:
-- brands 9 | categories 7 | stores 3 | products 321 | customers 1445
-- staffs 10 | orders 1615 | order_items 4722 | stocks 939
-- All counts match the CSV files (excluding header row).
