-- =============================================================
-- File     : 05_analysis.sql
-- Purpose  : Queries answering business questions Q1–Q7
-- Database : PostgreSQL — bike_store
-- Date     : 2026-10-02
-- =============================================================
-- Reads from the views created in 04_cleaning.sql:
--   vw_sales (completed order lines, Jan 2016 - Mar 2018) and vw_stock (stock snapshot).
-- "Last 12 months" = Apr 2017 - Mar 2018, the most recent full year in the data.
-- =============================================================


-- Q1: How has revenue developed over time?

-- Q1a. Revenue per year
SELECT
	order_year,
	COUNT(DISTINCT order_id)                                     AS total_orders,
	SUM(quantity)                                                AS units,
	ROUND(SUM(net_revenue), 0)                                   AS net_revenue,
	ROUND(SUM(net_revenue) / COUNT(DISTINCT order_id), 0)        AS avg_order_value,
	ROUND(SUM(net_revenue) / SUM(quantity), 0)                   AS avg_price_per_unit
FROM vw_sales
GROUP BY order_year
ORDER BY order_year;
-- Result: 2016 = 620 orders, 2,372,849 | 2017 = 671 orders, 3,346,973 (+41%)
--         2018 (Jan-Mar only) = 154 orders, 942,793.
-- Order count grew only 8% in 2017, so the growth came from a higher price per unit
-- (912 -> 1,105 -> 1,374) and a higher order value (3,827 -> 4,988 -> 6,122).

-- Q1b. Same-period comparison: January-March of each year
SELECT
	order_year,
	COUNT(DISTINCT order_id)                              AS total_orders,
	ROUND(SUM(net_revenue), 0)                            AS net_revenue,
	ROUND(SUM(net_revenue) / COUNT(DISTINCT order_id), 0) AS avg_order_value
FROM vw_sales
WHERE EXTRACT(MONTH FROM order_date) <= 3
GROUP BY order_year
ORDER BY order_year;
-- Result: Q1 2016 = 544,253 | Q1 2017 = 875,742 (+61%) | Q1 2018 = 942,793 (+8%).
-- Q1 2018 had fewer orders than Q1 2017 (154 vs 170) but still grew on order value.

-- Q1c. Category share of revenue per year
SELECT
	order_year,
	category_name,
	ROUND(100 * SUM(net_revenue)
		/ SUM(SUM(net_revenue)) OVER (PARTITION BY order_year), 1) AS pct_of_year
FROM vw_sales
GROUP BY order_year, category_name
ORDER BY category_name, order_year;
-- Result: Road Bikes had no sales in 2016, then 30.0% (2017) and 34.2% (Q1 2018).
-- Mountain Bikes fell from 48.9% to 32.8% to 24.4%, while Electric rose to 18.5% in Q1 2018.
-- -> The shift to higher-priced Road and Electric bikes explains the rising order value.

-- Q1d. Average monthly revenue by calendar month (2016-2017, full years only)
SELECT
	EXTRACT(MONTH FROM order_month) AS month_no,
	ROUND(AVG(monthly_revenue), 0)  AS avg_net_revenue
FROM (
	SELECT order_month, SUM(net_revenue) AS monthly_revenue
	FROM vw_sales
	WHERE order_year < 2018
	GROUP BY order_month
) AS t
GROUP BY month_no
ORDER BY month_no;
-- Result: 192,404 (April) to 290,521 (June). No clear seasonal pattern over two years.




-- Q2: How does each store perform, and does its stock match its sales?
WITH store_sales AS (
	SELECT
		store_name,
		COUNT(DISTINCT order_id)                         AS total_orders,
		SUM(net_revenue)                                 AS net_revenue,
		SUM(quantity) FILTER (WHERE order_date >= '2017-04-01') AS units_last_12m
	FROM vw_sales
	GROUP BY store_name
),
store_stock AS (
	SELECT store_name, SUM(stock_units) AS stock_units
	FROM vw_stock
	GROUP BY store_name
)
SELECT
	s.store_name,
	s.total_orders,
	ROUND(s.net_revenue, 0)                                   AS net_revenue,
	ROUND(100 * s.net_revenue / SUM(s.net_revenue) OVER (), 1) AS pct_revenue,
	k.stock_units,
	ROUND(100.0 * k.stock_units / SUM(k.stock_units) OVER (), 1) AS pct_stock,
	s.units_last_12m,
	ROUND(k.stock_units / (s.units_last_12m / 12.0), 1)       AS months_of_stock
FROM store_sales AS s
JOIN store_stock AS k
	ON s.store_name = k.store_name
ORDER BY net_revenue DESC;
-- Result:
--   Baldwin Bikes    70.6% of revenue | 32.3% of stock | 25 months of stock
--   Santa Cruz Bikes 18.8% of revenue | 33.5% of stock | 103 months of stock
--   Rowlett Bikes    10.6% of revenue | 34.2% of stock | 181 months of stock
-- (months of stock = current stock units / average monthly units sold in the last 12 months)
-- Stock is split equally across stores although Baldwin sells 4x Santa Cruz and 7x Rowlett.

-- Q2b. Store revenue per year
SELECT
	store_name,
	order_year,
	ROUND(SUM(net_revenue), 0) AS net_revenue
FROM vw_sales
GROUP BY store_name, order_year
ORDER BY store_name, order_year;
-- Result: Baldwin +54% and Rowlett +52% in 2017, while Santa Cruz stayed flat (544,659 -> 544,197).




-- Q3: How do sales staff compare within each store?
SELECT
	store_name,
	staff_name,
	COUNT(DISTINCT order_id)                                AS total_orders,
	ROUND(SUM(net_revenue), 0)                              AS net_revenue,
	ROUND(SUM(net_revenue) / COUNT(DISTINCT order_id), 0)   AS avg_order_value,
	ROUND(100 * SUM(net_revenue)
		/ SUM(SUM(net_revenue)) OVER (PARTITION BY store_name), 1) AS pct_of_store,
	ROUND(100.0 * COUNT(DISTINCT order_id) FILTER (WHERE shipped_date > required_date)
		/ COUNT(DISTINCT order_id), 1)                      AS pct_late
FROM vw_sales
GROUP BY store_name, staff_name
ORDER BY store_name, net_revenue DESC;
-- Result: each store has 2 selling staff with a near 50/50 split (46.8%-53.2%).
--   Baldwin: Marcelene Boyer 51.2% / Venita Daniel 48.8%
--   Rowlett: Kali Vargas 53.2% (AOV 5,288) / Layla Terrell 46.8% (AOV 4,654)
--   Santa Cruz: Genna Serrano 51.3% / Mireya Copeland 48.7%
-- Staff results follow store size, and no individual stands out on revenue.
-- Mireya Copeland has the highest late-shipment rate (43.8% vs 23.9%-32.1% for others).




-- Q4: Which categories and brands drive revenue?

-- Q4a. Categories
SELECT
	category_name,
	SUM(quantity)                                              AS units,
	ROUND(SUM(net_revenue), 0)                                 AS net_revenue,
	ROUND(100 * SUM(net_revenue) / SUM(SUM(net_revenue)) OVER (), 1) AS pct_revenue,
	ROUND(SUM(net_revenue) / SUM(quantity), 0)                 AS avg_price_per_unit
FROM vw_sales
GROUP BY category_name
ORDER BY net_revenue DESC;
-- Result: Mountain 37.3% | Road 19.9% | Cruisers 13.0% | Electric 11.0% | Cyclocross 9.6%
--         Comfort 5.2% | Children 3.9%.
-- Cruisers and Children = 46% of units but 17% of revenue (avg 465 and 248 per unit).
-- Road and Electric = 11% of units but 31% of revenue (avg ~2,900 per unit).

-- Q4b. Brands
SELECT
	brand_name,
	SUM(quantity)                                              AS units,
	ROUND(SUM(net_revenue), 0)                                 AS net_revenue,
	ROUND(100 * SUM(net_revenue) / SUM(SUM(net_revenue)) OVER (), 1) AS pct_revenue,
	ROUND(SUM(net_revenue) / SUM(quantity), 0)                 AS avg_price_per_unit
FROM vw_sales
GROUP BY brand_name
ORDER BY net_revenue DESC;
-- Result: Trek 58.8% | Electra 15.3% | Surly 13.0% | the other 6 brands 12.9% together.
-- Trek leads on price (2,506 per unit), while Electra sells the most units (2,329) at 438 per unit.
-- Trek alone covers Mountain (1.71M), Road (1.27M) and Electric (0.68M) revenue.




-- Q5: How concentrated is revenue across products? (ABC classification)
WITH product_revenue AS (
	SELECT product_id, SUM(net_revenue) AS net_revenue
	FROM vw_sales
	GROUP BY product_id
),
ranked AS (
	SELECT
		product_id,
		net_revenue,
		SUM(net_revenue) OVER (ORDER BY net_revenue DESC, product_id)
			/ SUM(net_revenue) OVER () AS cumulative_share
	FROM product_revenue
)
SELECT
	CASE
		WHEN cumulative_share <= 0.80 THEN 'A'
		WHEN cumulative_share <= 0.95 THEN 'B'
		ELSE 'C'
	END                                                         AS abc_class,
	COUNT(*)                                                    AS products,
	ROUND(100.0 * COUNT(*) / SUM(COUNT(*)) OVER (), 1)          AS pct_products,
	ROUND(SUM(net_revenue), 0)                                  AS net_revenue,
	ROUND(100 * SUM(net_revenue) / SUM(SUM(net_revenue)) OVER (), 1) AS pct_revenue
FROM ranked
GROUP BY abc_class
ORDER BY abc_class;
-- Result: A = 52 products (18.7%) -> 79.6% of revenue
--         B = 80 products (28.8%) -> 15.3%
--         C = 146 products (52.5%) -> 5.0%
-- Half of the products that sold make only 5% of revenue.




-- Q6: Where is stock too high compared with sales?

-- Q6a. Stock vs last-12-month sales by model year
WITH sales_12m AS (
	SELECT model_year, SUM(quantity) AS units_last_12m
	FROM vw_sales
	WHERE order_date >= '2017-04-01'
	GROUP BY model_year
),
stock AS (
	SELECT model_year, SUM(stock_units) AS stock_units, SUM(stock_value) AS stock_value
	FROM vw_stock
	GROUP BY model_year
)
SELECT
	k.model_year,
	k.stock_units,
	ROUND(k.stock_value, 0)                                     AS stock_value,
	ROUND(100 * k.stock_value / SUM(k.stock_value) OVER (), 1)  AS pct_stock_value,
	COALESCE(s.units_last_12m, 0)                               AS units_last_12m,
	ROUND(k.stock_units / NULLIF(s.units_last_12m / 12.0, 0), 1) AS months_of_stock
FROM stock AS k
LEFT JOIN sales_12m AS s
	ON k.model_year = s.model_year
ORDER BY k.model_year;
-- Result: total stock value at list price = 19,819,583 (3x the net revenue of all 27 months).
--   2016 models:  987,113 (5.0%)  | 22 months of stock
--   2017 models: 4,428,514 (22.3%) | 24 months of stock
--   2018 models: 14,403,955 (72.7%) | 229 months of stock (only 454 units sold so far)
-- Note: 2018 models were still new when the data ends (Mar 2018), so part of this is normal
-- seasonal build-up, but it is still far above any sales rate seen in the data.

-- Q6b. Stock vs last-12-month sales by category
WITH sales_12m AS (
	SELECT category_name, SUM(quantity) AS units_last_12m
	FROM vw_sales
	WHERE order_date >= '2017-04-01'
	GROUP BY category_name
),
stock AS (
	SELECT category_name, SUM(stock_units) AS stock_units, SUM(stock_value) AS stock_value
	FROM vw_stock
	GROUP BY category_name
)
SELECT
	k.category_name,
	k.stock_units,
	ROUND(k.stock_value, 0)                                      AS stock_value,
	s.units_last_12m,
	ROUND(k.stock_units / NULLIF(s.units_last_12m / 12.0, 0), 1) AS months_of_stock
FROM stock AS k
LEFT JOIN sales_12m AS s
	ON k.category_name = s.category_name
ORDER BY months_of_stock DESC;
-- Result: Electric 102 months | Road 71 | Children 58 | Cruisers 51 | Cyclocross 48
--         Mountain 47 | Comfort 46. Every category holds almost 4 years of stock or more.
-- Road (6.8M) and Electric (3.7M) hold 53% of stock value.

-- Q6c. Stocked products with no sales in the last 12 months
SELECT
	COUNT(DISTINCT product_id)  AS products,
	SUM(stock_units)            AS stock_units,
	ROUND(SUM(stock_value), 0)  AS stock_value
FROM vw_stock
WHERE stock_units > 0
	AND product_id NOT IN (
		SELECT product_id FROM vw_sales WHERE order_date >= '2017-04-01'
	);
-- Result: 35 products, 1,447 units, 2,215,816 in stock value with no sale in the last 12 months.

-- Q6d. Top-selling (class A) products out of stock
WITH product_revenue AS (
	SELECT product_id, SUM(net_revenue) AS net_revenue
	FROM vw_sales
	GROUP BY product_id
),
class_a AS (
	SELECT product_id
	FROM (
		SELECT
			product_id,
			SUM(net_revenue) OVER (ORDER BY net_revenue DESC, product_id)
				/ SUM(net_revenue) OVER () AS cumulative_share
		FROM product_revenue
	) AS t
	WHERE cumulative_share <= 0.80
)
SELECT
	k.store_name,
	COUNT(*)                                   AS class_a_products,
	COUNT(*) FILTER (WHERE k.stock_units = 0)  AS out_of_stock
FROM vw_stock AS k
JOIN class_a AS a
	ON k.product_id = a.product_id
GROUP BY k.store_name
ORDER BY k.store_name;
-- Result: only 2-3 of the 52 class A products are out of stock per store.
-- -> The issue is too much stock overall, not missing best-sellers.




-- Q7: How much do discounts cost, and do bigger discounts sell more?

-- Q7a. Discount cost per year
SELECT
	order_year,
	ROUND(SUM(gross_revenue), 0)                              AS gross_revenue,
	ROUND(SUM(discount_amount), 0)                            AS discount_amount,
	ROUND(100 * SUM(discount_amount) / SUM(gross_revenue), 1) AS pct_of_gross
FROM vw_sales
GROUP BY order_year
ORDER BY order_year;
-- Result: discounts cost 775,395 in total, a steady 10.4%-10.5% of gross every year.

-- Q7b. Results per discount level
SELECT
	discount,
	COUNT(*)                        AS order_lines,
	ROUND(AVG(quantity), 2)         AS avg_units_per_line,
	ROUND(SUM(net_revenue), 0)      AS net_revenue,
	ROUND(SUM(discount_amount), 0)  AS discount_amount
FROM vw_sales
GROUP BY discount
ORDER BY discount;
-- Result: units per line are the same at every level (1.48-1.52).
-- The 20% level costs 371,791 (48% of all discounts) without selling more units than 5%.
-- -> No sign that higher discounts lift volume. Store discount rates are similar (9.8%-10.5%).
-- (Exploration query 37: discounts look randomly assigned in this sample data.)
