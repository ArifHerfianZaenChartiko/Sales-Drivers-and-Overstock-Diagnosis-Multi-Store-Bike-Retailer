-- =============================================================
-- File     : 04_cleaning.sql
-- Purpose  : Data cleaning and validation (duplicates, NULLs, data types, consistency)
-- Database : PostgreSQL — bike_store
-- Date     : 2026-10-02
-- =============================================================
-- Exploration (03_exploration.sql) found no impossible values, untrimmed text or orphan ids,
-- so no raw rows are changed or deleted. Cleaning decisions are applied through two views
-- that 05_analysis.sql, Python, Excel and Power BI read from:
--   * vw_sales : one row per order line, completed orders only, with names and revenue
--   * vw_stock : current stock snapshot with product, brand, category and store names
--
-- Decisions (from exploration):
--   1. Sales = order_status 4 (Completed), Jan 2016 - Mar 2018.
--      Pending/Processing (Apr 2018) and Rejected orders are not sales.     (queries 4, 5, 20)
--   2. Net revenue = quantity * list_price * (1 - discount).
--      order_items.list_price always equals the catalog price.               (query 15)
--   3. The 29 product names listed under two categories are kept as separate
--      product_ids, as in the source catalog.                                (query 12)
--   4. NULL phone (customers), NULL shipped_date (non-completed orders) and
--      NULL manager_id (top manager) are valid and kept.                     (queries 5, 10)
--   5. Products 314-321 have no stock rows, so they are treated as 0 stock and
--      vw_stock keeps the source rows as they are.                           (queries 8, 9)
-- =============================================================


-- 1. Sales view: completed order lines
DROP VIEW IF EXISTS vw_sales;
CREATE VIEW vw_sales AS
SELECT
	o.order_id,
	oi.item_id,
	o.order_date,
	DATE_TRUNC('month', o.order_date)::DATE                AS order_month,
	EXTRACT(YEAR FROM o.order_date)::INT                   AS order_year,
	o.required_date,
	o.shipped_date,
	o.customer_id,
	c.city                                                 AS customer_city,
	c.state                                                AS customer_state,
	o.store_id,
	s.store_name,
	o.staff_id,
	st.first_name || ' ' || st.last_name                   AS staff_name,
	oi.product_id,
	p.product_name,
	p.model_year,
	b.brand_name,
	cat.category_name,
	oi.quantity,
	oi.list_price,
	oi.discount,
	oi.quantity * oi.list_price                            AS gross_revenue,
	oi.quantity * oi.list_price * oi.discount              AS discount_amount,
	oi.quantity * oi.list_price * (1 - oi.discount)        AS net_revenue
FROM orders AS o
JOIN order_items AS oi
	ON o.order_id = oi.order_id
JOIN customers AS c
	ON o.customer_id = c.customer_id
JOIN stores AS s
	ON o.store_id = s.store_id
JOIN staffs AS st
	ON o.staff_id = st.staff_id
JOIN products AS p
	ON oi.product_id = p.product_id
JOIN brands AS b
	ON p.brand_id = b.brand_id
JOIN categories AS cat
	ON p.category_id = cat.category_id
WHERE o.order_status = 4;


-- 2. Stock view: current stock snapshot
DROP VIEW IF EXISTS vw_stock;
CREATE VIEW vw_stock AS
SELECT
	sk.store_id,
	s.store_name,
	sk.product_id,
	p.product_name,
	p.model_year,
	p.list_price,
	b.brand_name,
	cat.category_name,
	sk.quantity                 AS stock_units,
	sk.quantity * p.list_price  AS stock_value
FROM stocks AS sk
JOIN stores AS s
	ON sk.store_id = s.store_id
JOIN products AS p
	ON sk.product_id = p.product_id
JOIN brands AS b
	ON p.brand_id = b.brand_id
JOIN categories AS cat
	ON p.category_id = cat.category_id;


-- 3. Validation: views must match the source tables
SELECT 'vw_sales' AS check_name,
	COUNT(*)                   AS row_count,
	COUNT(DISTINCT order_id)   AS orders,
	MIN(order_date)            AS first_date,
	MAX(order_date)            AS last_date,
	SUM(quantity)              AS units,
	ROUND(SUM(net_revenue), 2) AS net_revenue
FROM vw_sales
UNION ALL
SELECT 'vw_stock',
	COUNT(*),
	COUNT(DISTINCT product_id),
	NULL, NULL,
	SUM(stock_units),
	ROUND(SUM(stock_value), 2)
FROM vw_stock;
-- Result: vw_sales = 4214 lines, 1445 orders, 2016-01-01 to 2018-03-31, 6318 units, net 6,662,615.24
--         vw_stock = 939 rows, 313 products, 13,511 units, stock value 19,819,582.65 (at list price)
-- Both match the completed-order totals in 03_exploration.sql (queries 6 and 21).
