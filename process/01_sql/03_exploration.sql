-- =============================================================
-- File     : 03_exploration.sql
-- Purpose  : Data exploration (profiling) before cleaning and analysis
-- Database : PostgreSQL — bike_store
-- Date     : 2026-10-04
-- =============================================================

-- =============================================================
-- PART 1: DATA PROFILING
-- =============================================================

-- 1. Data period: first and last order date
SELECT
    MIN(order_date) AS first_order,
    MAX(order_date) AS last_order
FROM orders;
-- Result: 2016-01-01 to 2018-12-28 (~3 years)


-- 2. Number of orders per year
SELECT
	EXTRACT(YEAR FROM order_date) AS order_year,
	COUNT(*)					   AS total_orders
FROM orders
GROUP BY order_year
ORDER BY order_year;
-- Result: 2016 = 635, 2017 = 688, 2018 = 292 (sharp drop, needs checking)




-- 3. Number of orders per month
SELECT
	EXTRACT(YEAR FROM order_date) AS order_year,
	EXTRACT(MONTH FROM order_date) AS order_month,
	COUNT(*) AS total_orders
FROM orders
GROUP BY order_year, order_month
ORDER BY order_year, order_month;
-- Result: stable 35-68 orders/month (Jan 2016 - Mar 2018).
-- Apr 2018 spikes to 125, May 2018 has 0 orders,
-- Jun-Dec 2018 only 1-4 orders/month -> 2018 data is incomplete after April.





-- 4. Number of orders per status
-- (1 = Pending, 2 = Processing, 3 = Rejected, 4 = Completed)
SELECT
	order_status,
	COUNT(*) AS total_orders
FROM orders
GROUP BY order_status
ORDER BY order_status;
-- Result: Completed 1445 (89.5%), Pending 62, Processing 63, Rejected 45.
-- Non-completed = 170 orders (confirmed in query 5).





-- 5. Orders with no shipped date, per status
SELECT order_status,
	COUNT(*) AS total_orders
FROM orders
WHERE shipped_date IS NULL
GROUP BY order_status
ORDER BY order_status;
-- Result: NULL shipped_date only in status 1, 2, 3 (62 + 63 + 45 = 170).
-- All completed orders have a shipped date -> NULLs are valid, not dirty data.
-- Sales analysis should use completed orders only (order_status = 4).






-- 6. Stock overview per store
SELECT store_id,
	COUNT(*) AS total_products,
	SUM(quantity) AS total_units
FROM stocks
GROUP BY store_id
ORDER BY store_id;
-- Result: each store lists 313 products (catalog has 321 -> 8 products missing from stocks).
-- Total units almost equal: store 1 = 4532, store 2 = 4359, store 3 = 4620.





-- 7. Out-of-stock products per store
SELECT store_id,
	COUNT(*) AS out_of_stock_products
FROM stocks
WHERE quantity = 0
GROUP BY store_id
ORDER BY store_id;
-- Result: out-of-stock products: store 1 = 10, store 2 = 10, store 3 = 5 (of 313).




-- 8. Products in catalog but missing from stocks
SELECT
    p.product_id,
    p.product_name
FROM products AS p
LEFT JOIN stocks AS s
    ON p.product_id = s.product_id 
WHERE s.product_id IS NULL;
-- Result: 8 products (product_id 314-321), all newest model years (2018-2019).
-- Likely new catalog items not yet distributed to stores -> not dirty data.





-- 9. Sales history of the 8 products missing from stocks
SELECT
	p.product_id,
	COUNT(oi.product_id) AS times_ordered
FROM products AS p
LEFT JOIN order_items AS oi
	ON p.product_id = oi.product_id
WHERE p.product_id BETWEEN 314 AND 321
GROUP BY p.product_id
ORDER BY p.product_id;
-- Result: only 314 and 315 were ordered (1 time each), while 316-321 never sold.
-- Stocks is a current snapshot -> these are new or discontinued items with no stock.
-- Impact on analysis is negligible (2 order lines out of 4722).




-- =============================================================
-- PART 2: DATA QUALITY CHECKS
-- =============================================================

-- 10. Missing values in customers
SELECT
	COUNT(*) FILTER (WHERE phone IS NULL)    AS phone_null,
	COUNT(*) FILTER (WHERE email IS NULL)    AS email_null,
	COUNT(*) FILTER (WHERE street IS NULL)   AS street_null,
	COUNT(*) FILTER (WHERE city IS NULL)     AS city_null,
	COUNT(*) FILTER (WHERE state IS NULL)    AS state_null,
	COUNT(*) FILTER (WHERE zip_code IS NULL) AS zip_null
FROM customers;
-- Result: phone is NULL for 1267 of 1445 customers (87.7%), and every other column is complete.
-- staffs: only manager_id is NULL (1 row = staff 1, the top manager -> valid).
-- products and orders: no NULLs in foreign keys, price or model year.
-- Phone is not needed for analysis -> keep as is.




-- 11. Duplicate customers
SELECT
	COUNT(*)                                AS total_customers,
	COUNT(DISTINCT LOWER(TRIM(email)))      AS distinct_emails,
	COUNT(DISTINCT (first_name, last_name)) AS distinct_names
FROM customers;

SELECT customer_id, first_name, last_name, email, city
FROM customers
WHERE (first_name, last_name) IN (
	SELECT first_name, last_name
	FROM customers
	GROUP BY first_name, last_name
	HAVING COUNT(*) > 1
);
-- Result: 1445 customers, 1445 distinct emails. One shared name (Justina Jenkins, id 315 and 1425)
-- with different emails and cities -> two different people, not a duplicate.




-- 12. Duplicate product names
SELECT
	product_name,
	COUNT(*)                    AS rows_with_name,
	COUNT(DISTINCT category_id) AS categories,
	COUNT(DISTINCT list_price)  AS prices
FROM products
GROUP BY product_name
HAVING COUNT(*) > 1
ORDER BY rows_with_name DESC, product_name;
-- Result: 29 product names appear more than once (59 rows). Same brand, price and model year,
-- but a different category (e.g. "Electra Cruiser 1 (24-Inch) - 2016" is listed as both
-- Cruisers and Children Bicycles). 58 of the 59 ids have sales.
-- The source catalog lists one bike under two categories -> each product_id is a separate SKU.
-- Decision needed in cleaning: keep as is (category totals follow the source) or merge.




-- 13. Leading/trailing spaces in text columns
SELECT
	(SELECT COUNT(*) FROM customers
	 WHERE first_name <> TRIM(first_name) OR last_name <> TRIM(last_name)
	    OR email <> TRIM(email) OR city <> TRIM(city))  AS customers_untrimmed,
	(SELECT COUNT(*) FROM products
	 WHERE product_name <> TRIM(product_name))          AS products_untrimmed;
-- Result: 0 and 0 -> text columns are clean.




-- 14. Value ranges in order_items
SELECT
	MIN(quantity)   AS min_qty,   MAX(quantity)   AS max_qty,
	MIN(list_price) AS min_price, MAX(list_price) AS max_price,
	MIN(discount)   AS min_disc,  MAX(discount)   AS max_disc
FROM order_items;

SELECT discount, COUNT(*) AS order_lines
FROM order_items
GROUP BY discount
ORDER BY discount;
-- Result: quantity 1-2, price 89.99-11,999.99, discount 0.05-0.20. No zero or negative values.
-- Only 4 discount levels, spread almost evenly: 5% = 1205, 7% = 1156, 10% = 1158, 20% = 1203.
-- Every line has a discount (no full-price sales).




-- 15. Order price vs catalog price
SELECT
	COUNT(*)                                              AS order_lines,
	COUNT(*) FILTER (WHERE oi.list_price <> p.list_price) AS price_differs
FROM order_items AS oi
JOIN products AS p
	ON oi.product_id = p.product_id;
-- Result: 4722 lines, 0 differ -> order_items.list_price always equals the catalog price.
-- Price changes over time cannot be analysed. Net revenue = quantity * list_price * (1 - discount).




-- 16. Product catalog by model year
SELECT
	model_year,
	COUNT(*)        AS products,
	MIN(list_price) AS min_price,
	MAX(list_price) AS max_price
FROM products
GROUP BY model_year
ORDER BY model_year;
-- Result: 2016 = 26, 2017 = 85, 2018 = 204, 2019 = 6 products. Prices 89.99-11,999.99.
-- model_year always matches the year at the end of product_name.




-- 17. Date logic in orders
SELECT
	COUNT(*) FILTER (WHERE shipped_date < order_date)    AS shipped_before_order,
	COUNT(*) FILTER (WHERE required_date < order_date)   AS required_before_order,
	COUNT(*) FILTER (WHERE shipped_date > required_date) AS shipped_late,
	MIN(required_date - order_date) AS min_req_days,
	MAX(required_date - order_date) AS max_req_days,
	MIN(shipped_date - order_date)  AS min_ship_days,
	MAX(shipped_date - order_date)  AS max_ship_days
FROM orders;
-- Result: no impossible dates. Required date is 0-3 days after the order (0 only for the 170
-- non-completed orders), shipping takes 1-3 days. 458 orders shipped after the required date.




-- 18. Orphan and unused records
SELECT
	(SELECT COUNT(*) FROM orders o
	 WHERE NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.order_id = o.order_id))     AS orders_without_items,
	(SELECT COUNT(*) FROM customers c
	 WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.customer_id = c.customer_id))      AS customers_without_orders,
	(SELECT COUNT(*) FROM products p
	 WHERE NOT EXISTS (SELECT 1 FROM order_items oi WHERE oi.product_id = p.product_id)) AS products_never_ordered,
	(SELECT COUNT(*) FROM staffs s
	 WHERE NOT EXISTS (SELECT 1 FROM orders o WHERE o.staff_id = s.staff_id))           AS staff_without_orders;
-- Result: 0 orders without items, 0 customers without orders.
-- 14 products never ordered (6 of them are the 2019 models 316-321, see query 9).
-- 4 staff never took an order: 1, 4, 5, 10 (see query 26).
-- Foreign keys in 01_create_schema.sql already guarantee there are no orphan ids.




-- 19. Order lines: item numbering and repeated products
SELECT
	(SELECT COUNT(*) FROM (
		SELECT order_id FROM order_items
		GROUP BY order_id HAVING MAX(item_id) <> COUNT(*)) AS x)        AS orders_with_item_gaps,
	(SELECT COUNT(*) FROM (
		SELECT order_id, product_id FROM order_items
		GROUP BY order_id, product_id HAVING COUNT(*) > 1) AS y)        AS repeated_product_in_order,
	(SELECT ROUND(AVG(n), 2) FROM (
		SELECT COUNT(*) AS n FROM order_items GROUP BY order_id) AS z)  AS avg_lines_per_order;
-- Result: item_id runs 1..n with no gaps, no product is repeated inside one order,
-- 2.92 lines per order on average (max 5).




-- =============================================================
-- PART 3: SALES PERIOD AND ORDER STATUS
-- =============================================================

-- 20. Date range per order status
SELECT
	order_status,
	COUNT(*)        AS total_orders,
	MIN(order_date) AS first_order,
	MAX(order_date) AS last_order
FROM orders
GROUP BY order_status
ORDER BY order_status;
-- Result: Completed (4) = 2016-01-01 to 2018-03-31.
-- Pending (1) and Processing (2) = April 2018 only (the 125-order spike in query 3).
-- Rejected (3) = spread over 2016-2018, and the only orders after April 2018.
-- -> Completed sales end on 2018-03-31. Apr 2018 holds open orders, May-Dec 2018 rejected only.
-- -> Sales analysis window: Jan 2016 - Mar 2018 (27 months), order_status = 4.




-- 21. Revenue by order status
SELECT
	o.order_status,
	COUNT(DISTINCT o.order_id)                                     AS total_orders,
	SUM(oi.quantity)                                               AS units,
	ROUND(SUM(oi.quantity * oi.list_price), 2)                     AS gross_revenue,
	ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 2) AS net_revenue
FROM orders AS o
JOIN order_items AS oi
	ON o.order_id = oi.order_id
GROUP BY o.order_status
ORDER BY o.order_status;
-- Result: Completed = 1445 orders, 6318 units, gross 7,438,010.06, net 6,662,615.24.
-- Non-completed (1-3) = 170 orders, net 1,026,501.31 (not counted as sales).
-- Discounts reduce completed revenue by 775,394.82 (10.4% of gross).




-- 22. Monthly net revenue (completed orders)
SELECT
	DATE_TRUNC('month', o.order_date)::DATE                        AS order_month,
	COUNT(DISTINCT o.order_id)                                     AS total_orders,
	ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 0) AS net_revenue
FROM orders AS o
JOIN order_items AS oi
	ON o.order_id = oi.order_id
WHERE o.order_status = 4
GROUP BY order_month
ORDER BY order_month;
-- Result: 2016 = 2,372,849 | 2017 = 3,346,973 | Q1 2018 = 942,793 (3 months only).
-- Order count stays flat (34-68/month) but revenue grows from 2017 -> higher value per order.
-- Highest month: Jan 2018 (381,430), lowest: Feb 2016 (148,506).




-- 23. Order value (completed orders)
SELECT
	ROUND(AVG(order_value), 2)                                                  AS avg_order_value,
	ROUND(PERCENTILE_CONT(0.5) WITHIN GROUP (ORDER BY order_value)::NUMERIC, 2) AS median_order_value
FROM (
	SELECT
		oi.order_id,
		SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS order_value
	FROM order_items AS oi
	JOIN orders AS o
		ON oi.order_id = o.order_id
	WHERE o.order_status = 4
	GROUP BY oi.order_id
) AS t;
-- Result: average 4,610.81, median 3,540.36 -> skewed by a few high-value orders.




-- 24. Orders by day of week (completed orders)
SELECT
	EXTRACT(ISODOW FROM order_date) AS day_no,
	TO_CHAR(order_date, 'Dy')       AS day_name,
	COUNT(*)                        AS total_orders
FROM orders
WHERE order_status = 4
GROUP BY day_no, day_name
ORDER BY day_no;
-- Result: 188-239 orders per weekday, no strong pattern (Sunday highest at 239).




-- =============================================================
-- PART 4: STORES AND STAFF
-- =============================================================

-- 25. Sales per store (completed orders)
SELECT
	s.store_name,
	COUNT(DISTINCT o.order_id)                                     AS total_orders,
	SUM(oi.quantity)                                               AS units,
	ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 0) AS net_revenue
FROM orders AS o
JOIN order_items AS oi
	ON o.order_id = oi.order_id
JOIN stores AS s
	ON o.store_id = s.store_id
WHERE o.order_status = 4
GROUP BY s.store_name
ORDER BY net_revenue DESC;
-- Result: Baldwin Bikes (NY)    = 1019 orders, 4,701,210 (70.6%)
--         Santa Cruz Bikes (CA) =  284 orders, 1,255,492 (18.8%)
--         Rowlett Bikes (TX)    =  142 orders,   705,914 (10.6%)
-- Stock units are almost equal across stores (query 6) while sales differ up to 7x.




-- 26. Staff structure and sales (completed orders)
SELECT
	st.staff_id,
	st.first_name || ' ' || st.last_name                           AS staff_name,
	st.store_id,
	st.manager_id,
	COUNT(DISTINCT o.order_id)                                     AS total_orders,
	ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 0) AS net_revenue
FROM staffs AS st
LEFT JOIN orders AS o
	ON st.staff_id = o.staff_id
	AND o.order_status = 4
LEFT JOIN order_items AS oi
	ON o.order_id = oi.order_id
GROUP BY st.staff_id, staff_name, st.store_id, st.manager_id
ORDER BY st.staff_id;
-- Result: 10 staff, all active. 6 handle orders, 2 per store:
--   store 1: staff 2 (137) and 3 (147) | store 2: 6 (521) and 7 (498) | store 3: 8 (71) and 9 (71).
-- Staff 1 (top manager), 4, 5 (store 2 manager) and 10 have no orders.
-- Staff 9 and 10 (store 3) report to staff 7, who works in store 2.
-- Every order's store_id matches its staff member's store_id.




-- =============================================================
-- PART 5: PRODUCTS, BRANDS AND CATEGORIES
-- =============================================================

-- 27. Sales per category (completed orders)
SELECT
	c.category_name,
	SUM(oi.quantity)                                               AS units,
	ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 0) AS net_revenue,
	ROUND(100 * SUM(oi.quantity * oi.list_price * (1 - oi.discount))
		/ SUM(SUM(oi.quantity * oi.list_price * (1 - oi.discount))) OVER (), 1) AS pct_revenue
FROM orders AS o
JOIN order_items AS oi
	ON o.order_id = oi.order_id
JOIN products AS p
	ON oi.product_id = p.product_id
JOIN categories AS c
	ON p.category_id = c.category_id
WHERE o.order_status = 4
GROUP BY c.category_name
ORDER BY net_revenue DESC;
-- Result: Mountain 37.3% | Road 19.9% | Cruisers 13.0% | Electric 11.0% | Cyclocross 9.6%
--         Comfort 5.2% | Children 3.9%.
-- Cruisers sell the most units (1865) but rank 3rd in revenue (low price),
-- Road and Electric are the opposite (few units, high price).




-- 28. Sales per brand (completed orders) vs catalog size
SELECT
	b.brand_name,
	COUNT(DISTINCT p.product_id)                                                AS products_in_catalog,
	COALESCE(SUM(oi.quantity), 0)                                               AS units,
	ROUND(COALESCE(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 0), 0) AS net_revenue
FROM brands AS b
JOIN products AS p
	ON b.brand_id = p.brand_id
LEFT JOIN order_items AS oi
	ON p.product_id = oi.product_id
	AND oi.order_id IN (SELECT order_id FROM orders WHERE order_status = 4)
GROUP BY b.brand_name
ORDER BY net_revenue DESC;
-- Result: Trek 58.8% (135 products) | Electra 15.3% (118) | Surly 13.0% (25)
--         Sun Bicycles 4.7% | Haro 2.5% | Heller 2.4% | Pure Cycles 2.1% | Ritchey 1.2% | Strider 0.0%.
-- Trek + Electra + Surly = 87% of revenue. Strider sold only 13 units (2,014).




-- 29. Top 10 products by net revenue (completed orders)
SELECT
	p.product_id,
	p.product_name,
	SUM(oi.quantity)                                               AS units,
	ROUND(SUM(oi.quantity * oi.list_price * (1 - oi.discount)), 0) AS net_revenue
FROM orders AS o
JOIN order_items AS oi
	ON o.order_id = oi.order_id
JOIN products AS p
	ON oi.product_id = p.product_id
WHERE o.order_status = 4
GROUP BY p.product_id, p.product_name
ORDER BY net_revenue DESC
LIMIT 10;
-- Result: #1 Trek Slash 8 27.5 - 2016 (151 units, 544,319), then Trek Conduit+ - 2016
-- and Trek Fuel EX 8 29 - 2016. All top 10 are Trek or Surly, and 6 are 2016 models.




-- 30. Revenue concentration (Pareto)
WITH product_revenue AS (
	SELECT
		oi.product_id,
		SUM(oi.quantity * oi.list_price * (1 - oi.discount)) AS net_revenue
	FROM orders AS o
	JOIN order_items AS oi
		ON o.order_id = oi.order_id
	WHERE o.order_status = 4
	GROUP BY oi.product_id
),
ranked AS (
	SELECT
		ROW_NUMBER() OVER (ORDER BY net_revenue DESC)     AS rank_no,
		SUM(net_revenue) OVER (ORDER BY net_revenue DESC) AS cumulative,
		SUM(net_revenue) OVER ()                          AS total,
		COUNT(*) OVER ()                                  AS sold_products
	FROM product_revenue
)
SELECT
	MIN(rank_no)       AS products_for_80pct,
	MAX(sold_products) AS sold_products
FROM ranked
WHERE cumulative >= 0.8 * total;
-- Result: 53 of 278 sold products (19%) make 80% of net revenue.




-- 31. Units sold vs units in stock, by model year
SELECT
	p.model_year,
	COALESCE(sold.units, 0)      AS units_sold,
	COALESCE(stk.stock_units, 0) AS units_in_stock
FROM (SELECT DISTINCT model_year FROM products) AS p
LEFT JOIN (
	SELECT pr.model_year, SUM(oi.quantity) AS units
	FROM orders AS o
	JOIN order_items AS oi ON o.order_id = oi.order_id
	JOIN products AS pr    ON oi.product_id = pr.product_id
	WHERE o.order_status = 4
	GROUP BY pr.model_year
) AS sold
	ON p.model_year = sold.model_year
LEFT JOIN (
	SELECT pr.model_year, SUM(s.quantity) AS stock_units
	FROM stocks AS s
	JOIN products AS pr ON s.product_id = pr.product_id
	GROUP BY pr.model_year
) AS stk
	ON p.model_year = stk.model_year
ORDER BY p.model_year;
-- Result: 2016 models = 3379 sold / 1046 in stock | 2017 = 2485 / 3787
--         2018 = 454 / 8678 | 2019 = 0 / 0.
-- 64% of stock units are 2018 models, which sold little because the data ends in Mar 2018.
-- stocks has no date -> it is one snapshot, so stock movement over time cannot be tracked.




-- =============================================================
-- PART 6: CUSTOMERS
-- =============================================================

-- 32. Customers per state and the store they buy from
SELECT
	c.state,
	o.store_id,
	COUNT(DISTINCT c.customer_id) AS customers,
	COUNT(*)                      AS total_orders
FROM customers AS c
JOIN orders AS o
	ON c.customer_id = o.customer_id
GROUP BY c.state, o.store_id
ORDER BY c.state, o.store_id;
-- Result: CA = 284 customers -> store 1 only | NY = 1019 -> store 2 only | TX = 142 -> store 3 only.
-- Every customer buys only from the store in their own state. Customers live in 195 cities.




-- 33. Orders per customer
SELECT
	n_orders,
	COUNT(*) AS customers
FROM (
	SELECT customer_id, COUNT(*) AS n_orders
	FROM orders
	GROUP BY customer_id
) AS t
GROUP BY n_orders
ORDER BY n_orders;

SELECT
	n_completed,
	COUNT(*) AS customers
FROM (
	SELECT customer_id, COUNT(*) AS n_completed
	FROM orders
	WHERE order_status = 4
	GROUP BY customer_id
) AS t
GROUP BY n_completed
ORDER BY n_completed;
-- Result: all orders -> 1314 customers with 1 order, 92 with 2, 39 with 3.
-- Completed only -> all 1445 customers have exactly 1 completed order.
-- Every extra order (92 + 2*39 = 170) is a pending, processing or rejected order.
-- -> No repeat buyers in completed sales: retention / repeat-purchase analysis is not possible.




-- 34. New customers per year (first completed order)
SELECT
	EXTRACT(YEAR FROM first_order) AS first_year,
	COUNT(*)                       AS new_customers
FROM (
	SELECT customer_id, MIN(order_date) AS first_order
	FROM orders
	WHERE order_status = 4
	GROUP BY customer_id
) AS t
GROUP BY first_year
ORDER BY first_year;
-- Result: 2016 = 620, 2017 = 671, 2018 (Q1) = 154. Same as completed orders per year,
-- because each customer has exactly one completed order.




-- =============================================================
-- PART 7: SHIPPING
-- =============================================================

-- 35. Days from order to shipment (completed orders)
SELECT
	shipped_date - order_date AS days_to_ship,
	COUNT(*)                  AS total_orders
FROM orders
WHERE order_status = 4
GROUP BY days_to_ship
ORDER BY days_to_ship;
-- Result: 1 day = 489, 2 days = 493, 3 days = 463 -> every order ships within 3 days.




-- 36. Late shipments (shipped after required date)
SELECT
	store_id,
	COUNT(*)                                                                          AS completed_orders,
	COUNT(*) FILTER (WHERE shipped_date > required_date)                              AS late_orders,
	ROUND(100.0 * COUNT(*) FILTER (WHERE shipped_date > required_date) / COUNT(*), 1) AS pct_late
FROM orders
WHERE order_status = 4
GROUP BY store_id
ORDER BY store_id;

SELECT
	shipped_date - required_date AS days_late,
	COUNT(*)                     AS late_orders
FROM orders
WHERE shipped_date > required_date
GROUP BY days_late
ORDER BY days_late;
-- Result: 458 of 1445 completed orders are late (31.7%):
-- store 1 = 36.6%, store 2 = 31.1%, store 3 = 26.1%. By year: 2016 = 30.8%, 2017 = 32.0%, 2018 = 33.8%.
-- Late orders are only 1 day (305) or 2 days (153) late.




-- =============================================================
-- PART 8: DISCOUNTS
-- =============================================================

-- 37. Discount levels (completed orders)
SELECT
	oi.discount,
	COUNT(*)                                                 AS order_lines,
	ROUND(AVG(oi.list_price), 0)                             AS avg_list_price,
	ROUND(SUM(oi.quantity * oi.list_price * oi.discount), 0) AS discount_value
FROM orders AS o
JOIN order_items AS oi
	ON o.order_id = oi.order_id
WHERE o.order_status = 4
GROUP BY oi.discount
ORDER BY oi.discount;

SELECT ROUND(CORR(discount, quantity)::NUMERIC, 3) AS corr_discount_quantity
FROM order_items;
-- Result: 5% = 1078 lines | 7% = 1026 | 10% = 1026 | 20% = 1084.
-- Average list price is about the same at every level (1,152-1,221) and discount has no link
-- to quantity (correlation -0.005). Average discount per category is 10.2%-11.1%.
-- The 20% level alone costs 371,791 (48% of all discount value).
-- -> Discounts look randomly assigned, not tied to price, category or volume.




-- =============================================================
-- EXPLORATION SUMMARY
-- =============================================================
-- Data quality
--   * No impossible dates, negative values, untrimmed text or orphan ids.
--   * NULL shipped_date (170) and NULL manager_id (1) are valid, and NULL phone (87.7%) is unused.
--   * 29 product names exist under two categories (59 ids) -> decide in cleaning.
--   * 8 products (314-321) have no stock rows, and 14 products were never ordered.
--
-- Analysis base
--   * Sales = order_status 4, Jan 2016 - Mar 2018 (27 months): 1445 orders, net 6,662,615.24.
--   * Net revenue = quantity * list_price * (1 - discount). Order price = catalog price.
--
-- Data limitations
--   * Each customer has only one completed order -> no retention / repeat-purchase analysis.
--   * Each customer buys from the store in their own state -> stores do not share customers.
--   * stocks is one undated snapshot -> no stock history.
--   * No cost data -> profit and margin cannot be calculated.
--   * Discounts, shipping days and weekdays are almost evenly spread, which suggests the
--     sample data was generated -> treat patterns in these fields with care.






