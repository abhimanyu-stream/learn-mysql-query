# MySQL Advanced SQL Queries

These queries test advanced SQL concepts: window functions, CTEs, correlated subqueries, CASE, recursion, stored procedures, triggers, indexing, query analysis, and transaction isolation.
- Essential for senior roles and MNC interviews.

---

## 1. Use window functions

You want an SQL query to rank employees by their salary in descending order using window functions.

✅ Query: Rank employees by salary

```sql
SELECT name, salary, RANK() OVER (ORDER BY salary DESC) AS salary_rank
FROM employee;
```

🔎 Explanation

The `RANK()` window function assigns a unique rank to each row based on the `ORDER BY` clause within the `OVER()` clause. Here, employees are ordered by `salary` in descending order (`DESC`), so the highest salary gets rank 1, the second highest gets rank 2, and so on.

- If there are ties (same salary), they receive the same rank.
- The next rank after ties skips the number of tied rows (e.g., if two employees tie for rank 1, the next gets rank 3).
- Unlike `ROW_NUMBER()`, which assigns unique numbers even with ties, `RANK()` handles ties by giving the same rank.

Example output (based on sample data in advanced-queries.sql):

| name    | salary  | salary_rank |
|---------|---------|-------------|
| David  | 130000 | 1          |
| Alice  | 120000 | 2          |
| Emma   | 110000 | 3          |
| Frank  | 105000 | 4          |
| Bob    | 90000  | 5          |
| Charlie| 70000  | 6          |
| Emma   | 60000  | 7          |
| David  | 50000  | 8          |

This query is useful for ranking data without grouping, allowing access to aggregate values per row.

## 2. Use CTEs (Common Table Expressions)

You want an SQL query to find employees whose salary is above the overall average salary using a Common Table Expression (CTE).

✅ Query: Employees above average salary

```sql
WITH avg_salary AS (
    SELECT AVG(salary) AS avg_sal FROM employee
)
SELECT * FROM employee
WHERE salary > (SELECT avg_sal FROM avg_salary);
```

🔎 Explanation

A CTE is a temporary named result set defined within a SQL statement using the `WITH` clause. It improves readability and can be referenced multiple times in the main query.

- The CTE `avg_salary` calculates the average salary across all employees.
- The main query selects all employees where `salary` is greater than this average.
- CTEs are not stored in the database and exist only for the duration of the query.

Example output (based on sample data in advanced-queries.sql, assuming average salary ~85,000):

| id | name    | salary | department_id | manager_id | join_date  | last_updated |
|----|---------|--------|---------------|------------|------------|--------------|
| 1  | Alice  | 120000| 1            | NULL      | 2020-01-10| ...         |
| 4  | David  | 130000| 1            | NULL      | 2019-01-01| ...         |
| ...| ...    | ...   | ...          | ...       | ...       | ...         |

This query is useful for filtering data based on aggregate calculations without subqueries in the WHERE clause.

## 3. Use correlated subqueries

You want an SQL query to find employees whose salary is above the average salary in their department using correlated subqueries.

✅ Query: Employees above department average salary

```sql
SELECT e1.name, e1.salary, e1.department_id
FROM employee e1
WHERE e1.salary > (
    SELECT AVG(e2.salary)
    FROM employee e2
    WHERE e2.department_id = e1.department_id
);
```

🔎 Explanation

A correlated subquery is executed once for each row processed by the outer query. It references columns from the outer query (`e1.department_id`).

- For each employee (`e1`), the subquery calculates the average salary of employees in the same department (`e2`).
- The outer query filters employees where their salary exceeds this department average.
- Correlated subqueries can be less efficient than joins or CTEs for large datasets due to repeated executions.

Example output (based on sample data in advanced-queries.sql):

| name    | salary | department_id |
|---------|--------|---------------|
| Alice  | 120000| 1            |
| David  | 130000| 1            |
| Emma   | 110000| 2            |
| Frank  | 105000| 2            |

This query identifies top performers within their departments.

## 4. Use CASE statements

You want an SQL query to categorize employees' salaries into 'High', 'Medium', or 'Low' based on thresholds using CASE statements.

✅ Query: Categorize employee salaries

```sql
SELECT name, salary,
CASE
    WHEN salary > 100000 THEN 'High'
    WHEN salary > 50000 THEN 'Medium'
    ELSE 'Low'
END AS salary_category
FROM employee;
```

🔎 Explanation

The `CASE` statement evaluates conditions in order and returns the corresponding value for the first true condition. It's similar to if-else logic in programming.

- `WHEN salary > 100000 THEN 'High'` assigns 'High' for salaries over 100,000.
- `WHEN salary > 50000 THEN 'Medium'` assigns 'Medium' for salaries between 50,001 and 100,000.
- `ELSE 'Low'` assigns 'Low' for salaries 50,000 or below.
- The result is aliased as `salary_category`.

Example output (based on sample data in advanced-queries.sql):

| name    | salary  | salary_category |
|---------|---------|-----------------|
| David  | 130000 | High           |
| Alice  | 120000 | High           |
| Emma   | 110000 | High           |
| Frank  | 105000 | High           |
| Bob    | 90000  | Medium         |
| Charlie| 70000  | Medium         |
| Emma   | 60000  | Medium         |
| David  | 50000  | Low            |

This query is useful for conditional logic and data transformation in SELECT statements.

## 5. Use recursive queries

You want an SQL query to build a hierarchical structure of employees and their managers using recursive CTEs.

✅ Query: Employee hierarchy

```sql
WITH RECURSIVE employee_hierarchy AS (
    SELECT id, name, manager_id FROM employee WHERE manager_id IS NULL
    UNION ALL
    SELECT e.id, e.name, e.manager_id
    FROM employee e
    INNER JOIN employee_hierarchy eh ON e.manager_id = eh.id
)
SELECT * FROM employee_hierarchy;
```

🔎 Explanation

Recursive CTEs allow a query to reference itself, enabling traversal of hierarchical data like organizational charts.

- The anchor member selects top-level employees (managers with `manager_id IS NULL`).
- The recursive member joins employees to the hierarchy where `e.manager_id = eh.id`, adding subordinates.
- `UNION ALL` combines results until no more rows are added.
- The final SELECT retrieves the full hierarchy.

Example output (based on sample data in advanced-queries.sql):

| id | name    | manager_id |
|----|---------|------------|
| 1  | Alice  | NULL      |
| 2  | Bob    | 1         |
| 3  | Charlie| 1         |
| 4  | David  | 3         |
| ...| ...    | ...       |

This query is useful for reporting on tree-like structures without multiple joins.

## 6. Use stored procedures

You want to create a stored procedure to add a new employee to the database.

✅ Query: Create procedure to add employee

```sql
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
```

🔎 Explanation

Stored procedures are precompiled SQL code stored in the database, allowing parameterized execution and encapsulation of business logic.

- `DELIMITER //` changes the delimiter to avoid conflicts with semicolons in the procedure body.
- `CREATE PROCEDURE` defines the procedure with input parameters (`IN`).
- `BEGIN ... END` contains the procedure logic, here an INSERT statement.
- Call with `CALL add_employee('John Doe', 75000, 1);`.

This procedure simplifies adding employees and can include validation or additional logic.

## 7. Use triggers

You want to create a trigger that automatically updates the `last_updated` timestamp whenever an employee record is modified.

✅ Query: Create trigger for employee updates

```sql
CREATE TRIGGER before_employee_update
BEFORE UPDATE ON employee
FOR EACH ROW
BEGIN
    SET NEW.last_updated = NOW();
END;
```

🔎 Explanation

Triggers are automatic actions executed in response to database events like INSERT, UPDATE, or DELETE.

- `BEFORE UPDATE` specifies the trigger fires before an update on the `employee` table.
- `FOR EACH ROW` means it executes once per affected row.
- `SET NEW.last_updated = NOW()` updates the `last_updated` column to the current timestamp.
- `NEW` refers to the updated row values.

This trigger ensures audit trails by automatically maintaining update timestamps.

## 8. Use indexing for optimization

You want to create an index on the `salary` and `department_id` columns to improve query performance.

✅ Query: Create index for salary and department

```sql
CREATE INDEX idx_salary_department ON employee(salary, department_id);
```

🔎 Explanation

Indexes speed up data retrieval by creating a data structure that allows quick lookups, similar to a book's index.

- `CREATE INDEX` creates a composite index on `salary` and `department_id`.
- Composite indexes are useful for queries filtering on both columns.
- This index optimizes queries like `SELECT * FROM employee WHERE salary > 50000 AND department_id = 1;`.
- Indexes improve SELECT performance but can slow down INSERT/UPDATE/DELETE due to maintenance.

This index enhances performance for salary-based queries grouped by department.

## 9. Use EXPLAIN to analyze queries

You want to analyze the execution plan of a query to understand how MySQL processes it.

✅ Query: Analyze query execution plan

```sql
EXPLAIN SELECT * FROM employee WHERE salary > 50000;
```

🔎 Explanation

`EXPLAIN` shows the query execution plan, including which indexes are used, join types, and estimated costs.

- It helps identify performance bottlenecks and whether indexes are being utilized.
- Output includes columns like `type` (join type), `possible_keys`, `key` (index used), `rows` (estimated rows examined).
- For this query, it might show a table scan if no index on `salary`, or index usage if present.

Example output:

| id | select_type | table    | type | possible_keys | key | key_len | ref | rows | Extra |
|----|-------------|----------|------|---------------|-----|---------|-----|------|-------|
| 1  | SIMPLE     | employee| ALL | idx_salary    | NULL| NULL   | NULL| 8   | Using where |

This tool is essential for query optimization and database tuning.

## 10. Handle deadlocks with transaction isolation

You want to set the transaction isolation level to SERIALIZABLE to prevent deadlocks in concurrent transactions.

✅ Query: Set isolation level for deadlock prevention

```sql
SET SESSION TRANSACTION ISOLATION LEVEL SERIALIZABLE;
START TRANSACTION;
-- perform operations
COMMIT;
```

🔎 Explanation

Transaction isolation levels control how concurrent transactions interact to prevent issues like dirty reads, non-repeatable reads, and lost updates.

- `SERIALIZABLE` is the highest level, ensuring transactions appear to execute serially, preventing deadlocks by locking resources.
- `START TRANSACTION` begins a transaction block.
- Operations within the block are isolated.
- `COMMIT` saves changes; `ROLLBACK` undoes them.
- SERIALIZABLE can reduce concurrency but ensures data consistency in high-contention scenarios.

This is used in scenarios requiring strict consistency, like financial operations.

## 11. Employees without any project assigned

You want an SQL query to find employees who do not have any project assigned among employee–department tables.

Let’s assume a common schema:

| Table | Columns | Description |
|-------|---------|-------------|
| Employee | emp_id, emp_name, dept_id | Employee details |
| Department | dept_id, dept_name | Department details |
| ProjectAssignment | proj_id, emp_id | Mapping employees to projects |

✅ Query: Employees without any project assigned( 3 tables)

```sql
SELECT e.emp_id, e.emp_name, d.dept_name
FROM Employee e
JOIN Department d ON e.dept_id = d.dept_id
LEFT JOIN ProjectAssignment pa ON e.emp_id = pa.emp_id
WHERE pa.emp_id IS NULL;
```

🔎 Explanation

- The `LEFT JOIN` with `ProjectAssignment` ensures all employees are included, even those without projects.
- The `WHERE pa.emp_id IS NULL` filters employees who have no project assigned.
- Joining with `Department` provides department details for each employee.

If projects are stored directly in the `Employee` table (e.g., `project_id` column), the query simplifies:

```sql
SELECT e.emp_id, e.emp_name, d.dept_name
FROM Employee e
JOIN Department d ON e.dept_id = d.dept_id
WHERE e.project_id IS NULL;
```

## 12. Employees with multiple projects assigned

You want an SQL query to find employees who have multiple projects assigned.

✅ Query: Employees with multiple projects assigned

```sql
SELECT e.emp_id, e.emp_name, COUNT(pa.proj_id) AS project_count
FROM Employee e
JOIN ProjectAssignment pa ON e.emp_id = pa.emp_id
GROUP BY e.emp_id, e.emp_name
HAVING COUNT(pa.proj_id) > 1;
```

🔎 Explanation

- Join `ProjectAssignment` to get project assignments per employee.
- Group by employee to count projects.
- Use `HAVING` to filter employees with more than one project.

## 13. Departments with no employees

You want an SQL query to find departments that have no employees assigned.

✅ Query: Departments with no employees

```sql
SELECT d.dept_id, d.dept_name
FROM Department d
LEFT JOIN Employee e ON d.dept_id = e.dept_id
WHERE e.dept_id IS NULL;
```

🔎 Explanation

- `LEFT JOIN` includes all departments.
- `WHERE e.dept_id IS NULL` filters departments with no employees.

## 14. Projects with the highest number of employees assigned

You want an SQL query to find projects with the highest number of employees assigned.

✅ Query: Projects with the highest number of employees assigned

```sql
SELECT pa.proj_id, COUNT(pa.emp_id) AS employee_count
FROM ProjectAssignment pa
GROUP BY pa.proj_id
ORDER BY employee_count DESC
LIMIT 1;
```

🔎 Explanation

- Group by project to count employees.
- Order descending to get the project with the most employees.
- Limit to 1 to get the top project.

## 15. Employees ranked by number of projects using window functions

You want an SQL query to rank employees by the number of projects they are assigned to.

✅ Query: Employees ranked by number of projects

```sql
SELECT e.emp_id, e.emp_name, COUNT(pa.proj_id) AS project_count,
       RANK() OVER (ORDER BY COUNT(pa.proj_id) DESC) AS project_rank
FROM Employee e
LEFT JOIN ProjectAssignment pa ON e.emp_id = pa.emp_id
GROUP BY e.emp_id, e.emp_name;
```

🔎 Explanation

- `LEFT JOIN` includes employees with zero projects.
- Group by employee to count projects.
- Use `RANK()` window function to rank employees by project count descending.

## 16. Employee with the highest salary

You want an SQL query to find the employee with the highest salary.

✅ Query: Employee with the highest salary

```sql
SELECT emp_id, emp_name, salary
FROM Employee
ORDER BY salary DESC
LIMIT 1;
```

🔎 Explanation

- Order employees by salary descending.
- Limit to 1 to get the highest paid employee.

## 17. Employee with the lowest salary

You want an SQL query to find the employee with the lowest salary.

✅ Query: Employee with the lowest salary

```sql
SELECT emp_id, emp_name, salary
FROM Employee
ORDER BY salary ASC
LIMIT 1;
```

🔎 Explanation

- Order employees by salary ascending.
- Limit to 1 to get the lowest paid employee.

## 18. Second highest salary

You want an SQL query to find the employee with the second highest salary.

✅ Query: Second highest salary

```sql
SELECT emp_id, emp_name, salary
FROM Employee
ORDER BY salary DESC
LIMIT 1 OFFSET 1;
```

🔎 Explanation

- Order employees by salary descending.
- Use `LIMIT 1 OFFSET 1` to skip the highest and get the second highest.

## 19. Employees with salary above department average

You want an SQL query to find employees whose salary is above their department's average salary.

✅ Query: Employees with salary above department average

```sql
SELECT e.emp_id, e.emp_name, e.salary, d.dept_name
FROM Employee e
JOIN Department d ON e.dept_id = d.dept_id
WHERE e.salary > (
    SELECT AVG(e2.salary)
    FROM Employee e2
    WHERE e2.dept_id = e.dept_id
);
```

🔎 Explanation

- Correlated subquery calculates average salary per department.
- Filters employees with salary above their department average.

## 20. Department-wise maximum salary

You want an SQL query to find the maximum salary in each department.

✅ Query: Department-wise maximum salary

```sql
SELECT d.dept_name, MAX(e.salary) AS max_salary
FROM Employee e
JOIN Department d ON e.dept_id = d.dept_id
GROUP BY d.dept_id, d.dept_name;
```

🔎 Explanation

- Join to get department names.
- Group by department.
- Use `MAX()` to get highest salary per department.

## 21. Number of employees per department

You want an SQL query to find the number of employees in each department.

✅ Query: Number of employees per department

```sql
SELECT d.dept_name, COUNT(e.emp_id) AS employee_count
FROM Department d
LEFT JOIN Employee e ON d.dept_id = e.dept_id
GROUP BY d.dept_id, d.dept_name;
```

🔎 Explanation

- `LEFT JOIN` includes departments with zero employees.
- Group by department.
- Count employees per department.

## 22. Average salary per department

You want an SQL query to find the average salary in each department.

✅ Query: Average salary per department

```sql
SELECT d.dept_name, AVG(e.salary) AS avg_salary
FROM Department d
JOIN Employee e ON d.dept_id = e.dept_id
GROUP BY d.dept_id, d.dept_name;
```

🔎 Explanation

- Join employees to departments.
- Group by department.
- Calculate average salary per department.

## 23. Number of projects per department

You want an SQL query to find the number of projects assigned to employees in each department.

✅ Query: Number of projects per department

```sql
SELECT d.dept_name, COUNT(DISTINCT pa.proj_id) AS project_count
FROM Department d
JOIN Employee e ON d.dept_id = e.dept_id
JOIN ProjectAssignment pa ON e.emp_id = pa.emp_id
GROUP BY d.dept_id, d.dept_name;
```

🔎 Explanation

- Join employees and project assignments.
- Count distinct projects per department.
- Group by department.

## 24. Employees grouped by manager

Assuming Employee has manager_id, you want an SQL query to find employees grouped by their manager.

✅ Query: Employees grouped by manager

```sql
SELECT m.emp_name AS manager_name, COUNT(e.emp_id) AS subordinate_count
FROM Employee e
JOIN Employee m ON e.manager_id = m.emp_id
GROUP BY m.emp_id, m.emp_name;
```

🔎 Explanation

- Self-join employees to get managers.
- Group by manager.
- Count subordinates per manager.

## 25. Total projects per employee

You want an SQL query to find the total number of projects assigned to each employee.

✅ Query: Total projects per employee

```sql
SELECT e.emp_id, e.emp_name, COUNT(pa.proj_id) AS project_count
FROM Employee e
LEFT JOIN ProjectAssignment pa ON e.emp_id = pa.emp_id
GROUP BY e.emp_id, e.emp_name;
```

🔎 Explanation

- Left join project assignments to include employees with zero projects.
- Group by employee.
- Count projects per employee.


# Notes
- 