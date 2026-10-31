# Analysis Process

This folder holds all the technical work behind the results in [`../deliverables/`](../deliverables/): building the database, exploring and cleaning the data, the analysis, and validating the numbers. It is intended for data teams who want to review or re-run the analysis.

Subfolders are numbered in the order the work was done:

```
raw_data (CSV)
      |
01_sql/      -> database, exploration, cleaning, analysis
      |
02_excel/    -> quick management report with charts
      |
03_python/   -> advanced analysis
      |
../deliverables/  -> Power BI dashboard, report, presentation
```

Entity relationship diagram (ERD): [`erd_bike_store.png`](erd_bike_store.png).

---

## 1. SQL (`01_sql/`)

Run on **PostgreSQL**, database `bike_store`, default `public` schema.

| File                   | Contents                                                                  |
| ---------------------- | ------------------------------------------------------------------------- |
| `01_create_schema.sql` | Creates the 9 tables in dependency order, with primary and foreign keys   |
| `02_import_data.sql`   | Loads the 9 CSV files from `data_and_questions/raw_data/`, checks row counts |
| `03_exploration.sql`   | 37 profiling queries: data quality, sales period, stores, staff, products, customers, shipping, discounts, with a summary of limitations |
| `04_cleaning.sql`      | Documents cleaning decisions and creates the views `vw_sales` (completed order lines with revenue) and `vw_stock` (stock snapshot). Raw tables are not changed |
| `05_analysis.sql`      | Answers business questions Q1–Q7 using the two views                      |

> Table and column names follow the original dataset and are not renamed.

## 2. Excel (`02_excel/`)

`sales_drivers_overstock_report.xlsx` is a quick management report built on the two SQL views.

| Sheet        | Contents                                                                                     |
| ------------ | -------------------------------------------------------------------------------------------- |
| `Report`     | Key figures, revenue by year and month, stores vs stock, categories, brands, discounts, key takeaways, and 3 charts |
| `Sales_Data` | Export of `vw_sales` (4,214 completed order lines), with revenue columns as formulas             |
| `Stock_Data` | Export of `vw_stock` (939 rows)                                                              |
| `Notes`      | Definitions, sources and limitations                                                         |

Every figure on `Report` is a live formula (`SUMIFS` / `COUNTIFS`) on the data sheets, and all totals match `05_analysis.sql`. The start of the last-12-months window is an input cell (`Report!F4`).

## 3. Python (`03_python/`)

`analysis.ipynb` reads all 9 raw CSV files in full with **pandas**, rebuilds the sales data with the same rules as `vw_sales`, and checks the totals against SQL before the analysis. It uses **numpy** for the statistics and **matplotlib** for the charts.

| Section | Method |
| ------- | ------ |
| 1. Revenue trend and drivers | Linear trend (`np.polyfit`), 3-month rolling average, price-volume-mix bridge 2016 to 2017 |
| 2. Product concentration | ABC classes, Pareto curve, Gini coefficient |
| 3. Inventory position | Months of stock by store and category, stock rebalancing scenario, stock by model year |
| 4. Discounts | Permutation test (10,000 shuffles): 20% vs 5% discount |
| 5. Basket analysis | Category co-occurrence and lift |

The 6 charts are saved as PNG files in `03_python/charts/`.

## 4. Power BI (`../deliverables/dashboard/`)

`sales_drivers_overstock_dashboard.pbix` loads the 9 raw CSV files through Power Query and applies the same rules as `vw_sales` (completed orders only, net revenue after discount).

- **Model:** star schema with `Sales` and `Stock` facts, `Products`, `Stores`, `Staff`, `Customers` and `Date` dimensions, and 16 DAX measures (for example `Net Revenue`, `% of Revenue`, `Units Sold Last 12M`, `Months of Stock`).
- **Pages:** Overview, Stores & Staff, Products, Inventory & Discounts.
- **Locale:** English (United States).

The data is stored inside the file, so it opens without any setup. To refresh it on another computer, set the `ProjectFolder` parameter (Transform data → Edit parameters) to the local path of the project folder.

---

## How to Reproduce

All CSV paths are relative to the **project root folder** (`Sales Drivers and Overstock Diagnosis Multi-Store Bike Retailer/`), so the project runs on any machine without editing file paths.

1. Create the database: `CREATE DATABASE bike_store;`
2. Connect to `bike_store` and run `process/01_sql/01_create_schema.sql`.
3. Load the data with psql. `\copy` is a psql command, so use a terminal or the pgAdmin **PSQL Tool**, not the Query Tool.

   From a terminal opened in the project root folder:

   ```bash
   psql -U postgres -d bike_store -f process/01_sql/02_import_data.sql
   ```

   Or in the pgAdmin PSQL Tool. Each new PSQL Tool session starts in the pgAdmin folder, so run `\cd` first every time:

   ```
   \cd 'C:/path/to/Sales Drivers and Overstock Diagnosis Multi-Store Bike Retailer'
   \i process/01_sql/02_import_data.sql
   ```

4. Run `03_exploration.sql` (optional, read-only profiling).
5. Run `04_cleaning.sql` to create the views `vw_sales` and `vw_stock`.
6. Run `05_analysis.sql`.
7. Open `02_excel/sales_drivers_overstock_report.xlsx` (no setup needed, the data is inside the workbook).
8. Run `03_python/analysis.ipynb` from the `03_python/` folder. It needs Python 3 with numpy, pandas, matplotlib and Jupyter, and reads the CSV files directly (no database needed).
9. Open `../deliverables/dashboard/sales_drivers_overstock_dashboard.pbix` in Power BI Desktop. To refresh it, first set the `ProjectFolder` parameter to the local path of the project folder.
