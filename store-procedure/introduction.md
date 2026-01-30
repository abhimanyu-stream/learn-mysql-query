# MySQL Stored Procedures: A Comprehensive Guide

## What is a Stored Procedure?
A stored procedure is a prepared SQL code that you can save and reuse. It's like a function in other programming languages - you can pass parameters, perform operations, and return results.

## Basic Syntax

```sql
DELIMITER //

CREATE PROCEDURE procedure_name([parameters])
BEGIN
    -- SQL statements
END //

DELIMITER ;
```

## Creating Your First Stored Procedure

Let's create a simple stored procedure that returns "Hello, World!"

```sql
DELIMITER //

CREATE PROCEDURE HelloWorld()
BEGIN
    SELECT 'Hello, World!' AS message;
END //

DELIMITER ;

-- To call the procedure:
CALL HelloWorld();
```

## Parameters in Stored Procedures

### IN Parameters (Default)
```sql
DELIMITER //

CREATE PROCEDURE GetEmployee(IN emp_id INT)
BEGIN
    SELECT * FROM employees WHERE id = emp_id;
END //

DELIMITER ;

-- Call with parameter
CALL GetEmployee(101);
```

### OUT Parameters
```sql
DELIMITER //

CREATE PROCEDURE GetEmployeeCount(OUT total INT)
BEGIN
    SELECT COUNT(*) INTO total FROM employees;
END //

DELIMITER ;

-- Call and get the output
CALL GetEmployeeCount(@count);
SELECT @count AS total_employees;
```

### INOUT Parameters
```sql
DELIMITER //

CREATE PROCEDURE IncrementCounter(INOUT counter INT, IN increment INT)
BEGIN
    SET counter = counter + increment;
END //

DELIMITER ;

-- Usage
SET @counter = 5;
CALL IncrementCounter(@counter, 3);
SELECT @counter;  -- Returns 8
```

## Conditional Logic

```sql
DELIMITER //

CREATE PROCEDURE CheckEmployeeStatus(IN emp_id INT, OUT status VARCHAR(50))
BEGIN
    DECLARE emp_salary DECIMAL(10,2);
    
    SELECT salary INTO emp_salary FROM employees WHERE id = emp_id;
    
    IF emp_salary > 100000 THEN
        SET status = 'High Earner';
    ELSEIF emp_salary > 50000 THEN
        SET status = 'Mid Level';
    ELSE
        SET status = 'Entry Level';
    END IF;
END //

DELIMITER ;
```

## Loops

### WHILE Loop
```sql
DELIMITER //

CREATE PROCEDURE CreateNumberTable(IN max_num INT)
BEGIN
    DECLARE i INT DEFAULT 1;
    DROP TABLE IF EXISTS numbers;
    CREATE TABLE numbers (num INT);
    
    WHILE i <= max_num DO
        INSERT INTO numbers VALUES (i);
        SET i = i + 1;
    END WHILE;
    
    SELECT * FROM numbers;
END //

DELIMITER ;
```

## Error Handling

```sql
DELIMITER //

CREATE PROCEDURE SafeDivision(
    IN num1 INT, 
    IN num2 INT, 
    OUT result DECIMAL(10,2),
    OUT status VARCHAR(50)
)
BEGIN
    DECLARE CONTINUE HANDLER FOR 1365, 1366, 1062
    BEGIN
        SET status = 'Error: Invalid input or division by zero';
        SET result = NULL;
    END;
    
    IF num2 = 0 THEN
        SIGNAL SQLSTATE '45000' 
        SET MESSAGE_TEXT = 'Division by zero error';
    ELSE
        SET result = num1 / num2;
        SET status = 'Success';
    END IF;
END //

DELIMITER ;
```

## Modifying and Managing Stored Procedures

### View Existing Procedures
```sql
-- List all stored procedures
SHOW PROCEDURE STATUS WHERE Db = 'your_database_name';

-- View procedure definition
SHOW CREATE PROCEDURE procedure_name;
```

### Modify a Procedure
```sql
-- First drop the existing procedure
DROP PROCEDURE IF EXISTS procedure_name;

-- Then create it again with changes
DELIMITER //
CREATE PROCEDURE procedure_name()
BEGIN
    -- Updated procedure body
END //
DELIMITER ;
```

### Delete a Procedure
```sql
DROP PROCEDURE IF EXISTS procedure_name;
```

## Best Practices

1. Use meaningful names that describe the procedure's purpose
2. Include comments for complex logic
3. Handle potential errors
4. Use transactions when making multiple related changes
5. Avoid using SELECT * - specify only needed columns
6. Consider security implications (SQL injection)
7. Document parameters and return values

## Example: Complete Employee Management

```sql
DELIMITER //

CREATE PROCEDURE ManageEmployee(
    IN action VARCHAR(10),
    IN emp_id INT,
    IN emp_name VARCHAR(100),
    IN emp_salary DECIMAL(10,2),
    OUT status VARCHAR(100)
)
BEGIN
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        SET status = CONCAT('Error: ', SQLSTATE, ' - ', SQLERRM);
    END;
    
    START TRANSACTION;
    
    CASE action
        WHEN 'ADD' THEN
            INSERT INTO employees (id, name, salary) 
            VALUES (emp_id, emp_name, emp_salary);
            SET status = 'Employee added successfully';
            
        WHEN 'UPDATE' THEN
            UPDATE employees 
            SET name = emp_name, salary = emp_salary 
            WHERE id = emp_id;
            SET status = 'Employee updated successfully';
            
        WHEN 'DELETE' THEN
            DELETE FROM employees WHERE id = emp_id;
            SET status = 'Employee deleted successfully';
            
        ELSE
            SET status = 'Invalid action specified';
    END CASE;
    
    COMMIT;
END //

DELIMITER ;
```

## Stored Functions vs Stored Procedures

### What are Stored Functions?

Stored functions are similar to stored procedures but with key differences in their usage and behavior. They are designed to return a single value and can be used in SQL statements.

### Key Differences

| Feature | Stored Procedure | Stored Function |
|---------|------------------|-----------------|
| **Return Value** | Can return zero or multiple values using OUT parameters | Must return exactly one value using RETURN statement |
| **Usage in SQL** | Cannot be used directly in SQL statements | Can be used in SQL statements (SELECT, WHERE, etc.) |
| **Transaction Control** | Can manage transactions (COMMIT/ROLLBACK) | Cannot contain transaction control statements |
| **DML Operations** | Can perform DML operations (INSERT, UPDATE, DELETE) | Typically used for calculations, should avoid DML |
| **Calling** | CALL procedure_name() | SELECT function_name() |
| **Error Handling** | Supports comprehensive error handling | Limited error handling capabilities |

### Creating a Stored Function

```sql
DELIMITER //

CREATE FUNCTION CalculateBonus(emp_salary DECIMAL(10,2), years_of_service INT) 
RETURNS DECIMAL(10,2)
DETERMINISTIC
BEGIN
    DECLARE bonus DECIMAL(10,2);
    
    IF years_of_service > 5 THEN
        SET bonus = emp_salary * 0.15;
    ELSEIF years_of_service > 2 THEN
        SET bonus = emp_salary * 0.10;
    ELSE
        SET bonus = emp_salary * 0.05;
    END IF;
    
    RETURN LEAST(bonus, 10000); -- Cap bonus at 10,000
END //

DELIMITER ;

-- Usage in SQL
SELECT 
    emp_name, 
    salary, 
    CalculateBonus(salary, TIMESTAMPDIFF(YEAR, hire_date, CURDATE())) AS bonus
FROM employees;
```

### When to Use Stored Functions

1. **Calculations**: Complex calculations used in multiple queries
2. **Data Transformation**: Reusable data formatting or transformation logic
3. **Business Rules**: Encapsulating business rules that return a single value
4. **Data Validation**: Reusable validation logic

### Example: Complex Business Logic

```sql
DELIMITER //

CREATE FUNCTION GetEmployeeStatus(emp_id INT) 
RETURNS VARCHAR(50)
READS SQL DATA
BEGIN
    DECLARE emp_salary DECIMAL(10,2);
    DECLARE years_of_service INT;
    DECLARE project_count INT;
    
    -- Get employee details
    SELECT 
        salary,
        TIMESTAMPDIFF(YEAR, hire_date, CURDATE())
    INTO emp_salary, years_of_service
    FROM employees
    WHERE id = emp_id;
    
    -- Count active projects
    SELECT COUNT(*) 
    INTO project_count
    FROM employee_projects 
    WHERE emp_id = emp_id 
    AND end_date > CURDATE();
    
    -- Determine status based on multiple factors
    IF emp_salary > 100000 AND years_of_service > 5 AND project_count > 2 THEN
        RETURN 'Senior Lead';
    ELSEIF emp_salary > 75000 AND years_of_service > 3 THEN
        RETURN 'Team Lead';
    ELSEIF project_count > 0 THEN
        RETURN 'Team Member';
    ELSE
        RETURN 'On Bench';
    END IF;
END //

DELIMITER ;

-- Usage
SELECT emp_name, GetEmployeeStatus(id) AS status FROM employees;
```

### Best Practices for Stored Functions

1. **Use DETERMINISTIC when possible**: Improves performance by allowing MySQL to cache results
2. **Keep them simple**: Functions should do one thing well
3. **Avoid DML operations**: Functions should generally be read-only
4. **Handle NULL values**: Always account for potential NULL inputs
5. **Document thoroughly**: Include comments about parameters, return values, and usage

### Performance Considerations

1. **Caching**: MySQL caches deterministic function results
2. **Query Optimization**: Functions in WHERE clauses can prevent index usage
3. **Context Switching**: Avoid excessive database calls within functions
4. **Temporary Tables**: Be cautious with temporary tables in functions

## Next Steps

1. Practice creating and calling stored procedures
2. Experiment with different parameter types
3. Implement error handling in your procedures
4. Try creating procedures with complex business logic
5. Create and use stored functions in your SQL queries





comprehensive files to help you learn MySQL stored procedures:

introduction.md - A detailed guide covering:
Basic syntax and structure
Parameters (IN, OUT, INOUT)
Conditional logic and loops
Error handling
Best practices
Complete examples
practical_examples.sql - A hands-on example with:
Sample database schema (employees, departments, projects)
Practical stored procedures for common operations
Error handling and validation
Complex business logic
Sample data
How to Use These Files:
First, execute the SQL in 
practical_examples.sql
 to set up the database and procedures.
Refer to 
introduction.md
 for explanations and examples.
Try calling the procedures with different parameters.

Key Concepts Demonstrated:
Parameter Handling: IN, OUT, and INOUT parameters
Error Handling: Using DECLARE HANDLER for exceptions
Data Validation: Checking business rules before operations
Transactions: Ensuring data consistency
Complex Queries: Joins, aggregations, and subqueries