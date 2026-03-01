# MySQL Intermediate SQL Queries

---

## 1. Use subqueries
```sql
SELECT * FROM employee
WHERE salary > (SELECT AVG(salary) FROM employee);
```

## 2. Use HAVING with GROUP BY

**Tables:**
```sql
-- employee table
CREATE TABLE employee (
    employee_id INT PRIMARY KEY,
    name VARCHAR(100),
    department_id INT,
    salary DECIMAL(10,2),
    join_date DATE
);

-- department table
CREATE TABLE department (
    department_id INT PRIMARY KEY,
    department_name VARCHAR(100),
    location VARCHAR(100)
);

-- Sample data
INSERT INTO employee VALUES
(1, 'Alice', 1, 60000, '2020-01-15'),
(2, 'Bob', 1, 65000, '2019-03-20'),
(3, 'Charlie', 2, 70000, '2021-06-10'),
(4, 'David', 1, 62000, '2020-11-05'),
(5, 'Eve', 3, 75000, '2018-07-22'),
(6, 'Frank', 1, 68000, '2022-02-14'),
(7, 'Grace', 2, 72000, '2021-09-30'),
(8, 'Henry', 1, 64000, '2020-05-18'),
(9, 'Ivy', 1, 66000, '2019-12-01'),
(10, 'Jack', 2, 71000, '2021-03-25');

INSERT INTO department VALUES
(1, 'Engineering', 'New York'),
(2, 'Marketing', 'San Francisco'),
(3, 'HR', 'Chicago');
```

**Query:**
```sql
SELECT department_id, COUNT(*) AS employee_count
FROM employee
GROUP BY department_id
HAVING employee_count > 5;
```

**Result:**
```
department_id | employee_count
1            | 6
```

**Explanation:** 
- `GROUP BY` groups employees by department
- `HAVING` filters groups after aggregation (only departments with more than 5 employees)
- Department 1 (Engineering) has 6 employees, so it appears in the result





***new***
No, you cannot select employee_id in this query as written. Here's why:

The Rule: SELECT and GROUP BY
When you use GROUP BY, you can only SELECT:

Columns that are in the GROUP BY clause
Aggregate functions (COUNT, SUM, AVG, MAX, MIN, etc.)
Why It Doesn't Work
-- ❌ This will give an ERROR
SELECT employee_id, department_id, COUNT(*) AS employee_count
FROM employee
GROUP BY department_id
HAVING employee_count > 5;
Error: employee_id is not in the GROUP BY clause and it's not an aggregate function.

When you group by department_id, multiple employees are collapsed into one row per department. Which employee_id should MySQL show? Employee 1, 2, 3, 4, 5, or 6 from that department? It's ambiguous!

What You CAN Do
Option 1: Add employee_id to GROUP BY (but this defeats the purpose)
SELECT employee_id, department_id, COUNT(*) AS employee_count
FROM employee
GROUP BY department_id, employee_id
HAVING employee_count > 5;
This won't work as intended because now you're grouping by both, so each row represents one employee.

Option 2: Use GROUP_CONCAT to see all employee IDs
SELECT 
    department_id, 
    COUNT(*) AS employee_count,
    GROUP_CONCAT(employee_id) AS employee_ids
FROM employee
GROUP BY department_id
HAVING employee_count > 5;
Result:

department_id | employee_count | employee_ids
1            | 6              | 1,2,4,6,8,9
Option 3: Use a subquery to get individual employees
SELECT e.employee_id, e.name, e.department_id
FROM employee e
WHERE e.department_id IN (
    SELECT department_id
    FROM employee
    GROUP BY department_id
    HAVING COUNT(*) > 5
);
Result:

employee_id | name   | department_id
1          | Alice  | 1
2          | Bob    | 1
4          | David  | 1
6          | Frank  | 1
8          | Henry  | 1
9          | Ivy    | 1
This shows all individual employees from departments that have more than 5 employees.

Summary
No, you can't directly select employee_id with GROUP BY department_id
Use GROUP_CONCAT to see all IDs in one row
Use a subquery if you want individual employee rows from qualifying departments


**Here are SQL queries to get orders by customer that happened today or today up to 1 PM:**
   | 2           | 505,506     | 280.00
Query 2: Orders by Customer - Today Up to 1 PM
SELECT 
    customer_id,
    COUNT(*) AS order_count,
    GROUP_CONCAT(order_id) AS order_ids,
    SUM(total_amount) AS total_spent
FROM orders
WHERE DATE(order_date) = CURDATE()
  AND TIME(order_date) <= '13:00:00'
GROUP BY customer_id;
Alternative using HOUR:

SELECT 
    customer_id,
    COUNT(*) AS order_count,
    GROUP_CONCAT(order_id) AS order_ids,
    SUM(total_amount) AS total_spent
FROM orders
WHERE DATE(order_date) = CURDATE()
  AND HOUR(order_date) < 13
GROUP BY customer_id;
Query 3: With Customer Details (Using JOIN)
SELECT 
    c.customer_id,
    c.customer_name,
    COUNT(o.order_id) AS order_count,
    GROUP_CONCAT(o.order_id) AS order_ids,
    GROUP_CONCAT(TIME(o.order_date)) AS order_times,
    SUM(o.total_amount) AS total_spent
FROM customer c
LEFT JOIN orders o ON c.customer_id = o.customer_id
    AND DATE(o.order_date) = CURDATE()
    AND TIME(o.order_date) <= '13:00:00'
GROUP BY c.customer_id, c.customer_name
HAVING order_count > 0;
Result:

customer_id | customer_name | order_count | order_ids | order_times        | total_spent
101        | John Doe      | 2           | 501,502   | 09:30:00,12:45:00 | 350.00
103        | Jane Smith    | 1           | 505       | 10:15:00          | 180.00
Query 4: Orders Between Specific Time Range (e.g., 9 AM to 1 PM)
SELECT 
    customer_id,
    COUNT(*) AS order_count,
    GROUP_CONCAT(order_id ORDER BY order_date) AS order_ids,
    MIN(order_date) AS first_order_time,
    MAX(order_date) AS last_order_time
FROM orders
WHERE DATE(order_date) = CURDATE()
  AND TIME(order_date) BETWEEN '09:00:00' AND '13:00:00'
GROUP BY customer_id
ORDER BY order_count DESC;
Sample Table Schema
CREATE TABLE orders (
    order_id INT PRIMARY KEY,
    customer_id INT,
    total_amount DECIMAL(10,2),
    order_date DATETIME,
    status VARCHAR(20)
);

CREATE TABLE customer (
    customer_id INT PRIMARY KEY,
    customer_name VARCHAR(100),
    email VARCHAR(100)
);

-- Sample data
INSERT INTO orders VALUES
(501, 101, 150.00, '2024-03-02 09:30:00', 'completed'),
(502, 101, 200.00, '2024-03-02 12:45:00', 'completed'),
(503, 101, 100.00, '2024-03-02 14:20:00', 'pending'),
(504, 102, 120.00, '2024-03-02 15:30:00', 'completed'),
(505, 103, 180.00, '2024-03-02 10:15:00', 'completed'),
(506, 103, 100.00, '2024-03-02 16:00:00', 'completed');
Key Functions Used:
CURDATE() - Returns current date (2024-03-02)
DATE(order_date) - Extracts date part from datetime
TIME(order_date) - Extracts time part from datetime
HOUR(order_date) - Extracts hour (0-23)
GROUP_CONCAT() - Combines multiple values into comma-separated string

**The Complete Order (Easy to Remember):**
The correct order is:

SQL Query Clause Order
SELECT column1, column2, aggregate_function()
FROM table_name
WHERE condition
GROUP BY column1, column2
HAVING aggregate_condition
ORDER BY column1
LIMIT number;
The Complete Order (Easy to Remember):
SELECT - What columns to retrieve
FROM - Which table(s)
WHERE - Filter rows BEFORE grouping
GROUP BY - Group rows
HAVING - Filter groups AFTER grouping
ORDER BY - Sort the results
LIMIT - Limit number of results
Key Difference: WHERE vs HAVING
WHERE filters individual rows BEFORE grouping
HAVING filters groups AFTER aggregation
Example with All Three:
SELECT 
    department_id,
    COUNT(*) AS employee_count,
    AVG(salary) AS avg_salary
FROM employee
WHERE salary > 50000                    -- Filter rows first
GROUP BY department_id                  -- Then group
HAVING employee_count > 3               -- Filter groups
ORDER BY avg_salary DESC;               -- Finally sort
Execution Order (How SQL Processes It):
FROM - Get the table
WHERE - Filter individual rows (salary > 50000)
GROUP BY - Group remaining rows by department
HAVING - Filter the groups (employee_count > 3)
SELECT - Calculate the columns
ORDER BY - Sort the final result
LIMIT - Take only specified number of rows
Common Mistakes:
❌ Wrong Order:
SELECT department_id, COUNT(*) AS employee_count
FROM employee
HAVING employee_count > 5        -- ERROR: HAVING before GROUP BY
GROUP BY department_id
ORDER BY employee_count;
✅ Correct Order:
SELECT department_id, COUNT(*) AS employee_count
FROM employee
GROUP BY department_id           -- GROUP BY first
HAVING employee_count > 5        -- HAVING second
ORDER BY employee_count DESC;    -- ORDER BY last
Memory Trick:
"Some Frogs Will Go Hopping Over Logs"

SELECT
FROM
WHERE
GROUP BY
HAVING
ORDER BY
LIMIT





## 3. Find duplicate records
```sql
SELECT name, COUNT(*) AS count
FROM employee
GROUP BY name
HAVING count > 1;
```

## 4. Use date functions
```sql
SELECT * FROM employee
WHERE join_date >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH);
```

## 5. Use aliases
```sql
SELECT name AS Employee, salary AS `Monthly Salary`
FROM employee;
```

## 6. Use multiple joins
```sql
SELECT o.order_id, c.name AS customer_name, p.name AS product_name
FROM orders o
JOIN customer c ON o.customer_id = c.customer_id
JOIN product p ON o.product_id = p.product_id;
```

## 7. Use UNION
```sql
SELECT name FROM customer
UNION
SELECT name FROM employee;
```

---

# Notes
- These queries test subqueries, HAVING, GROUP BY, date functions, aliases, multiple joins, and UNION.
- Useful for intermediate-level interviews and practical reporting tasks.
