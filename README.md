## Business Context
Olist shows strong historical growth but clear signs of maturity and operational friction:
- Growth accelerated sharply in 2017, then slowed in 2018.
- Customer behavior is heavily one-time purchase driven.
- Delivery delays materially impact customer satisfaction.
- Revenue is concentrated in key states, with expansion opportunities in underpenetrated regions.

This repository is structured to answer those challenges with reproducible data models, analytical queries, and executive-facing visuals.

---

## Project Objectives
1. Build a clean and scalable analytics foundation from raw CSVs.
2. Track marketplace health across revenue, fulfillment, geography, and customer behavior.
3. Validate core business hypotheses through SQL analysis.
4. Segment customers using RFM to prioritize retention.
5. Simulate and evaluate a second-purchase incentive using A/B testing logic.
6. Deliver interactive dashboard views for business stakeholders.

---

## Data Architecture (Medallion)

### 1) Bronze Layer (`olist_bronze`)
Raw ingestion layer with minimal assumptions:
- Loads source CSVs as-is.
- Preserves source grain and nullable fields.
- Adds audit timestamps (`_loaded_at`).

### 2) Silver Layer (`olist_silver`)
Cleansed and standardized layer:
- Type casting for IDs, numerics, and datetimes.
- Text cleanup (`TRIM`, case normalization).
- Category translation (Portuguese → English).
- Deduplication logic (notably in reviews and geolocation).
- Data quality filtering of null critical keys.

### 3) Gold Layer (`olist_gold`)
Analytics-ready star schema:
- `fact_orders` at **order grain**.
- Dimensions: `dim_customers`, `dim_products`, `dim_sellers`, `dim_date`.
- Delivery and revenue metrics precomputed for BI use.
- Primary key constraints added for model reliability.

---

## Key Analytical Tracks

### 1) Strategic SQL Analysis
The SQL analysis script tests business hypotheses around:
- Growth trajectory and monthly revenue trends.
- Geographic concentration and whitespace markets.
- Category revenue contribution.
- Delivery delay impact on review outcomes.
- One-time vs repeat customer value.
- State-wise logistics performance.
- Weekday vs weekend purchasing patterns.

### 2) RFM Customer Segmentation (Python)
RFM scoring is used to classify customers by:
- **Recency** (how recently they purchased)
- **Frequency** (how often they purchase)
- **Monetary** (how much they spend)

The segmentation supports action-oriented lifecycle strategies (retention, reactivation, loyalty).

### 3) A/B Testing Simulation (Python)
A controlled simulation evaluates a **10% off second purchase coupon** for eligible first-time buyers:
- Randomized control/treatment split.
- Two-proportion z-test for repeat purchase rate.
- Lift interpretation for growth experimentation planning.

---

## Dashboard Focus Areas
The Power BI dashboard is designed for decision-making across:
- Revenue and order trends over time.
- Delivery performance and delay diagnostics.
- Customer behavior and repeat-rate indicators.
- Segment-level contribution (RFM framing).
- Geographic and category performance views.

Special attention was given to model consistency, filter behavior, and metric integrity while resolving common BI bottlenecks (filter propagation, denominator mismatches, over-filtering, and visual clarity).

---


## Repository Structure
```text
OLIST-Marketplace-Analysis/
├── README.md
├── dashboard/
│   └── OLIST_customer_analysis.pbix
├── python/
│   ├── AB testing.ipynb
│   ├── rfm_customer_segmentation.ipynb
│   └── review cleaning.py
└── sql/
    ├── bronze layer/
    │   ├── 01_bronze_schema.sql
    │   └── 01_bronze_validation.sql
    ├── silver layer/
    │   ├── 02_silver_schema.sql
    │   └── 02_silver_validation.sql
    ├── gold layer/
    │   ├── 03_gold_fact_orders.sql
    │   ├── 03_gold_dim_customers.sql
    │   ├── 03_gold_dim_products.sql
    │   ├── 03_gold_dim_sellers.sql
    │   ├── 03_gold_dim_date.sql
    │   ├── 03_gold_add_constraints.sql
    │   └── 03_gold_validation.sql
    └── analysis/
        └── 04_analytical_queries.sql
```

---

## How to Run

### Prerequisites
- MySQL 8+
- Python 3.9+
- Jupyter Notebook / JupyterLab
- Power BI Desktop

### SQL Pipeline Execution Order
Run scripts in this sequence:
1. `sql/bronze layer/01_bronze_schema.sql`
2. `sql/bronze layer/01_bronze_validation.sql`
3. `sql/silver layer/02_silver_schema.sql`
4. `sql/silver layer/02_silver_validation.sql`
5. Gold layer scripts (`03_gold_*.sql`)
6. `sql/analysis/04_analytical_queries.sql`

### Python Analysis
Run notebooks from the `python/` folder:
- `rfm_customer_segmentation.ipynb`
- `AB testing.ipynb`

Optional preprocessing utility:
- `review cleaning.py` (cleans multiline review comments from order_items before loading into bronze layer for proper pr).

### Dashboard
Open and refresh:
- `dashboard/OLIST_customer_analysis.pbix`

---

## Core Insights Captured by This Project
- Marketplace growth has matured; scale now requires deliberate strategic levers.
- Delivery performance is a major driver of customer sentiment and repeat potential.
- Retention is the biggest monetization gap; repeat buyers provide outsized value.
- Category mix is diversified, but top categories still offer focused growth potential.
- Geographic concentration highlights clear expansion opportunities beyond core states.

---

## Learning Outcomes
This project demonstrates hands-on capabilities in:
- Data warehousing and medallion modeling in SQL.
- Data quality auditing and transformation governance.
- Customer lifecycle analytics (RFM).
- Experiment design and statistical evaluation for growth decisions.
- Power BI modeling, DAX debugging, and executive storytelling.

---

## Future Enhancements
- Add item-level gold fact modeling for deeper seller/category diagnostics.
- Integrate cohort retention and LTV decomposition.
- Operationalize experiment tracking on real campaign data.
- Extend dashboard with alerting thresholds for delivery and retention KPIs.

## Dataset Used

Brazilian E-Commerce Public Dataset by Olist, available on Kaggle  
[🔗 Dataset Link](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)



