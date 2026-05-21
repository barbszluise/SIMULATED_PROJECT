# 🏡 Real Estate SQL Project

## 📌 Overview

This project simulates a real estate management system using SQL.

The database stores:
- clients
- properties
- sales transactions

The goal of the project is to practice:
- SQL queries
- joins
- aggregations
- data relationships
- dashboard visualization

---

## 🛠 Technologies Used

- SQL
- SQLite
- DBeaver
- Tableau
- GitHub

---

## 🧩 Database Structure

### Tables

#### Clients
Stores customer information.

#### Properties
Stores property details.

#### Selling
Stores sales transactions connecting clients and properties.

---

## 🔑 Relationships

```sql
selling.client_id → clients.client_id

selling.property_id → properties.id
```

---

## 📊 Example SQL Queries

### Top clients by total spending

```sql
SELECT clients.name,
SUM(selling.price) AS total_spent
FROM selling
JOIN clients
ON selling.client_id = clients.client_id
GROUP BY clients.name
ORDER BY total_spent DESC;
```

---

### Properties by city

```sql
SELECT city,
COUNT(*) AS total_properties
FROM properties
GROUP BY city;
```

---

## 📈 Dashboard

The project was connected to Tableau to create visualizations such as:
- top clients
- sales by city
- property status
- total sales

---

## 📂 Files Included

- database.sql
- clients.csv
- properties.csv
- selling.csv

---

## 🚀 What I Learned

During this project I practiced:
- database modeling
- SQL relationships
- primary and foreign keys
- joins and aggregations
- dashboard integration
- troubleshooting data connections

---

## 👩‍💻 Author

Barbara Rodovalho
