-- MySQL Core Concepts, Interview, and Tricky Queries

-- 1. Find the Second Highest Salary (No LIMIT)
SELECT MAX(salary) AS second_highest_salary
FROM employee
WHERE salary < (SELECT MAX(salary) FROM employee);

-- 2. Find Duplicate Records
SELECT name, COUNT(*) AS name_count
FROM employee
GROUP BY name
HAVING name_count > 1;

-- 3. Retrieve Records with No Matching Data (Left Join)
SELECT c.customer_id, c.name
FROM customer c
LEFT JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_id IS NULL;

-- 4. Find Nth Highest Salary (Generalized)
SELECT DISTINCT salary
FROM employee e1
WHERE (
    SELECT COUNT(DISTINCT salary)
    FROM employee e2
    WHERE e2.salary >= e1.salary
) = N;

-- 5. Retrieve Customers with Their Last Order
SELECT c.customer_id, c.name, o.order_id, o.order_date
FROM customer c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_date = (
    SELECT MAX(order_date)
    FROM orders
    WHERE customer_id = c.customer_id
);

-- 6. Self Join – Employees and Their Managers
SELECT e.name AS employee_name, m.name AS manager_name
FROM employee e
LEFT JOIN employee m ON e.manager_id = m.id;

-- 13. Manager: List managers and their direct reports
SELECT m.name AS manager_name, GROUP_CONCAT(e.name) AS employees
FROM employee m
LEFT JOIN employee e ON m.id = e.manager_id
WHERE e.id IS NOT NULL
GROUP BY m.name;

-- 7. FULL OUTER JOIN (Emulated with UNION)
SELECT e.name AS employee_name, m.name AS manager_name
FROM employee_manager e
LEFT JOIN employee m ON e.manager_id = m.id
UNION
SELECT e.name AS employee_name, m.name AS manager_name
FROM employee_manager e
RIGHT JOIN employee m ON e.manager_id = m.id
ORDER BY manager_name;

-- 8. Find Gaps in Sequential Data
SELECT t1.invoice_no + 1 AS missing_invoice
FROM invoices t1
LEFT JOIN invoices t2 ON t1.invoice_no + 1 = t2.invoice_no
WHERE t2.invoice_no IS NULL;

-- 9. Rank Employees by Salary within Each Department
SELECT name, department_id, salary,
RANK() OVER (PARTITION BY department_id ORDER BY salary DESC) AS salary_rank
FROM employee;

-- 10. Optimize Queries with Indexes
CREATE INDEX idx_status_created ON orders(status, created_at);
