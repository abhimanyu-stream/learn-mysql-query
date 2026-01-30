-- MySQL Basic SQL Queries

-- 1. Select all records from a table
SELECT * FROM employee;

-- 2. Filter records based on conditions
SELECT * FROM employee WHERE salary > 50000;

-- 3. Use ORDER BY to sort records
SELECT * FROM employee ORDER BY join_date DESC;

-- 4. Use aggregate functions like COUNT, SUM
SELECT COUNT(*) AS total_employees FROM employee;
SELECT SUM(salary) AS total_salary FROM employee;

-- 5. Use GROUP BY
SELECT department_id, COUNT(*) AS employee_count
FROM employee
GROUP BY department_id;

-- 6. Use basic joins
SELECT e.name AS employee_name, d.name AS department_name
FROM employee e
JOIN department d ON e.department_id = d.department_id;

-- 7. Use LIKE for pattern matching
SELECT * FROM employee WHERE name LIKE 'R%';

-- 8. Ecommerce: List all customers
SELECT * FROM customer;

-- 9. Payment: List all payments
SELECT * FROM payment;

-- 10. Employee: List all employees with their department
SELECT e.name, d.name AS department_name
FROM employee e
JOIN department d ON e.department_id = d.department_id;

-- 11. Salary: Show all employee salaries
SELECT name, salary FROM employee;

-- 12. Department: List all departments
SELECT * FROM department;

-- 13. Manager: List all managers (employees with no manager_id)
SELECT * FROM employee WHERE manager_id IS NULL;
