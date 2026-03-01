# MySQL Core Concepts, Interview, and Tricky Queries

---

## 1. Find the Second Highest Salary (No LIMIT)
```sql
SELECT MAX(salary) AS second_highest_salary
FROM employee
WHERE salary < (SELECT MAX(salary) FROM employee);
```

## 2. Find Duplicate Records
```sql
SELECT name, COUNT(*) AS name_count
FROM employee
GROUP BY name
HAVING name_count > 1;
```

## 3. Retrieve Records with No Matching Data (Left Join)
```sql
SELECT c.customer_id, c.name
FROM customer c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;
```

## 4. Find Nth Highest Salary (Generalized)
```sql
SELECT DISTINCT salary
FROM employee e1
WHERE (
    SELECT COUNT(DISTINCT salary)
    FROM employee e2
    WHERE e2.salary >= e1.salary
) = N;
```

## 5. Retrieve Customers with Their Last Order
```sql
SELECT c.customer_id, c.name, o.order_id, o.order_date
FROM customer c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_date = (
    SELECT MAX(order_date)
    FROM orders
    WHERE customer_id = c.customer_id
);
```
Great question! Let me explain the difference between JOIN (which is actually INNER JOIN) and LEFT JOIN.

JOIN (INNER JOIN)
JOIN is shorthand for INNER JOIN. It returns only the rows where there's a match in BOTH tables.

In your example:

SELECT c.customer_id, c.name, o.order_id, o.order_date
FROM customer c
JOIN orders o ON c.customer_id = o.customer_id
This returns only customers who HAVE orders. If a customer has no orders, they won't appear in the result.

LEFT JOIN (LEFT OUTER JOIN)
LEFT JOIN returns ALL rows from the left table (first table), and matching rows from the right table. If there's no match, it returns NULL for the right table's columns.

SELECT c.customer_id, c.name, o.order_id, o.order_date
FROM customer c
LEFT JOIN orders o ON c.customer_id = o.customer_id
This returns ALL customers, even those without orders. For customers without orders, order_id and order_date will be NULL.

Visual Example
Let's say you have:

customer table:

customer_id	name
1	Alice
2	Bob
3	Charlie
orders table:

order_id	customer_id	order_date
101	1	2024-01-15
102	1	2024-02-20
103	2	2024-01-10
INNER JOIN Result:
customer_id | name  | order_id | order_date
1          | Alice | 101      | 2024-01-15
1          | Alice | 102      | 2024-02-20
2          | Bob   | 103      | 2024-01-10
Charlie is NOT included because he has no orders.

LEFT JOIN Result:
customer_id | name    | order_id | order_date
1          | Alice   | 101      | 2024-01-15
1          | Alice   | 102      | 2024-02-20
2          | Bob     | 103      | 2024-01-10
3          | Charlie | NULL     | NULL
Charlie IS included with NULL values for order columns.

When to Use Which?
INNER JOIN: When you only want records that exist in both tables (e.g., "customers who have placed orders")
LEFT JOIN: When you want all records from the first table, regardless of matches (e.g., "all customers, including those who haven't ordered yet")
Your Original Query
In your query with the subquery:

WHERE o.order_date = (SELECT MAX(order_date)...)
Using INNER JOIN makes sense because you specifically want customers with their LAST order. If you used LEFT JOIN, you'd get customers without orders too, but the WHERE clause would filter them out anyway since NULL can't equal a date.



## 6. Self Join – Employees and Their Managers
```sql
SELECT e.name AS employee_name, m.name AS manager_name
FROM employee e
LEFT JOIN employee m ON e.manager_id = m.id;
```

## 7. FULL OUTER JOIN (Emulated with UNION)
```sql
SELECT e.name AS employee_name, m.name AS manager_name
FROM employee_manager e
LEFT JOIN employee m ON e.manager_id = m.id
UNION
SELECT e.name AS employee_name, m.name AS manager_name
FROM employee_manager e
RIGHT JOIN employee m ON e.manager_id = m.id
ORDER BY manager_name;
```

## 8. Find Gaps in Sequential Data
```sql
SELECT t1.invoice_no + 1 AS missing_invoice
FROM invoices t1
LEFT JOIN invoices t2 ON t1.invoice_no + 1 = t2.invoice_no
WHERE t2.invoice_no IS NULL;
```

## 9. Rank Employees by Salary within Each Department
```sql
SELECT name, department_id, salary,
RANK() OVER (PARTITION BY department_id ORDER BY salary DESC) AS salary_rank
FROM employee;
```

## 10. Optimize Queries with Indexes
```sql
CREATE INDEX idx_status_created ON orders(status, created_at);
```

---

# Notes
- These queries are commonly asked in MNC interviews for Java developers and MySQL administrators.
- They test subqueries, joins, window functions, indexing, and tricky SQL concepts.
- FULL OUTER JOIN is not natively supported in MySQL but can be emulated with UNION.
