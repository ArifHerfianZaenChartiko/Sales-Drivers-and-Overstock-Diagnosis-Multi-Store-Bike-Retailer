# Business Questions and Data

This document is the starting point of the project: the problem to solve, the questions derived from it, and the data available to answer them.

**Prepared for:** Management of a multi-store bike retailer (three stores in California, New York and Texas)

---

## 1. Background

A bicycle retailer runs three stores in California, New York and Texas and sells 9 brands across 7 categories. Management wants a sales and inventory review: where revenue comes from, how the stores and products perform, and whether the stock held in each store matches what actually sells.

## 2. Questions

| #  | Question                                                         | Answered in          |
| -- | ---------------------------------------------------------------- | -------------------- |
| Q1 | How has revenue developed over time?                             | `05_analysis.sql` Q1 |
| Q2 | How does each store perform, and does its stock match its sales? | `05_analysis.sql` Q2 |
| Q3 | How do sales staff compare within each store?                    | `05_analysis.sql` Q3 |
| Q4 | Which categories and brands drive revenue?                       | `05_analysis.sql` Q4 |
| Q5 | How concentrated is revenue across products?                     | `05_analysis.sql` Q5 |
| Q6 | Where is stock too high compared with sales?                     | `05_analysis.sql` Q6 |
| Q7 | How much do discounts cost, and do bigger discounts sell more?   | `05_analysis.sql` Q7 |

## 3. Available Data

The raw data is in the [`raw_data/`](raw_data/) folder: 9 CSV files covering orders from Jan 2016 to Dec 2018. File names are kept as in the original source so they can be matched against it.

| File              | Contents                                      | Rows  |
| ----------------- | --------------------------------------------- | ----- |
| `orders.csv`      | Orders, status, store, staff, and dates       | 1,615 |
| `order_items.csv` | Items in each order, price, discount          | 4,722 |
| `customers.csv`   | Customers and their location                  | 1,445 |
| `products.csv`    | Products, brand, category, model year, price  | 321   |
| `stocks.csv`      | Stock of each product per store               | 939   |
| `staffs.csv`      | Store staff and their managers                | 10    |
| `stores.csv`      | Stores and their location                     | 3     |
| `brands.csv`      | List of brands                                | 9     |
| `categories.csv`  | List of product categories                    | 7     |

**Source:** [Bike Store Sample Database](https://www.kaggle.com/datasets/dillonmyrick/bike-store-sample-database) (Kaggle).

## 4. Analysis Scope

- **Sales:** completed orders only (`order_status = 4`), January 2016 to March 2018 (27 months). Completed sales stop on 31 March 2018, and all later orders are pending, processing or rejected.
- **Net revenue:** quantity × list price × (1 − discount).
- **Stock:** a single undated snapshot, compared with sales from the last 12 months (April 2017 to March 2018).

**Out of scope** (not supported by the data):

- Profit and margin: the data has no cost information.
- Customer retention: every customer has only one completed order.
