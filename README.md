

# 📦 Olist Marketplace Data Analysis & Insights

## 🚀 Project Overview

This project analyzes the **Olist Brazilian eCommerce dataset** to identify delivery bottlenecks, evaluate customer value, and run A/B testing experiments. The goal is to support Olist in improving **conversion rates, delivery reliability, and customer retention** through data-driven insights and Power BI dashboards.

---

## 🧠 Problem Statement

Olist, a Brazilian e-commerce marketplace, has received concerns from sellers regarding **delayed deliveries** and **declining customer conversion rates**. The company aims to:

- Identify **friction points** in the purchase-to-delivery pipeline
- Assess the **impact of payment methods** on customer spending
- Segment customers based on value for **targeted loyalty strategies**

---

## 📊 Tasks & Business Objectives

### 🧪 Task 1: A/B Testing — Payment Method vs Order Value

**Objective:**  
Determine whether customers using **Credit Cards (Group A)** spend more than those using **Boleto/Voucher (Group B)**.

- **Metric Used:** Average payment value
- **Test Used:** Independent T-Test
- **Insight:** Statistically significant difference found — credit card users spend more, indicating better targeting potential for upsell.

---

### 🚚 Task 2: Delivery Bottleneck Analysis + Top Performers

**Objective:**  
Find bottlenecks in the order-to-delivery pipeline and highlight **top-performing sellers** and **product categories**.

**Key Metrics:**
- 📦 **Avg. Delivery Duration**
- ⏱ **Approval to Shipment Lag**
- ❌ **Delayed Delivery Rate**
- 💰 **Revenue per Seller**
- 🔁 **Return Rate** based on review scores

**Deliverable:**  
Interactive Power BI dashboard with KPIs, drill-down filters, and geographic breakdowns.

---

### 👥 Task 3: Customer Segmentation & Value Analysis

**Objective:**  
Identify the most valuable customers using **Total Spend**, **Order Frequency**, and **Recency**.

#### 🔍 Metrics:
- **Total Spend = Price + Freight**
- **Order Frequency = # of Orders per Customer**
- **Recency = Days since last purchase**

#### 🧮 Method:
- Applied **RFM Scoring** (Recency, Frequency, Monetary) using quantiles
- Classified customers into groups:
  - 🏆 **Top Customers**
  - 💚 **Loyal Customers**
  - 🆕 **Recent Buyers**
  - 🔁 **Frequent Buyers**
  - ⚠️ **At Risk**

**Deliverable:**  
Visualized RFM segments and generated business recommendations for **retention and loyalty programs**.

---

## 📁 Dataset Used

Brazilian E-Commerce Public Dataset by Olist, available on Kaggle  
[🔗 Dataset Link](https://www.kaggle.com/datasets/olistbr/brazilian-ecommerce)

---

## 🛠 Tools & Technologies

- **Python** (Pandas, NumPy, SciPy, Matplotlib, Seaborn)
- **Power BI** (KPI Cards, Bar Charts, Maps, Scorecards)
- **A/B Testing** (T-tests, Chi-Square)
- **Customer Segmentation** (RFM Analysis)
- **SQL** (Exploration & joins - optional preprocessing)

---

## 📌 Key Business Insights

- 💳 **Credit Card users spend ~20% more** on average than Boleto/Voucher users.
- ⏳ **Delivery delays and shipping lag** vary significantly by seller and product category.
- 🧲 **Big Spenders & Loyal Customers** account for the majority of revenue — critical segment for loyalty efforts.
- ⚠️ **At-Risk customers** form a sizable chunk, representing a retention opportunity.

---

## 📈 Visual Highlights

- 📌 Power BI dashboard includes:
  - Delivery metrics across seller, state, and category
  - Top performing sellers and high-return categories
  - Dynamic filters for segmenting customer insights
  - Clean KPI cards for executive-level reporting

-
