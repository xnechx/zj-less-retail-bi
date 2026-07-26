-- ==============================================================================
-- PROJECT: ZJ LESS RETAIL SALES & INVENTORY ANALYTICS
-- COMPONENT: 02_assortment_opportunity_gap.sql
-- PLATFORM: Google BigQuery (Standard SQL)
-- DESCRIPTION: Actual production-grade query for identifying missing items.
--              Summarized from POS-level transaction logs to optimized summary
--              tables (sales_by_date_store and sales_by_time_range_date_store_item)
--              to reduce scan cost and increase query performance.
-- ==============================================================================

CREATE OR REPLACE TABLE `bi-project-test-101.Data_Mock_ZJ.missing_item_monthly` AS

WITH vars as (
  -- Define target date range for monthly run
  SELECT
      DATE "2025-01-01" AS from_date , 
      DATE "2025-01-31" AS to_date
),

std as (
  -- Calculate total network-wide operating days across all active stores (storeday denominator)
  -- Uses the pre-aggregated daily store summary table to optimize query cost
  SELECT COUNT(DISTINCT store_id || sales_date) as storeday 
  FROM `bi-project-test-101.Data_Mock_ZJ.sales_by_date_store` 
  CROSS JOIN vars
  WHERE sales_date BETWEEN from_date AND to_date
),

sales_by_item as (
  -- Calculate aggregate sales metrics (BPSD and UPSD) per item
  -- Joins the item-store-date pre-aggregated fact table
  SELECT 
        fact.item_code,
        category,
        SAFE_DIVIDE(SUM(sales_amount), AVG(storeday)) as BPSD,
        SAFE_DIVIDE(SUM(sales_quantity), AVG(storeday)) as UPSD
  FROM `bi-project-test-101.Data_Mock_ZJ.sales_by_time_range_date_store_item` as fact
  CROSS JOIN vars
  CROSS JOIN std
  LEFT JOIN `bi-project-test-101.Data_Mock_ZJ.item_detail` as item_detail
        ON fact.item_code = item_detail.item_code
  WHERE sales_date BETWEEN from_date AND to_date 
  GROUP BY 1,2
),

ranked_sales as (
  -- Rank items within each category to find best-sellers
  SELECT 
        RANK() OVER(PARTITION BY category ORDER BY BPSD, UPSD DESC) as rank,
        item_code,
        category,
        BPSD,
        UPSD
  FROM sales_by_item
),

active_store as (
  -- Identify active store branches within the current month window
  SELECT DISTINCT store_id
  FROM `bi-project-test-101.Data_Mock_ZJ.sales_by_date_store`
  CROSS JOIN vars
  WHERE sales_date BETWEEN from_date AND to_date
),

missing_item_top10 as (
  -- Filter Top 10 Best Sellers per Category
  SELECT 
        rank,
        item_code,
        category,
        BPSD
  FROM ranked_sales
  WHERE rank <= 10
),

sales_by_store_item_missing as (
  -- Fetch actual store sales for top-selling items to check gaps
  SELECT 
        fact.store_id,
        fact.item_code,
        SUM(sales_amount) as sales_amount
  FROM `bi-project-test-101.Data_Mock_ZJ.sales_by_time_range_date_store_item` as fact
  CROSS JOIN vars
  JOIN active_store ON fact.store_id = active_store.store_id
  JOIN missing_item_top10 ON fact.item_code = missing_item_top10.item_code
  WHERE sales_date BETWEEN from_date AND to_date
  GROUP BY 1,2
),

order_stock as (
  -- Join inventory snapshot (stock on shelf & orders in transit)
  SELECT 
        fact.store_id, 
        fact.item_code,
        SUM(order_quantity) as order_quantity,
        MAX(stock_quantity) as stock_quantity
  FROM `bi-project-test-101.Data_Mock_ZJ.fact_inventory` fact
  CROSS JOIN vars
  WHERE sales_date BETWEEN from_date AND to_date
  GROUP BY 1,2
)

-- Generate final output table mapping every active store to the Top 10 Category Best-Sellers
-- Flagging items as "missing" if there were 0 sales, 0 inventory, and 0 orders in transit
SELECT
      from_date,
      to_date,
      active_store.store_id,
      category,
      rank,
      missing_item_top10.item_code,
      BPSD,
      sales_amount,
      order_quantity,
      stock_quantity,
      CASE WHEN sales_amount > 0
                OR order_quantity > 0
                OR stock_quantity > 0
            THEN null
            ELSE "missing"
      END as missing_item
FROM active_store
CROSS JOIN missing_item_top10
CROSS JOIN vars
LEFT JOIN sales_by_store_item_missing ON active_store.store_id = sales_by_store_item_missing.store_id 
                                        AND missing_item_top10.item_code = sales_by_store_item_missing.item_code
LEFT JOIN order_stock ON active_store.store_id = order_stock.store_id 
                        AND missing_item_top10.item_code = order_stock.item_code
ORDER BY 1,2,3;
