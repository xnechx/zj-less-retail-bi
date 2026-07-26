# 📗 Retail Performance KPI Dictionary & Formulation Logic

This document outlines the standardized analytical formulation methodologies implemented across the **ZJ LESS Business Intelligence Data Warehouse**. To ensure fair performance evaluation across 12 retail branches with varying operational scales, all core metrics are normalized using operating-day denominators rather than fixed 30-day calendar multipliers.

---

## 🏛️ Normalized Retail Performance Methodology

In multi-branch retail operations, stores experience temporary closures, renovations, or differing grand opening dates. Dividing cumulative sales by a static 30-day or 365-day calendar distorts branch efficiency. 

> [!IMPORTANT]
> **Core Formulation Standard**: In the ZJ LESS data model, denominators representing time ranges strictly utilize store operating days. **Time multipliers cannot be directly multiplied or simplified without accounting for branch-level operational status.** The operating days for each store are dynamically calculated using the difference between its open date (`openstoredate`) and close date (`closestoredate`) relative to the target analysis period.

---

## 📐 Core KPI Formula Reference

| Metric Acronym | Full Name | Standard English Definition | Exact Formulation Logic | Business Rationale |
| :--- | :--- | :--- | :--- | :--- |
| **BPSD** | **Baht Per Store Per Day** | Average Sales Revenue per Store per Operating Day | `Total Sales Revenue (Baht) / Total Store Operating Days` | Measures true operational sales efficiency and floor productivity across branches. |
| **UPSD** | **Units Per Store Per Day** | Average Physical Volume Sold per Store per Day | `Total Physical Units Sold (PCS) / Total Store Operating Days` | Evaluates physical supply chain velocity and shelf replenishment speed. |
| **TCPSD** | **Transactions Per Store Per Day** | Average Customer Traffic Count per Store per Day | `Total POS Receipts (Transactions) / Total Store Operating Days` | Tracks customer footfall conversion and cash register throughput efficiency. |
| **GPPSD** | **Gross Profit Per Store Per Day** | Average Gross Margin Dollar Generated per Store per Day | `Total Gross Profit (Baht) / Total Store Operating Days` | Evaluates net profitability after product cost deduction per active operating day. |
| **TA** | **Ticket Average (Basket Size)** | Average Baht Spending per Single Customer Receipt | `Total Sales Revenue (Baht) / Total Transactions` *(or `BPSD / TCPSD`)* | Analyzes purchasing power and effectiveness of cashier up-selling tactics. |
| **UT** | **Units Per Transaction** | Average Physical Items Purchased per Customer Receipt | `Total Physical Units Sold / Total Transactions` *(or `UPSD / TCPSD`)* | Measures basket depth and multi-pack promotional effectiveness. |
| **%GP** | **Gross Profit Margin %** | Proportion of Gross Profit Relative to Total Revenue | `(Total Gross Profit / Total Sales Revenue) × 100` | Monitors pricing strategy health and category margin mix optimization. |


