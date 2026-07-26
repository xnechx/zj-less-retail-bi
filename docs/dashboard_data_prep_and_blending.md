# 📊 Looker Studio Dashboard Data Preparation & Data Blending Logic

This document details the data preparation pipeline and the advanced **Data Blending** configuration used within Looker Studio to calculate normalized retail averages (like BPSD) dynamically and mathematically correctly.

---

## ⚙️ Step 1: Data Preparation & Integration (BigQuery to Looker Studio)

Rather than connecting Looker Studio directly to millions of raw, transaction-level POS receipts (which would result in high query costs and slow dashboard load times), we prepare optimized, pre-aggregated summary tables in **Google BigQuery**.

Looker Studio connects directly to BigQuery using the native **Google BigQuery Connector**, pulling from these two key tables:
1. **`sales_by_time_range_date_store_item` (Sales Table)**: Logs daily revenue and quantity sold per item per store.
2. **`sales_by_date_store` (Store Daily Sales Summary Table)**: Logs daily store-level sales (if the store has sales it means the store was open on that date).

---

## ⚠️ The BI Challenge: The "Double-Counting / Filter Distortion" Problem

Calculating averages like **BPSD (Baht Per Store Per Day)** directly in a single data source causes mathematical errors when users apply filters in Looker Studio.

### The Problem Scenario:
* **Formula:** $\text{BPSD} = \frac{\text{Sum of Sales}}{\text{Sum of Operating Days}}$
* If a store was open for **30 days** in January, the denominator is 30.
* If a user filters the dashboard to show only **"Premium Green Tea"** (สินค้าชาเขียวพรีเมี่ยม):
  * **Incorrect Native Calculation:** In reality, every store in the network has the opportunity to sell this product, but some stores might end up with zero sales. If we calculate BPSD directly using only the item sales table (`sales_by_time_range_date_store_item`), Looker Studio will filter out the records for stores that had zero sales. Consequently, the average denominator (storeday) will shrink to only count the days of the stores that *successfully sold the tea*.
  * **Why this is wrong:** The denominator should reflect the operating days of *all* open stores in the network, because they were active and had the potential to sell the item. Shrinking the denominator to only active sellers artificially inflates the average BPSD of the product.
  * Filtering by product/SKU should **never** shrink the store network's actual open operating days denominator.

---

## 🛠️ The Solution: Data Blending in Looker Studio

To solve this and achieve a fully dynamic and mathematically correct calculation, we therefore use **Data Blending** to combine the sales numerator and the operating days denominator as separate, independent tables.

### 📋 Blending Configuration Blueprint

```
[ Data Source A: Sales Numerator ]            [ Data Source B: Denominator ]
(sales_by_time_range_date_store_item)         (sales_by_date_store)
       │                                             │
       ├── Dimensions:                               ├── Dimensions:
       │   - item_code (Filterable)                  │   (None / Aggregated Globally)
       │   - category (Filterable)                   │
       │                                             │
       └── Metrics:                                  └── Metrics:
           - sales_amount (SUM)                          - storeday (COUNT DISTINCT store_id||sales_date)
```

### 1. Data Source A (Table: `sales_by_time_range_date_store_item`)
* **Filter Dimensions:** `item_code`, `category`, `time_range`
* **Metrics:** `sales_amount` (Aggregated as `SUM`)

### 2. Data Source B (Table: `sales_by_date_store` - ตารางยอดขายร้านรายวัน ถ้าร้านมียอดขายเท่ากับว่าเปิดร้าน)
* **Metrics:** `storeday` (Aggregated as `COUNT DISTINCT` of `store_id || sales_date`)
  * *Note: Since this table only contains one record per store per active day (if the store has sales it means the store was open), its day count is independent of any item-level filters.*

---

## 📐 Calculated Fields in the Blended Data Source

Once the sources are blended, we create custom calculated fields in Looker Studio to compute the metrics dynamically.

> [!IMPORTANT]
> **Why we use `MAX(storeday)` instead of `SUM(storeday)`:**
> Since Data Source A contains multiple item-level transaction rows that join with the daily store summary records in Data Source B, Looker Studio duplicates the `storeday` value for every matching transaction. If we were to use `SUM(storeday)`, it would sum these duplicate values, resulting in an inflated denominator. Using **`MAX(storeday)`** (or `AVG(storeday)`) extracts the true, unique number of operating days.

### 1. Baht Per Store Per Day (BPSD)
```sql
SUM(sales_amount) / MAX(storeday)
```
* **Why this works correctly:** If a user filters the dashboard by "Premium Green Tea", Source A filters the sales amount to only those transactions, but `MAX(storeday)` from Source B still returns the correct, unique sum of operating days of all open stores in the network.

### 2. Units Per Store Per Day (UPSD)
```sql
SUM(sales_quantity) / MAX(storeday)
```

### 3. Gross Profit Per Store Per Day (GPPSD)
```sql
SUM(profit) / MAX(storeday)
```

---

## 📈 Summary of Benefits
* **100% Mathematical Accuracy**: Eliminates denominator distortion when filtering by product hierarchies, SKU codes, or time blocks.
* **Dynamic Flexibility**: Users can filter by any date range, store profile, or zone, and the operating days denominator recalculates on the fly.
* **Cloud Cost Efficiency**: Offloads heavy processing to BigQuery pre-aggregates, keeping Looker Studio snappy and responsive.

---

## ⚡ BigQuery Performance Best Practice: Table Partitioning

When designing tables in Google BigQuery to connect to Looker Studio:

> [!IMPORTANT]
> **Apply Table Partitioning on Date Fields across ALL tables.**
> If a table containing a `DATE` field is not partitioned (using `PARTITION BY sales_date`), Looker Studio refreshes will trigger a **Full Table Scan** on BigQuery every single time, even if users apply a date range filter on the dashboard. Partitioning restricts the query scope to specific partitions (Partition Pruning), significantly reducing data scan costs and boosting dashboard performance.

---

## ⚠️ Dashboard Limitations & Performance Warnings (ข้อควรระวังในการใช้งาน)

When analyzing transaction-based metrics:

> [!WARNING]
> **Ticket-Count Metrics (TCPSD, TA, UT) can only be filtered by Store-level dimensions.**
> * **The Business Logic:** Evaluating transaction count and basket sizes at the store level (Zone, Profile, Branch) is already sufficient for high-level retail operational analysis.
> * **The Tech Constraint (Cost-Performance Trade-off):** To make ticket counts (TC) dynamically filterable by item-level dimensions (e.g. item code, item category), Looker Studio would need to import and scan the raw transaction table containing `ticket_id` (millions of rows) to perform a real-time `COUNT(DISTINCT ticket_id)`. This process is extremely data-heavy, causes severe dashboard lag, and is not cost-effective. Thus, transaction metrics are strictly bound to store-level pre-aggregates.
