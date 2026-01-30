-- Create a sample database
CREATE DATABASE IF NOT EXISTS company_db;
USE company_db;

-- Create tables
CREATE TABLE IF NOT EXISTS departments (
    dept_id INT PRIMARY KEY AUTO_INCREMENT,
    dept_name VARCHAR(50) NOT NULL,
    location VARCHAR(100)
);

CREATE TABLE IF NOT EXISTS employees (
    emp_id INT PRIMARY KEY AUTO_INCREMENT,
    emp_name VARCHAR(100) NOT NULL,
    email VARCHAR(100) UNIQUE,
    hire_date DATE NOT NULL,
    salary DECIMAL(10,2),
    dept_id INT,
    manager_id INT,
    FOREIGN KEY (dept_id) REFERENCES departments(dept_id),
    FOREIGN KEY (manager_id) REFERENCES employees(emp_id)
);

CREATE TABLE IF NOT EXISTS projects (
    project_id INT PRIMARY KEY AUTO_INCREMENT,
    project_name VARCHAR(100) NOT NULL,
    start_date DATE,
    end_date DATE,
    budget DECIMAL(15,2)
);

CREATE TABLE IF NOT EXISTS employee_projects (
    emp_id INT,
    project_id INT,
    hours_worked DECIMAL(5,2),
    PRIMARY KEY (emp_id, project_id),
    FOREIGN KEY (emp_id) REFERENCES employees(emp_id),
    FOREIGN KEY (project_id) REFERENCES projects(project_id)
);

-- Insert sample data
INSERT INTO departments (dept_name, location) VALUES 
('Engineering', 'Building A, Floor 1'),
('Marketing', 'Building A, Floor 2'),
('Sales', 'Building B, Floor 1'),
('HR', 'Building B, Floor 2');

-- Procedure to add a new employee
DELIMITER //
CREATE PROCEDURE AddEmployee(
    IN p_emp_name VARCHAR(100),
    IN p_email VARCHAR(100),
    IN p_hire_date DATE,
    IN p_salary DECIMAL(10,2),
    IN p_dept_id INT,
    IN p_manager_id INT,
    OUT p_emp_id INT,
    OUT p_status VARCHAR(100)
)
BEGIN
    DECLARE v_dept_count INT;
    DECLARE v_manager_dept_id INT;
    DECLARE EXIT HANDLER FOR SQLEXCEPTION
    BEGIN
        ROLLBACK;
        GET DIAGNOSTICS CONDITION 1
        @sqlstate = RETURNED_SQLSTATE, @errno = MYSQL_ERRNO, @text = MESSAGE_TEXT;
        SET p_status = CONCAT('Error: ', @errno, ' (', @sqlstate, '): ', @text);
    END;
    
    -- Check if department exists
    SELECT COUNT(*) INTO v_dept_count FROM departments WHERE dept_id = p_dept_id;
    IF v_dept_count = 0 THEN
        SET p_status = 'Error: Department does not exist';
    ELSE
        -- If manager_id is provided, verify manager exists and is in the same department
        IF p_manager_id IS NOT NULL THEN
            SELECT dept_id INTO v_manager_dept_id 
            FROM employees 
            WHERE emp_id = p_manager_id;
            
            IF v_manager_dept_id IS NULL THEN
                SET p_status = 'Error: Manager does not exist';
                LEAVE proc_label;
            END IF;
            
            IF v_manager_dept_id != p_dept_id THEN
                SET p_status = 'Error: Manager is not in the same department';
                LEAVE proc_label;
            END IF;
        END IF;
        
        -- Insert the new employee
        INSERT INTO employees (emp_name, email, hire_date, salary, dept_id, manager_id)
        VALUES (p_emp_name, p_email, p_hire_date, p_salary, p_dept_id, p_manager_id);
        
        SET p_emp_id = LAST_INSERT_ID();
        SET p_status = 'Employee added successfully';
    END IF;
    
    proc_label: BEGIN END; -- Label for early exit
END //

-- Procedure to get department statistics
CREATE PROCEDURE GetDepartmentStats(IN p_dept_id INT)
BEGIN
    SELECT 
        d.dept_name,
        d.location,
        COUNT(e.emp_id) as employee_count,
        AVG(e.salary) as avg_salary,
        MIN(e.hire_date) as oldest_hire_date,
        MAX(e.hire_date) as newest_hire_date
    FROM 
        departments d
    LEFT JOIN 
        employees e ON d.dept_id = e.dept_id
    WHERE 
        d.dept_id = p_dept_id
    GROUP BY 
        d.dept_id, d.dept_name, d.location;
        
    -- Get employees in this department
    SELECT 
        e.emp_id,
        e.emp_name,
        e.email,
        e.hire_date,
        e.salary,
        m.emp_name as manager_name
    FROM 
        employees e
    LEFT JOIN 
        employees m ON e.manager_id = m.emp_id
    WHERE 
        e.dept_id = p_dept_id
    ORDER BY 
        e.emp_name;
END //

-- Procedure to update employee salary with validation
CREATE PROCEDURE UpdateEmployeeSalary(
    IN p_emp_id INT,
    IN p_new_salary DECIMAL(10,2),
    OUT p_status VARCHAR(100)
)
BEGIN
    DECLARE v_current_salary DECIMAL(10,2);
    DECLARE v_max_increase DECIMAL(10,2) DEFAULT 0.2; -- Max 20% increase
    DECLARE v_min_salary DECIMAL(10,2) DEFAULT 30000; -- Minimum salary
    DECLARE v_dept_avg_salary DECIMAL(10,2);
    DECLARE v_dept_id INT;
    
    -- Get current salary and department
    SELECT salary, dept_id INTO v_current_salary, v_dept_id
    FROM employees
    WHERE emp_id = p_emp_id;
    
    -- Check if employee exists
    IF v_current_salary IS NULL THEN
        SET p_status = 'Error: Employee not found';
    -- Check if new salary is less than minimum
    ELSEIF p_new_salary < v_min_salary THEN
        SET p_status = CONCAT('Error: Salary cannot be less than ', v_min_salary);
    -- Check if increase is too large
    ELSEIF (p_new_salary - v_current_salary) / v_current_salary > v_max_increase THEN
        SET p_status = CONCAT('Error: Salary increase cannot exceed ', 
                             v_max_increase * 100, '%');
    ELSE
        -- Get department average salary
        SELECT AVG(salary) INTO v_dept_avg_salary
        FROM employees
        WHERE dept_id = v_dept_id;
        
        -- Check if new salary is significantly higher than department average
        IF p_new_salary > v_dept_avg_salary * 1.5 THEN
            SET p_status = 'Warning: New salary is more than 50% above department average';
            -- Log this for review
            INSERT INTO salary_change_audit 
            VALUES (p_emp_id, v_current_salary, p_new_salary, 'PENDING_APPROVAL', NOW());
        ELSE
            -- Update the salary
            UPDATE employees 
            SET salary = p_new_salary 
            WHERE emp_id = p_emp_id;
            
            -- Log the change
            INSERT INTO salary_change_audit 
            VALUES (p_emp_id, v_current_salary, p_new_salary, 'APPROVED', NOW());
            
            SET p_status = 'Salary updated successfully';
        END IF;
    END IF;
END //

-- Create audit table for salary changes
CREATE TABLE IF NOT EXISTS salary_change_audit (
    audit_id INT AUTO_INCREMENT PRIMARY KEY,
    emp_id INT,
    old_salary DECIMAL(10,2),
    new_salary DECIMAL(10,2),
    status VARCHAR(20),
    change_date DATETIME,
    FOREIGN KEY (emp_id) REFERENCES employees(emp_id)
);

-- Procedure to get employee project assignments
CREATE PROCEDURE GetEmployeeProjects(IN p_emp_id INT)
BEGIN
    SELECT 
        p.project_id,
        p.project_name,
        p.start_date,
        p.end_date,
        ep.hours_worked,
        p.budget,
        (SELECT COUNT(DISTINCT emp_id) 
         FROM employee_projects 
         WHERE project_id = p.project_id) as team_size
    FROM 
        projects p
    JOIN 
        employee_projects ep ON p.project_id = ep.project_id
    WHERE 
        ep.emp_id = p_emp_id
    ORDER BY 
        p.start_date DESC;
END //

-- Procedure to assign an employee to a project
CREATE PROCEDURE AssignEmployeeToProject(
    IN p_emp_id INT,
    IN p_project_id INT,
    IN p_hours_worked DECIMAL(5,2) DEFAULT 0,
    OUT p_status VARCHAR(100)
)
BEGIN
    DECLARE v_emp_count INT;
    DECLARE v_project_count INT;
    DECLARE v_assignment_count INT;
    
    -- Check if employee exists
    SELECT COUNT(*) INTO v_emp_count 
    FROM employees 
    WHERE emp_id = p_emp_id;
    
    -- Check if project exists
    SELECT COUNT(*) INTO v_project_count 
    FROM projects 
    WHERE project_id = p_project_id;
    
    -- Check if assignment already exists
    SELECT COUNT(*) INTO v_assignment_count
    FROM employee_projects
    WHERE emp_id = p_emp_id AND project_id = p_project_id;
    
    IF v_emp_count = 0 THEN
        SET p_status = 'Error: Employee does not exist';
    ELSEIF v_project_count = 0 THEN
        SET p_status = 'Error: Project does not exist';
    ELSEIF v_assignment_count > 0 THEN
        SET p_status = 'Error: Employee is already assigned to this project';
    ELSE
        -- Assign employee to project
        INSERT INTO employee_projects (emp_id, project_id, hours_worked)
        VALUES (p_emp_id, p_project_id, p_hours_worked);
        
        SET p_status = 'Employee assigned to project successfully';
    END IF;
END //

-- Procedure to generate department report
CREATE PROCEDURE GenerateDepartmentReport(IN p_dept_id INT)
BEGIN
    -- Department summary
    SELECT 
        d.dept_name,
        d.location,
        COUNT(DISTINCT e.emp_id) as total_employees,
        AVG(e.salary) as avg_salary,
        SUM(CASE WHEN e.manager_id IS NOT NULL THEN 1 ELSE 0 END) as has_manager_count,
        MIN(e.hire_date) as oldest_hire_date
    FROM 
        departments d
    LEFT JOIN 
        employees e ON d.dept_id = e.dept_id
    WHERE 
        d.dept_id = p_dept_id
    GROUP BY 
        d.dept_id, d.dept_name, d.location;
    
    -- Employee count by year
    SELECT 
        YEAR(hire_date) as hire_year,
        COUNT(*) as employees_hired
    FROM 
        employees
    WHERE 
        dept_id = p_dept_id
    GROUP BY 
        YEAR(hire_date)
    ORDER BY 
        hire_year;
    
    -- Salary distribution
    SELECT 
        FLOOR(salary/10000)*10000 as salary_range_start,
        COUNT(*) as employee_count
    FROM 
        employees
    WHERE 
        dept_id = p_dept_id
    GROUP BY 
        FLOOR(salary/10000)
    ORDER BY 
        salary_range_start;
END //

DELIMITER ;

-- Insert some sample data
INSERT INTO projects (project_name, start_date, end_date, budget) VALUES 
('Website Redesign', '2024-01-15', '2024-06-30', 50000.00),
('Mobile App Development', '2024-02-01', '2024-08-31', 120000.00),
('Marketing Campaign Q2', '2024-04-01', '2024-06-30', 35000.00);

-- Add some employees using the procedure
CALL AddEmployee('John Doe', 'john.doe@example.com', '2020-05-15', 75000.00, 1, NULL, @emp1, @status);
CALL AddEmployee('Jane Smith', 'jane.smith@example.com', '2021-02-20', 85000.00, 1, 1, @emp2, @status);
CALL AddEmployee('Bob Johnson', 'bob.johnson@example.com', '2022-06-10', 65000.00, 2, NULL, @emp3, @status);

-- Assign employees to projects
CALL AssignEmployeeToProject(1, 1, 10.5, @status);
CALL AssignEmployeeToProject(2, 1, 15.0, @status);
CALL AssignEmployeeToProject(2, 2, 20.0, @status);
CALL AssignEmployeeToProject(3, 3, 8.5, @status);
