# MySQL Notes and Concepts

---

## SQL Join Types Explained

- **LEFT JOIN**: Returns all rows from the left table and matching rows from the right table. If no match, right table columns are NULL.
- **INNER JOIN**: Returns only rows with matches in both tables.
- **RIGHT JOIN**: Returns all rows from the right table and matching rows from the left table. If no match, left table columns are NULL.
- **FULL OUTER JOIN**: Returns all rows from both tables, matched where possible. Not natively supported in MySQL, but can be emulated with UNION.

## Example Data

| employee_manager (e) | employee (m) |
|---------------------|--------------|
| id | name   | manager_id | id | name  |
|----|--------|------------|----|-------|
| 1  | Bob    | 101        | 101| David |
| 2  | Alice  | 102        | 102| Emma  |
| 3  | Charlie| NULL       | 103| Frank |

## Example Results

- **LEFT JOIN**: All employees, even if no manager.
- **INNER JOIN**: Only employees with managers.
- **RIGHT JOIN**: All managers, even if no employee.
- **FULL OUTER JOIN**: All employees and all managers, matched where possible.

## Interview Tips
- MySQL does not support FULL OUTER JOIN directly; use UNION of LEFT and RIGHT JOIN.
- Use EXPLAIN to analyze query performance.
- Use indexes for columns frequently used in WHERE, JOIN, and ORDER BY.
- Use GROUP_CONCAT to group employees under a manager.

---

# Useful SQL Patterns
- Find second highest salary without LIMIT.
- Find duplicates using GROUP BY and HAVING.
- Use window functions for ranking.
- Use CTEs for modular queries.
- Use triggers and stored procedures for automation.

---

# For More
- See each folder for categorized queries: basic, intermediate, advanced, core/interview.
- Practice writing and explaining each query for interviews.
