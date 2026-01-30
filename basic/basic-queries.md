# MySQL Basic SQL Queries

---

## 1. Select all records from a table
```sql
SELECT * FROM employee;
```

## 2. Filter records based on conditions
```sql
SELECT * FROM employee WHERE salary > 50000;
```

## 3. Use ORDER BY to sort records
```sql
SELECT * FROM employee ORDER BY join_date DESC;
```

## 4. Use aggregate functions like COUNT, SUM
```sql
SELECT COUNT(*) AS total_employees FROM employee;
SELECT SUM(salary) AS total_salary FROM employee;
```

## 5. Use GROUP BY
```sql
SELECT department_id, COUNT(*) AS employee_count
FROM employee
GROUP BY department_id;
```

## 6. Use basic joins
```sql
SELECT e.name AS employee_name, d.name AS department_name
FROM employee e
JOIN department d ON e.department_id = d.department_id;
```

## 7. Use LIKE for pattern matching
```sql
SELECT * FROM employee WHERE name LIKE 'R%';
```

---

# Notes
- These queries test basic SELECT, WHERE, JOIN, aggregation, and pattern matching skills.
- Useful for warm-up and initial screening in interviews.
