-- MySQL Intermediate SQL Queries

-- 1. Use subqueries
SELECT * FROM employee
WHERE salary > (SELECT AVG(salary) FROM employee);


SELECT e.employee_id, e.emp_name, e.department_id, e.salary
FROM employee e
WHERE e.salary > (
    SELECT AVG(salary)
    FROM employee
    WHERE department_id = e.department_id
);

-- 2. Use HAVING with GROUP BY
SELECT department_id, COUNT(*) AS employee_count
FROM employee
GROUP BY department_id
HAVING employee_count > 5;

-- 3. Find duplicate records
SELECT name, COUNT(*) AS count
FROM employee
GROUP BY name
HAVING count > 1;

-- 4. Use date functions
SELECT * FROM employee
WHERE join_date >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH);
Step-by-Step Explanation
Part	Function	What it does
CURDATE()	Returns today’s date (current date).	
DATE_SUB(date, INTERVAL 3 MONTH)	Subtracts 3 months from a given date.	
join_date >= ...	Filters rows where join_date is greater than or equal to that date.

	Example	Meaning
Last 7 days	WHERE join_date >= DATE_SUB(CURDATE(), INTERVAL 7 DAY)	Last week
Last 1 year	WHERE join_date >= DATE_SUB(CURDATE(), INTERVAL 1 YEAR)	Last 12 months
Upcoming 10 days	WHERE join_date <= DATE_ADD(CURDATE(), INTERVAL 10 DAY)	Future range


-- 5. Use aliases
SELECT name AS Employee, salary AS `Monthly Salary`
FROM employee;

-- 6. Use multiple joins
SELECT o.order_id, c.name AS customer_name, p.name AS product_name
FROM orders o
JOIN customer c ON o.customer_id = c.customer_id
JOIN product p ON o.product_id = p.product_id;

-- 7. Use UNION
SELECT name FROM customer
UNION
SELECT name FROM employee;

-- 8. Ecommerce: Find customers who placed orders in the last month
SELECT DISTINCT c.customer_id, c.name
FROM customer c
JOIN orders o ON c.customer_id = o.customer_id
WHERE o.order_date >= DATE_SUB(CURDATE(), INTERVAL 1 MONTH);

-- 9. Payment: Find payments above 1000
SELECT * FROM payment WHERE amount > 1000;

-- 10. Employee: Find employees with salary between 50,000 and 100,000
SELECT * FROM employee WHERE salary BETWEEN 50000 AND 100000;

-- 11. Salary: Find average salary by department
SELECT department_id, AVG(salary) AS avg_salary
FROM employee
GROUP BY department_id;




SELECT e.employee_id, e.emp_name, e.department_id, e.salary
FROM employee e
WHERE e.salary > (
    SELECT AVG(salary)
    FROM employee
    WHERE department_id = e.department_id
);

-- 12. Department: Find departments with no employees
SELECT d.department_id, d.name
FROM department d
LEFT JOIN employee e ON d.department_id = e.department_id
WHERE e.id IS NULL;

-- 13. Manager: List managers and their direct reports
SELECT m.name AS manager_name, GROUP_CONCAT(e.name) AS employees
FROM employee m
LEFT JOIN employee e ON m.id = e.manager_id
WHERE e.id IS NOT NULL
GROUP BY m.name;
