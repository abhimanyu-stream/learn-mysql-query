-- -----------------------------
-- Table and Sample Data Setup --
-- -----------------------------

-- Employee Table
DROP TABLE IF EXISTS employee;
CREATE TABLE employee (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100),
    salary DECIMAL(10,2),
    department_id INT,
    manager_id INT,
    join_date DATE,
    last_updated DATETIME
);
INSERT INTO employee (name, salary, department_id, manager_id, join_date, last_updated) VALUES
('Alice', 120000, 1, NULL, '2020-01-10', NOW()),
('Bob', 90000, 1, 1, '2021-03-15', NOW()),
('Charlie', 70000, 2, 1, '2022-06-20', NOW()),
('David', 50000, 2, 3, '2023-02-01', NOW()),
('Emma', 60000, 1, 1, '2023-05-10', NOW()),
('Frank', 80000, 2, 3, '2022-09-12', NOW());

-- Department Table
DROP TABLE IF EXISTS department;
CREATE TABLE department (
    department_id INT PRIMARY KEY,
    name VARCHAR(100)
);
INSERT INTO department (department_id, name) VALUES
(1, 'Engineering'),
(2, 'HR');

-- Orders Table
DROP TABLE IF EXISTS orders;
CREATE TABLE orders (
    order_id INT PRIMARY KEY AUTO_INCREMENT,
    customer_id INT,
    product_id INT,
    order_date DATE,
    status VARCHAR(20),
    amount DECIMAL(10,2),
    created_at DATETIME
);
INSERT INTO orders (customer_id, product_id, order_date, status, amount, created_at) VALUES
(1, 1, '2025-09-10', 'completed', 100.00, NOW()),
(2, 2, '2025-09-12', 'pending', 200.00, NOW()),
(1, 3, '2025-09-15', 'completed', 150.00, NOW()),
(3, 1, '2025-09-17', 'completed', 120.00, NOW());

-- Customer Table
DROP TABLE IF EXISTS customer;
CREATE TABLE customer (
    customer_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100),
    email VARCHAR(100)
);
INSERT INTO customer (name, email) VALUES
('John Doe', 'john@example.com'),
('Jane Smith', 'jane@example.com'),
('Sam Lee', 'sam@example.com');

-- Product Table
DROP TABLE IF EXISTS product;
CREATE TABLE product (
    product_id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100)
);
INSERT INTO product (name) VALUES
('Laptop'),
('Phone'),
('Tablet');

-- ProjectAssignment Table (for employee-project mappings)
DROP TABLE IF EXISTS project_assignment;
CREATE TABLE project_assignment (
    proj_id INT,
    emp_id INT,
    PRIMARY KEY (proj_id, emp_id),
    FOREIGN KEY (emp_id) REFERENCES employee(id)
);
INSERT INTO project_assignment (proj_id, emp_id) VALUES
(1, 1),
(1, 2),
(2, 3),
(3, 4),
(3, 5);

-- Invoices Table
DROP TABLE IF EXISTS invoices;
CREATE TABLE invoices (
    invoice_no INT PRIMARY KEY
);
INSERT INTO invoices (invoice_no) VALUES (1), (2), (4), (5);

-- employee_manager Table (for FULL OUTER JOIN example)
DROP TABLE IF EXISTS employee_manager;
CREATE TABLE employee_manager (
    id INT PRIMARY KEY AUTO_INCREMENT,
    name VARCHAR(100),
    manager_id INT
);
INSERT INTO employee_manager (name, manager_id) VALUES
('Bob', 101),
('Alice', 102),
('Charlie', NULL);

-- Add managers to employee table for join
INSERT INTO employee (name, salary, department_id, manager_id, join_date, last_updated) VALUES
('David', 130000, 1, NULL, '2019-01-01', NOW()),
('Emma', 110000, 2, NULL, '2018-05-01', NOW()),
('Frank', 105000, 2, NULL, '2017-07-01', NOW());

-- MySQL Advanced SQL Queries

-- 1. Ranks employees by salary using window function RANK().
SELECT name, salary, RANK() OVER (ORDER BY salary DESC) AS salary_rank
FROM employee;

-- 2. Uses CTE to find employees above average salary.
WITH avg_salary AS (
    SELECT AVG(salary) AS avg_sal FROM employee
)
SELECT * FROM employee
WHERE salary > (SELECT avg_sal FROM avg_salary);






-- 3. Correlated subquery to find employees above their department's average salary.
SELECT e1.name, e1.salary, e1.department_id
FROM employee e1
WHERE e1.salary > (
    SELECT AVG(e2.salary)
    FROM employee e2
    WHERE e2.department_id = e1.department_id
);

-- 4. Categorizes salaries using CASE statement.
SELECT name, salary,
CASE
    WHEN salary > 100000 THEN 'High'
    WHEN salary > 50000 THEN 'Medium'
    ELSE 'Low'
END AS salary_category
FROM employee;

-- 5. Recursive CTE to build employee hierarchy.
WITH RECURSIVE employee_hierarchy AS (
    SELECT id, name, manager_id FROM employee WHERE manager_id IS NULL
    UNION ALL
    SELECT e.id, e.name, e.manager_id
    FROM employee e
    INNER JOIN employee_hierarchy eh ON e.manager_id = eh.id
)
SELECT * FROM employee_hierarchy;

-- 6. Stored procedure to add a new employee.
DELIMITER //
CREATE PROCEDURE add_employee(
    IN emp_name VARCHAR(100),
    IN emp_salary DECIMAL(10,2),
    IN dept_id INT
)
BEGIN
    INSERT INTO employee(name, salary, department_id)
    VALUES (emp_name, emp_salary, dept_id);
END //
DELIMITER ;

-- 7. Trigger to update last_updated on employee changes.
CREATE TRIGGER before_employee_update
BEFORE UPDATE ON employee
FOR EACH ROW
BEGIN
    SET NEW.last_updated = NOW();
END;

-- 8. Creates index on salary and department_id.
CREATE INDEX idx_salary_department ON employee(salary, department_id);

-- 9. EXPLAIN to analyze query plan for salary filter.
EXPLAIN SELECT * FROM employee WHERE salary > 50000;

-- 10. Sets transaction isolation and starts transaction (for deadlock demo).
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
START TRANSACTION;
-- perform operations
COMMIT;

-- -----------------------------
-- Additional Real-World & Interview SQL Queries
-- -----------------------------

-- 11. Correlated subquery for employees above department average.
SELECT e1.name, e1.salary, e1.department_id
FROM employee e1
WHERE e1.salary > (
    SELECT AVG(e2.salary)
    FROM employee e2
    WHERE e2.department_id = e1.department_id
);
-- In MySQL, the JOIN keyword is an alias for INNER JOIN by default, not LEFT JOIN. LEFT JOIN must be explicitly specified when an outer join is required, as used in the queries where all records from the left table are needed (e.g., employees without projects or departments with no employees). The queries in advance/advanced-queries.sql and .md are correctly using JOIN for inner joins and LEFT JOIN for outer joins as appropriate.

-- 12. LEFT JOIN to find customers with no recent orders.
SELECT c.customer_id, c.name
FROM customer c
LEFT JOIN orders o ON c.customer_id = o.customer_id AND o.order_date >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)
WHERE o.order_id IS NULL;

-- 13. UPDATE salaries for employees joined before 2023.
UPDATE employee
SET salary = salary * 1.05
WHERE join_date < '2023-01-01';

-- 14. Delete orders with status 'cancelled' older than 6 months
DELETE FROM orders
WHERE status = 'cancelled' AND order_date < DATE_SUB(CURDATE(), INTERVAL 6 MONTH);

-- 15. Grant SELECT and UPDATE privileges to a user (admin task)
GRANT SELECT, UPDATE ON *.* TO 'java_lead'@'localhost';







-- 16. Find top 3 products by sales amount (window function)
SELECT product_id, SUM(amount) AS total_sales,
       RANK() OVER (ORDER BY SUM(amount) DESC) AS sales_rank
FROM orders
GROUP BY product_id
ORDER BY total_sales DESC
LIMIT 3;

-- 17. Show all running processes (admin monitoring)
SHOW PROCESSLIST;

-- 18. Find tables larger than 10MB (performance monitoring)
SELECT table_name, ROUND((data_length + index_length) / 1024 / 1024, 2) AS size_mb
FROM information_schema.tables
WHERE table_schema = DATABASE() AND (data_length + index_length) > 10 * 1024 * 1024;

-- 19. Create a view for high earning employees
CREATE OR REPLACE VIEW high_earners AS
SELECT * FROM employee WHERE salary > 100000;

-- 20. Use a prepared statement (Java integration example)
PREPARE stmt FROM 'SELECT * FROM employee WHERE email = ?';

-- 21. Simulate a deadlock (for interview discussion)
-- Transaction 1:
-- START TRANSACTION;
-- UPDATE accounts SET balance = balance - 100 WHERE account_id = 1;
-- UPDATE accounts SET balance = balance + 100 WHERE account_id = 2;
-- Transaction 2:
-- START TRANSACTION;
-- UPDATE accounts SET balance = balance + 100 WHERE account_id = 2;
-- UPDATE accounts SET balance = balance - 100 WHERE account_id = 1;

-- 22. Find employees who have never had a salary update (using triggers/audit table)
-- (Assume salary_history table exists)
SELECT e.id, e.name
FROM employee e
LEFT JOIN salary_history sh ON e.id = sh.employee_id
WHERE sh.employee_id IS NULL;

-- 23. Archive old audit logs (admin/maintenance)
INSERT INTO audit_log_archive SELECT * FROM audit_log WHERE action_date < DATE_SUB(CURDATE(), INTERVAL 1 YEAR);
DELETE FROM audit_log WHERE action_date < DATE_SUB(CURDATE(), INTERVAL 1 YEAR);

-- 24. Find orders with missing product or customer (data integrity)
SELECT o.order_id
FROM orders o
LEFT JOIN product p ON o.product_id = p.product_id
LEFT JOIN customer c ON o.customer_id = c.customer_id
WHERE p.product_id IS NULL OR c.customer_id IS NULL;

-- 25. List all indexes on the employee table
SHOW INDEX FROM employee;
-- -----------------------------
-- ECOMMERCE, PAYMENT, EMPLOYEE, SALARY, DEPARTMENT, MANAGER QUERIES
-- -----------------------------





-- 26. Ecommerce: List top 5 customers by total spend in last 30 days
SELECT c.customer_id, c.name, SUM(o.amount) AS total_spent
FROM customer c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_date >= DATE_SUB(CURDATE(), INTERVAL 30 DAY)
GROUP BY c.customer_id, c.name
ORDER BY total_spent DESC
LIMIT 5;

-- 27. Payment: Find all failed transactions in last 7 days
SELECT * FROM payment
WHERE status = 'FAILED' AND payment_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY);

-- 28. Employee: List employees and their manager names
SELECT e.name AS employee_name, m.name AS manager_name
FROM employee e
LEFT JOIN employee m ON e.manager_id = m.id;

-- 29. Salary: Find employees whose salary is above the average in their department
SELECT e1.name, e1.salary, e1.department_id
FROM employee e1
WHERE e1.salary > (
    SELECT AVG(e2.salary)
    FROM employee e2
    WHERE e2.department_id = e1.department_id
);

-- 30. Department: Count employees in each department
SELECT d.name AS department_name, COUNT(e.id) AS employee_count
FROM department d
LEFT JOIN employee e ON d.department_id = e.department_id
GROUP BY d.name;

-- 31. Manager: List managers with number of direct reports
SELECT m.id AS manager_id, m.name AS manager_name, COUNT(e.id) AS num_reports
FROM employee m
LEFT JOIN employee e ON m.id = e.manager_id
GROUP BY m.id, m.name;

-- 32. Ecommerce: Find products never ordered
SELECT p.product_id, p.name
FROM product p
LEFT JOIN orders o ON p.product_id = o.product_id
WHERE o.order_id IS NULL;

-- 33. Payment: Total payment amount by status
SELECT status, SUM(amount) AS total_amount
FROM payment
GROUP BY status;

-- 34. Employee: Find employees who joined in the last year
SELECT * FROM employee
WHERE join_date >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR);

-- 35. Salary: Show salary history for an employee (assume salary_history table)
SELECT sh.employee_id, e.name, sh.old_salary, sh.new_salary, sh.change_date
FROM salary_history sh
JOIN employee e ON sh.employee_id = e.id
ORDER BY sh.change_date DESC;

-- -----------------------------
-- Additional Queries from advanced-queries.md
-- -----------------------------

-- 11. Employees without any project assigned
SELECT e.id AS emp_id, e.name AS emp_name, d.name AS dept_name
FROM employee e
JOIN department d ON e.department_id = d.department_id
LEFT JOIN project_assignment pa ON e.id = pa.emp_id
WHERE pa.emp_id IS NULL;

-- 12. Employees with multiple projects assigned
SELECT e.id AS emp_id, e.name AS emp_name, COUNT(pa.proj_id) AS project_count
FROM employee e
JOIN project_assignment pa ON e.id = pa.emp_id
GROUP BY e.id, e.name
HAVING COUNT(pa.proj_id) > 1;

-- 13. Departments with no employees
SELECT d.department_id, d.name AS dept_name
FROM department d
LEFT JOIN employee e ON d.department_id = e.department_id
WHERE e.department_id IS NULL;

-- 14. Projects with the highest number of employees assigned
SELECT pa.proj_id, COUNT(pa.emp_id) AS employee_count
FROM project_assignment pa
GROUP BY pa.proj_id
ORDER BY employee_count DESC
LIMIT 1;

-- 15. Employees ranked by number of projects using window functions
SELECT e.id AS emp_id, e.name AS emp_name, COUNT(pa.proj_id) AS project_count,
       RANK() OVER (ORDER BY COUNT(pa.proj_id) DESC) AS project_rank
FROM employee e
LEFT JOIN project_assignment pa ON e.id = pa.emp_id
GROUP BY e.id, e.name;

-- 16. Employee with the highest salary
SELECT id AS emp_id, name AS emp_name, salary
FROM employee
ORDER BY salary DESC
LIMIT 1;

-- 17. Employee with the lowest salary
SELECT id AS emp_id, name AS emp_name, salary
FROM employee
ORDER BY salary ASC
LIMIT 1;

-- 18. Second highest salary
SELECT id AS emp_id, name AS emp_name, salary
FROM employee
ORDER BY salary DESC
LIMIT 1 OFFSET 1;

-- 19. Employees with salary above department average
SELECT e.id AS emp_id, e.name AS emp_name, e.salary, d.name AS dept_name
FROM employee e
JOIN department d ON e.department_id = d.department_id
WHERE e.salary > (
    SELECT AVG(e2.salary)
    FROM employee e2
    WHERE e2.department_id = e.department_id
);

-- 20. Department-wise maximum salary
SELECT d.name AS dept_name, MAX(e.salary) AS max_salary
FROM employee e
JOIN department d ON e.department_id = d.department_id
GROUP BY d.department_id, d.name;

-- 21. Number of employees per department
SELECT d.name AS dept_name, COUNT(e.id) AS employee_count
FROM department d
LEFT JOIN employee e ON d.department_id = e.department_id
GROUP BY d.department_id, d.name;

-- 22. Average salary per department
SELECT d.name AS dept_name, AVG(e.salary) AS avg_salary
FROM department d
JOIN employee e ON d.department_id = e.department_id
GROUP BY d.department_id, d.name;

-- 23. Number of projects per department
SELECT d.name AS dept_name, COUNT(DISTINCT pa.proj_id) AS project_count
FROM department d
JOIN employee e ON d.department_id = e.department_id
JOIN project_assignment pa ON e.id = pa.emp_id
GROUP BY d.department_id, d.name;

-- 24. Employees grouped by manager
SELECT m.name AS manager_name, COUNT(e.id) AS subordinate_count
FROM employee e
JOIN employee m ON e.manager_id = m.id
GROUP BY m.id, m.name;

-- 25. Total projects per employee
SELECT e.id AS emp_id, e.name AS emp_name, COUNT(pa.proj_id) AS project_count
FROM employee e
LEFT JOIN project_assignment pa ON e.id = pa.emp_id
GROUP BY e.id, e.name;













-----------------------------------------------

-- 26. Second highest salary using subquery.
SELECT MAX(salary) AS second_highest_salary
FROM employee
WHERE salary < (SELECT MAX(salary) FROM employee);

-- 27. Highest salary using subquery.
SELECT * FROM employee
WHERE salary = (SELECT MAX(salary) FROM employee);

-- 28. Lowest salary using subquery.
SELECT * FROM employee
WHERE salary = (SELECT MIN(salary) FROM employee);

-- 29. Second highest salary per department using subquery.
SELECT d.name AS department_name, (
    SELECT MAX(e.salary)
    FROM employee e
    WHERE e.department_id = d.department_id AND e.salary < (
        SELECT MAX(e2.salary)
        FROM employee e2
        WHERE e2.department_id = d.department_id
    )
) AS second_highest_salary
FROM department d;

-- 30. Highest salary per department using subquery.
SELECT d.name AS department_name, (
    SELECT MAX(e.salary)
    FROM employee e0
    WHERE e.department_id = d.department_id
) AS highest_salary
FROM department d;
