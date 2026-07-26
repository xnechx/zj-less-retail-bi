-- ==============================================================================
-- PROJECT: ZJ LESS RETAIL SALES & INVENTORY ANALYTICS
-- COMPONENT: 01_bigquery_star_schema_ddl.sql
-- PLATFORM: Google BigQuery (Standard SQL)
-- DESCRIPTION: Data Definition Language (DDL) matching the ACTUAL production database schema.
--              Includes raw dimensions, master fact table (fact_sales), and optimized 
--              summary tables aggregated from fact_sales to improve BI performance.
-- ==============================================================================

CREATE SCHEMA IF NOT EXISTS `zj_less_retail_bi`
OPTIONS(
  location = 'asia-southeast1',
  description = 'Data warehouse for 12 retail stores sales and inventory analytics'
);

-- ------------------------------------------------------------------------------
-- 1. DIMENSION TABLE: store_detail
-- Contains store metadata and historical open/close dates.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `zj_less_retail_bi.store_detail` (
    store_id STRING NOT NULL OPTIONS(description="Unique store branch ID"),
    storename STRING NOT NULL OPTIONS(description="Full branch display name"),
    zone STRING NOT NULL OPTIONS(description="Geographical zone: East, South, West, BKK, Isan"),
    profile STRING NOT NULL OPTIONS(description="Store customer profile: Tourist, Office, Residential"),
    subprofile STRING OPTIONS(description="Detailed store subprofile classification"),
    openstoredate DATE NOT NULL OPTIONS(description="Date the store officially opened"),
    closestoredate DATE OPTIONS(description="Date the store closed (NULL if still active)")
)
CLUSTER BY zone, profile
OPTIONS(
    description="Dimension table containing retail store profiles and operating lifespans."
);

-- ------------------------------------------------------------------------------
-- 2. DIMENSION TABLE: item_detail
-- Contains product hierarchy and cost/pricing attributes.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `zj_less_retail_bi.item_detail` (
    item_code STRING NOT NULL OPTIONS(description="Unique SKU item code"),
    item_name STRING NOT NULL OPTIONS(description="Item description name"),
    group_item STRING NOT NULL OPTIONS(description="Tier 1 Hierarchy: Non-Food, Processed Food, etc."),
    category_code STRING OPTIONS(description="Category code"),
    category STRING NOT NULL OPTIONS(description="Tier 2 Hierarchy: Hardware, Beverage, Snack, etc."),
    sub_category_code STRING OPTIONS(description="Sub-category code"),
    sub_category STRING OPTIONS(description="Tier 3 Hierarchy: Measuring Tape, Extension Cord, etc."),
    unit_price FLOAT64 OPTIONS(description="Retail sales price in Baht"),
    unit_cost FLOAT64 OPTIONS(description="Acquisition cost in Baht"),
    on_shelf_date DATE OPTIONS(description="Date SKU was introduced to shelves"),
    off_shelf_date DATE OPTIONS(description="Date SKU was discontinued")
)
CLUSTER BY group_item, category
OPTIONS(
    description="Dimension table for product classification and item attributes."
);

-- ------------------------------------------------------------------------------
-- 3. MASTER FACT TABLE: fact_sales (Raw POS Transactions)
-- Base fact table recording every transaction ticket line item.
-- Partitioned by sales_date for optimal scan performance.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `zj_less_retail_bi.fact_sales` (
    ticket_id STRING NOT NULL OPTIONS(description="Unique POS receipt transaction ID"),
    time_range STRING OPTIONS(description="POS transaction time block classification"),
    sales_date DATE NOT NULL OPTIONS(description="POS transaction date (Partition Key)"),
    store_id STRING NOT NULL OPTIONS(description="Foreign Key linking to store_detail"),
    item_code STRING NOT NULL OPTIONS(description="Foreign Key linking to item_detail"),
    payment STRING OPTIONS(description="Payment method used (e.g. Cash, Credit Card, QR)"),
    sales_quantity INT64 NOT NULL OPTIONS(description="Number of physical units sold"),
    sales_amount FLOAT64 NOT NULL OPTIONS(description="Total sales revenue in Baht"),
    profit FLOAT64 NOT NULL OPTIONS(description="Calculated profit in Baht (sales_amount - (sales_quantity * unit_cost))")
)
PARTITION BY sales_date
CLUSTER BY store_id, item_code
OPTIONS(
    description="Master POS daily sales transaction fact table containing raw transaction-level data.",
    require_partition_filter = TRUE
);

-- ------------------------------------------------------------------------------
-- 4. OPTIMIZED SUMMARY FACT TABLE: sales_by_date_store
-- Created from: fact_sales
-- Purpose: Pre-aggregated daily store-level sales summary table to optimize query cost.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `zj_less_retail_bi.sales_by_date_store` (
    sales_date DATE NOT NULL OPTIONS(description="Transaction date (Partition Key)"),
    store_id STRING NOT NULL OPTIONS(description="Foreign Key linking to store_detail"),
    total_sales_amount FLOAT64 NOT NULL OPTIONS(description="Total sales amount accumulated in store on this day"),
    total_transaction_count INT64 NOT NULL OPTIONS(description="Total receipts processed in store on this day")
)
PARTITION BY sales_date
CLUSTER BY store_id
OPTIONS(
    description="Summary table aggregated from fact_sales to optimize storeday counting and reporting performance."
);

-- ------------------------------------------------------------------------------
-- 5. OPTIMIZED SUMMARY FACT TABLE: sales_by_time_range_date_store_item
-- Created from: fact_sales
-- Purpose: Pre-aggregated daily item-store-time sales summary table.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `zj_less_retail_bi.sales_by_time_range_date_store_item` (
    sales_date DATE NOT NULL OPTIONS(description="Transaction date (Partition Key)"),
    store_id STRING NOT NULL OPTIONS(description="Foreign Key linking to store_detail"),
    item_code STRING NOT NULL OPTIONS(description="Foreign Key linking to item_detail"),
    time_range STRING OPTIONS(description="POS transaction time block (e.g. morning, afternoon)"),
    sales_quantity INT64 NOT NULL OPTIONS(description="Physical units sold"),
    sales_amount FLOAT64 NOT NULL OPTIONS(description="Sales revenue generated in Baht"),
    profit FLOAT64 NOT NULL OPTIONS(description="Gross profit calculated (sales_amount - costs)")
)
PARTITION BY sales_date
CLUSTER BY store_id, item_code
OPTIONS(
    description="Summary table aggregated from fact_sales to optimize item-level sales queries."
);

-- ------------------------------------------------------------------------------
-- 6. FACT TABLE: fact_inventory
-- Monthly snapshot logging stock availability and pending purchase orders.
-- ------------------------------------------------------------------------------
CREATE OR REPLACE TABLE `zj_less_retail_bi.fact_inventory` (
    sales_date DATE NOT NULL OPTIONS(description="Snapshot date (Partition Key)"),
    store_id STRING NOT NULL OPTIONS(description="Foreign Key linking to store_detail"),
    item_code STRING NOT NULL OPTIONS(description="Foreign Key linking to item_detail"),
    order_quantity INT64 DEFAULT 0 OPTIONS(description="Pending orders currently en route to store"),
    stock_quantity INT64 DEFAULT 0 OPTIONS(description="Physical inventory counted at store end-of-month")
)
PARTITION BY sales_date
CLUSTER BY store_id, item_code
OPTIONS(
    description="Inventory fact table logging stock quantities and in-transit orders."
);
