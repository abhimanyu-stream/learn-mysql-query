# MySQL Intermediate SQL Queries

---

## 1. Use subqueries
```sql
SELECT * FROM employee
WHERE salary > (SELECT AVG(salary) FROM employee);
```

## 2. Use HAVING with GROUP BY
```sql
SELECT department_id, COUNT(*) AS employee_count
FROM employee
GROUP BY department_id
HAVING employee_count > 5;
```

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
