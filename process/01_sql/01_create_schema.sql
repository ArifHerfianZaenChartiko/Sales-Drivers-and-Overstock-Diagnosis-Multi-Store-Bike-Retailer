-- =============================================================
-- File     : 01_create_schema.sql
-- Purpose  : Create table structure (DDL) for the Bike Store Sample Database
-- Database : PostgreSQL — bike_store
-- Date     : 2026-10-02
-- =============================================================

-- -------------------------------------------------------------
-- How to run:
-- 1. Create the database first (from any database, e.g. postgres):
--        CREATE DATABASE bike_store;
-- 2. Connect to bike_store, then run this whole file
--    (pgAdmin Query Tool or psql).
--
-- Notes:
-- 1. All tables are created in the default "public" schema.
-- 2. Each table mirrors one raw CSV file in data_and_questions/raw_data/
--    (same table name, same column names and order).
-- 3. Tables are created in dependency order:
--    parent tables first (no foreign keys), then child tables.
-- 4. Data is loaded in 02_import_data.sql, and all cleaning is done in
--    04_cleaning.sql.
-- -------------------------------------------------------------


-- Table: brands (bike brands)
DROP TABLE IF EXISTS brands CASCADE;

CREATE TABLE brands (
    brand_id    INT          PRIMARY KEY,
    brand_name  VARCHAR(50)  NOT NULL
);



-- Table: categories (bike categories)
DROP TABLE IF EXISTS categories CASCADE;

CREATE TABLE categories (
	category_id		INT			PRIMARY KEY,
	category_name	VARCHAR(50) NOT NULL
);



-- Table: stores (store locations)
DROP TABLE IF EXISTS stores CASCADE;

CREATE TABLE stores (
	store_id	INT				PRIMARY KEY,
	store_name	VARCHAR(50)		NOT NULL,
	phone		VARCHAR(20),
	email		VARCHAR(50),
	street		VARCHAR(50),
	city		VARCHAR(50),
	state		VARCHAR(2),
	zip_code	VARCHAR(10)
);



-- Table: products (bike products)
DROP TABLE IF EXISTS products CASCADE;

CREATE TABLE products (
	product_id		INT 			PRIMARY KEY,
	product_name	VARCHAR(100)	NOT NULL,
	brand_id		INT				REFERENCES brands(brand_id),
	category_id		INT				REFERENCES categories(category_id),
	model_year		SMALLINT,
	list_price		NUMERIC(10,2)
);



-- Table: customers (customer data)
DROP TABLE IF EXISTS customers CASCADE;

CREATE TABLE customers (
	customer_id		INT				PRIMARY KEY,
	first_name		VARCHAR(20)		NOT NULL,
	last_name		VARCHAR(20)		NOT NULL,
	phone			VARCHAR(20),
	email			VARCHAR(50),
	street			VARCHAR(50),
	city			VARCHAR(50),
	state			VARCHAR(2),
	zip_code		VARCHAR(10)
);



-- Table: staffs (store employees)
DROP TABLE IF EXISTS staffs CASCADE;

CREATE TABLE staffs (
	staff_id	INT			PRIMARY KEY,
	first_name	VARCHAR(20)	NOT NULL,
	last_name	VARCHAR(20)	NOT NULL,
	email		VARCHAR(50),
	phone		VARCHAR(20),
	active		SMALLINT,
	store_id	INT			REFERENCES stores(store_id),
	manager_id	INT		REFERENCES staffs(staff_id)
);



-- Table: orders (sales orders)
DROP TABLE IF EXISTS orders CASCADE;

CREATE TABLE orders (
	order_id		INT			PRIMARY KEY,
	customer_id		INT			REFERENCES customers(customer_id),
	order_status	SMALLINT	NOT NULL,
	order_date		DATE		NOT NULL,
	required_date	DATE		NOT NULL,
	shipped_date	DATE,
	store_id		INT			REFERENCES stores(store_id),
	staff_id		INT			REFERENCES staffs(staff_id)
);





-- Table: order_items (line item of each order)
DROP TABLE IF EXISTS order_items CASCADE;

CREATE TABLE order_items (
	order_id		INT				REFERENCES orders(order_id),
	item_id			INT,
	product_id		INT				REFERENCES products(product_id),
	quantity		INT				NOT NULL,
	list_price		NUMERIC(10,2)	NOT NULL,
	discount		NUMERIC(4,2)	NOT NULL,
	PRIMARY KEY		(order_id, item_id)
);




-- Table: stocks (product stock per store)
DROP TABLE IF EXISTS stocks CASCADE;

CREATE TABLE stocks (
	store_id		INT		REFERENCES stores(store_id),
	product_id		INT		REFERENCES products(product_id),
	quantity		INT 	NOT NULL,
	PRIMARY KEY		(store_id, product_id)
);
