# Spring Boot + JPA + MySQL Stored Procedures Integration

This guide shows how to call MySQL stored procedures from a Spring Boot application using JPA and Hibernate.

## Prerequisites
- Java 11+
- Spring Boot 2.7.x or later
- MySQL 8.0+
- Maven/Gradle

## 1. Add Dependencies

### Maven (`pom.xml`):
```xml
<dependencies>
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-data-jpa</artifactId>
    </dependency>
    <dependency>
        <groupId>mysql</groupId>
        <artifactId>mysql-connector-java</artifactId>
        <scope>runtime</scope>
    </dependency>
    <dependency>
        <groupId>org.projectlombok</groupId>
        <artifactId>lombok</artifactId>
        <optional>true</optional>
    </dependency>
</dependencies>
```

## 2. Configure Application Properties

`application.properties`:
```properties
# Database Configuration
spring.datasource.url=jdbc:mysql://localhost:3306/company_db?useSSL=false&serverTimezone=UTC
spring.datasource.username=your_username
spring.datasource.password=your_password

# JPA/Hibernate Properties
spring.jpa.hibernate.ddl-auto=update
spring.jpa.show-sql=true
spring.jpa.properties.hibernate.dialect=org.hibernate.dialect.MySQL8Dialect
spring.jpa.properties.hibernate.format_sql=true

# Show SQL parameter values (for debugging)
logging.level.org.hibernate.type.descriptor.sql.BasicBinder=TRACE
```

## 3. Entity Classes

### Department Entity
```java
import lombok.Data;
import javax.persistence.*;
import java.util.List;

@Data
@Entity
@Table(name = "departments")
@NamedStoredProcedureQueries({
    @NamedStoredProcedureQuery(
        name = "Department.getDepartmentStats",
        procedureName = "GetDepartmentStats",
        parameters = {
            @StoredProcedureParameter(mode = ParameterMode.IN, name = "p_dept_id", type = Integer.class)
        },
        resultClasses = { DepartmentStatsDTO.class }
    )
})
public class Department {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "dept_id")
    private Long id;
    
    @Column(name = "dept_name", nullable = false)
    private String name;
    
    private String location;
    
    @OneToMany(mappedBy = "department", fetch = FetchType.LAZY)
    private List<Employee> employees;
}
```

### Employee Entity
```java
import lombok.Data;
import javax.persistence.*;

@Data
@Entity
@Table(name = "employees")
@NamedStoredProcedureQueries({
    @NamedStoredProcedureQuery(
        name = "Employee.addEmployee",
        procedureName = "AddEmployee",
        parameters = {
            @StoredProcedureParameter(mode = ParameterMode.IN, name = "p_emp_name", type = String.class),
            @StoredProcedureParameter(mode = ParameterMode.IN, name = "p_email", type = String.class),
            @StoredProcedureParameter(mode = ParameterMode.IN, name = "p_hire_date", type = String.class),
            @StoredProcedureParameter(mode = ParameterMode.IN, name = "p_salary", type = Double.class),
            @StoredProcedureParameter(mode = ParameterMode.IN, name = "p_dept_id", type = Integer.class),
            @StoredProcedureParameter(mode = ParameterMode.IN, name = "p_manager_id", type = Integer.class),
            @StoredProcedureParameter(mode = ParameterMode.OUT, name = "p_emp_id", type = Integer.class),
            @StoredProcedureParameter(mode = ParameterMode.OUT, name = "p_status", type = String.class)
        }
    ),
    @NamedStoredProcedureQuery(
        name = "Employee.updateEmployeeSalary",
        procedureName = "UpdateEmployeeSalary",
        parameters = {
            @StoredProcedureParameter(mode = ParameterMode.IN, name = "p_emp_id", type = Integer.class),
            @StoredProcedureParameter(mode = ParameterMode.IN, name = "p_new_salary", type = Double.class),
            @StoredProcedureParameter(mode = ParameterMode.OUT, name = "p_status", type = String.class)
        }
    )
})
public class Employee {
    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    @Column(name = "emp_id")
    private Long id;
    
    @Column(name = "emp_name", nullable = false)
    private String name;
    
    @Column(unique = true)
    private String email;
    
    @Column(name = "hire_date", nullable = false)
    private LocalDate hireDate;
    
    private Double salary;
    
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "dept_id")
    private Department department;
    
    @ManyToOne(fetch = FetchType.LAZY)
    @JoinColumn(name = "manager_id")
    private Employee manager;
    
    @OneToMany(mappedBy = "manager", fetch = FetchType.LAZY)
    private List<Employee> subordinates;
    
    @ManyToMany
    @JoinTable(
        name = "employee_projects",
        joinColumns = @JoinColumn(name = "emp_id"),
        inverseJoinColumns = @JoinColumn(name = "project_id")
    )
    private List<Project> projects;
}
```

## 4. DTOs for Stored Procedure Results

### DepartmentStatsDTO
```java
import lombok.Data;
import java.math.BigDecimal;

@Data
public class DepartmentStatsDTO {
    private String deptName;
    private String location;
    private Long employeeCount;
    private BigDecimal avgSalary;
    private java.sql.Date oldestHireDate;
    private java.sql.Date newestHireDate;
}
```

## 5. Repository Layer

### Employee Repository
```java
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.query.Procedure;
import org.springframework.data.repository.query.Param;

public interface EmployeeRepository extends JpaRepository<Employee, Long> {
    
    // Using @Procedure with method name convention
    @Procedure(procedureName = "AddEmployee")
    Map<String, Object> addEmployee(
        @Param("p_emp_name") String name,
        @Param("p_email") String email,
        @Param("p_hire_date") String hireDate,
        @Param("p_salary") Double salary,
        @Param("p_dept_id") Integer deptId,
        @Param("p_manager_id") Integer managerId
    );
    
    // Using @Procedure with explicit parameter mapping
    @Procedure(name = "Employee.updateEmployeeSalary")
    String updateEmployeeSalary(
        @Param("p_emp_id") Long employeeId,
        @Param("p_new_salary") Double newSalary
    );
}
```

### Department Repository
```java
import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.query.Procedure;
import org.springframework.data.repository.query.Param;
import java.util.List;

public interface DepartmentRepository extends JpaRepository<Department, Long> {
    
    // Using EntityManager with @Query for complex result mapping
    @Query(value = "CALL GetDepartmentStats(:p_dept_id)", nativeQuery = true)
    List<Object[]> getDepartmentStats(@Param("p_dept_id") Long departmentId);
    
    // Alternative using ResultSet mapping
    @Procedure(name = "Department.getDepartmentStats")
    List<DepartmentStatsDTO> getDepartmentStatsMapped(@Param("p_dept_id") Long departmentId);
}
```

## 6. Service Layer

### Employee Service
```java
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.time.LocalDate;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class EmployeeService {
    
    private final EmployeeRepository employeeRepository;
    
    @Transactional
    public Map<String, Object> addEmployee(String name, String email, LocalDate hireDate, 
                                         Double salary, Long deptId, Long managerId) {
        return employeeRepository.addEmployee(
            name,
            email,
            hireDate.toString(),
            salary,
            deptId.intValue(),
            managerId != null ? managerId.intValue() : null
        );
    }
    
    @Transactional
    public String updateEmployeeSalary(Long employeeId, Double newSalary) {
        return employeeRepository.updateEmployeeSalary(employeeId, newSalary);
    }
}
```

### Department Service
```java
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import java.util.List;

@Service
@RequiredArgsConstructor
public class DepartmentService {
    
    private final DepartmentRepository departmentRepository;
    
    @Transactional(readOnly = true)
    public List<Object[]> getDepartmentStats(Long departmentId) {
        return departmentRepository.getDepartmentStats(departmentId);
    }
    
    @Transactional(readOnly = true)
    public List<DepartmentStatsDTO> getDepartmentStatsMapped(Long departmentId) {
        return departmentRepository.getDepartmentStatsMapped(departmentId);
    }
}
```

## 7. Controller Layer

### Employee Controller
```java
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.time.LocalDate;
import java.util.Map;

@RestController
@RequestMapping("/api/employees")
@RequiredArgsConstructor
public class EmployeeController {
    
    private final EmployeeService employeeService;
    
    @PostMapping
    public ResponseEntity<?> addEmployee(
            @RequestParam String name,
            @RequestParam String email,
            @RequestParam String hireDate,
            @RequestParam Double salary,
            @RequestParam Long deptId,
            @RequestParam(required = false) Long managerId) {
        
        Map<String, Object> result = employeeService.addEmployee(
            name, email, LocalDate.parse(hireDate), salary, deptId, managerId
        );
        
        return ResponseEntity.ok(result);
    }
    
    @PutMapping("/{id}/salary")
    public ResponseEntity<String> updateSalary(
            @PathVariable Long id,
            @RequestParam Double newSalary) {
        
        String result = employeeService.updateEmployeeSalary(id, newSalary);
        return ResponseEntity.ok(result);
    }
}
```

### Department Controller
```java
import lombok.RequiredArgsConstructor;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import java.util.List;

@RestController
@RequestMapping("/api/departments")
@RequiredArgsConstructor
public class DepartmentController {
    
    private final DepartmentService departmentService;
    
    @GetMapping("/{id}/stats")
    public ResponseEntity<?> getDepartmentStats(@PathVariable Long id) {
        return ResponseEntity.ok(departmentService.getDepartmentStatsMapped(id));
    }
}
```

## 8. Testing the Endpoints

### Add a New Employee
```http
POST /api/employees
Content-Type: application/x-www-form-urlencoded

name=John%20Doe&email=john.doe@example.com&hireDate=2024-01-15&salary=75000&deptId=1&managerId=1
```

### Update Employee Salary
```http
PUT /api/employees/1/salary?newSalary=80000
```

### Get Department Statistics
```http
GET /api/departments/1/stats
```

## 9. Important Notes

1. **Transaction Management**: 
   - Use `@Transactional` for methods that modify data
   - For read-only operations, use `@Transactional(readOnly = true)`

2. **Error Handling**:
   - Implement `@ControllerAdvice` for global exception handling
   - Handle `DataAccessException` for database-related errors

3. **Performance Considerations**:
   - Use DTOs to avoid lazy loading issues
   - Consider using `@EntityGraph` or `JOIN FETCH` for eager loading when needed
   - Use pagination for large result sets

4. **Security**:
   - Add Spring Security for authentication/authorization
   - Validate all inputs
   - Use parameterized queries to prevent SQL injection

5. **Logging**:
   - Add appropriate logging for debugging and monitoring
   - Log stored procedure calls and their parameters

## 10. Alternative: Using JdbcTemplate

For more complex stored procedures or better control, you can use `JdbcTemplate`:

```java
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.SqlParameter;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.stereotype.Repository;

import javax.sql.DataSource;
import java.sql.Types;
import java.util.HashMap;
import java.util.Map;

@Repository
public class EmployeeCustomRepository {
    
    private final JdbcTemplate jdbcTemplate;
    private SimpleJdbcCall getEmployeeProjectsCall;
    
    public EmployeeCustomRepository(DataSource dataSource) {
        this.jdbcTemplate = new JdbcTemplate(dataSource);
        this.getEmployeeProjectsCall = new SimpleJdbcCall(dataSource)
            .withProcedureName("GetEmployeeProjects")
            .declareParameters(
                new SqlParameter("p_emp_id", Types.INTEGER)
            );
    }
    
    public List<Map<String, Object>> getEmployeeProjects(Long employeeId) {
        Map<String, Object> inParams = new HashMap<>();
        inParams.put("p_emp_id", employeeId);
        
        Map<String, Object> result = getEmployeeProjectsCall.execute(inParams);
        
        // Handle the result set
        // The actual structure depends on your stored procedure's result set
        return (List<Map<String, Object>>) result.get("#result-set-1");
    }
}
```

## 11. Additional Stored Procedure Calling Methods

### 1. Using EntityManager with createStoredProcedureQuery()

```java
import javax.persistence.*;
import java.util.List;

@Repository
@RequiredArgsConstructor
public class EmployeeProcedureRepository {
    
    @PersistenceContext
    private final EntityManager entityManager;
    
    @SuppressWarnings("unchecked")
    public List<Object[]> getEmployeeProjects(Long employeeId) {
        StoredProcedureQuery query = entityManager
            .createStoredProcedureQuery("GetEmployeeProjects")
            .registerStoredProcedureParameter("p_emp_id", Long.class, ParameterMode.IN)
            .setParameter("p_emp_id", employeeId);
            
        // For OUT parameters:
        // .registerStoredProcedureParameter("out_param", String.class, ParameterMode.OUT)
        
        // Execute and get result list
        return query.getResultList();
    }
    
    // For procedures with multiple result sets
    @SuppressWarnings("unchecked")
    public Map<String, Object> getEmployeeDetails(Long employeeId) {
        StoredProcedureQuery query = entityManager
            .createStoredProcedureQuery("GetEmployeeDetails")
            .registerStoredProcedureParameter("p_emp_id", Long.class, ParameterMode.IN)
            .setParameter("p_emp_id", employeeId);
            
        // Execute the query
        boolean hasResults = query.execute();
        
        Map<String, Object> result = new HashMap<>();
        int resultSetCount = 0;
        
        // Process all result sets
        do {
            if (hasResults) {
                result.put("resultSet" + (++resultSetCount), query.getResultList());
            }
            hasResults = query.hasMoreResults();
        } while (hasResults || query.getUpdateCount() != -1);
        
        // Process OUT parameters if any
        // String outParam = (String) query.getOutputParameterValue("out_param");
        
        return result;
    }
}
```

### 2. Using JdbcTemplate.call()

```java
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.core.SqlOutParameter;
import org.springframework.jdbc.core.SqlParameter;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.stereotype.Repository;

import javax.sql.DataSource;
import java.sql.Types;
import java.util.HashMap;
import java.util.Map;

@Repository
@RequiredArgsConstructor
public class EmployeeJdbcRepository {
    
    private final JdbcTemplate jdbcTemplate;
    
    // Using JdbcTemplate.call() with CallableStatementCreator
    public Map<String, Object> getEmployeeProjects(Long employeeId) {
        return jdbcTemplate.call(con -> {
            CallableStatement cs = con.prepareCall(
                "{call GetEmployeeProjects(?, ?)}",
                ResultSet.TYPE_SCROLL_INSENSITIVE,
                ResultSet.CONCUR_READ_ONLY
            );
            cs.setLong(1, employeeId);
            cs.registerOutParameter(2, Types.VARCHAR); // For OUT parameter
            return cs;
        }, Arrays.asList(
            new SqlParameter("p_emp_id", Types.BIGINT),
            new SqlOutParameter("status", Types.VARCHAR)
        ));
    }
    
    // Using SimpleJdbcCall with explicit parameter declaration
    public Map<String, Object> getEmployeeDetails(Long employeeId) {
        SimpleJdbcCall jdbcCall = new SimpleJdbcCall(jdbcTemplate)
            .withProcedureName("GetEmployeeDetails")
            .declareParameters(
                new SqlParameter("p_emp_id", Types.BIGINT),
                new SqlOutParameter("out_status", Types.VARCHAR)
            )
            .returningResultSet("employees", (rs, rowNum) -> {
                // Map result set to DTO
                Map<String, Object> emp = new HashMap<>();
                emp.put("id", rs.getLong("emp_id"));
                emp.put("name", rs.getString("emp_name"));
                return emp;
            });
            
        Map<String, Object> params = new HashMap<>();
        params.put("p_emp_id", employeeId);
        
        return jdbcCall.execute(params);
    }
}
```

### 3. Using JPA StoredProcedureQuery

```java
import javax.persistence.*;
import java.util.List;

@Repository
@RequiredArgsConstructor
public class EmployeeStoredProcedureRepository {
    
    @PersistenceContext
    private final EntityManager entityManager;
    
    @SuppressWarnings("unchecked")
    public List<EmployeeProjectDTO> getEmployeeProjects(Long employeeId) {
        StoredProcedureQuery query = entityManager
            .createStoredProcedureQuery("GetEmployeeProjects", "EmployeeProjectMapping")
            .registerStoredProcedureParameter("p_emp_id", Long.class, ParameterMode.IN)
            .setParameter("p_emp_id", employeeId);
            
        // Execute and map results using the named mapping
        return query.getResultList();
    }
    
    // Using SqlResultSetMapping
    @SqlResultSetMapping(
        name = "EmployeeProjectMapping",
        classes = @ConstructorResult(
            targetClass = EmployeeProjectDTO.class,
            columns = {
                @ColumnResult(name = "project_id", type = Long.class),
                @ColumnResult(name = "project_name", type = String.class),
                @ColumnResult(name = "hours_worked", type = Double.class)
            }
        )
    )
    @Entity
    @Table(name = "dummy") // Required but not used
    public static class DummyEntity { @Id private Long id; }
}

// DTO class for mapping results
public class EmployeeProjectDTO {
    private Long projectId;
    private String projectName;
    private Double hoursWorked;
    
    public EmployeeProjectDTO(Long projectId, String projectName, Double hoursWorked) {
        this.projectId = projectId;
        this.projectName = projectName;
        this.hoursWorked = hoursWorked;
    }
    
    // Getters and setters
}
```

### 4. Using Spring Data JDBC

```java
import org.springframework.data.jdbc.repository.query.Modifying;
import org.springframework.data.jdbc.repository.query.Query;
import org.springframework.data.repository.CrudRepository;
import org.springframework.data.repository.query.Param;

public interface EmployeeJdbcRepository extends CrudRepository<Employee, Long> {
    
    @Query("CALL GetEmployeeProjects(:employeeId)")
    List<Map<String, Object>> findProjectsByEmployeeId(@Param("employeeId") Long employeeId);
    
    @Modifying
    @Query("CALL UpdateEmployeeStatus(:employeeId, :status)")
    void updateEmployeeStatus(
        @Param("employeeId") Long employeeId, 
        @Param("status") String status
    );
    
    // Using SimpleJdbcCall with Spring Data JDBC
    @Query(value = "SELECT * FROM employees WHERE dept_id = :deptId", 
           resultSetExtractorClass = EmployeeResultSetExtractor.class)
    List<Employee> findByDepartment(@Param("deptId") Long departmentId);
}

// Custom ResultSetExtractor
public class EmployeeResultSetExtractor implements ResultSetExtractor<List<Employee>> {
    @Override
    public List<Employee> extractData(ResultSet rs) throws SQLException {
        List<Employee> employees = new ArrayList<>();
        while (rs.next()) {
            Employee emp = new Employee();
            emp.setId(rs.getLong("emp_id"));
            emp.setName(rs.getString("emp_name"));
            // Map other fields
            employees.add(emp);
        }
        return employees;
    }
}
```

### 5. Using MyBatis

```java
@Mapper
public interface EmployeeMapper {
    @Select("{CALL GetEmployeeProjects(#{empId, mode=IN, jdbcType=BIGINT}, " +
            "#{status, mode=OUT, jdbcType=VARCHAR})}")
    @Options(statementType = StatementType.CALLABLE)
    List<Map<String, Object>> getEmployeeProjects(
        @Param("empId") Long employeeId,
        @Param("status") String status
    );
    
    // For multiple result sets
    @Select("{CALL GetEmployeeDetails(#{empId, mode=IN, jdbcType=BIGNUMERIC})}")
    @Options(statementType = StatementType.CALLABLE)
    @Results({
        @Result(property = "id", column = "emp_id"),
        @Result(property = "name", column = "emp_name"),
        @Result(property = "projects", 
                column = "emp_id",
                many = @Many(select = "findProjectsByEmployeeId"))
    })
    Employee getEmployeeWithProjects(@Param("empId") Long employeeId);
    
    @Select("SELECT * FROM projects p " +
            "JOIN employee_projects ep ON p.project_id = ep.project_id " +
            "WHERE ep.emp_id = #{empId}")
    List<Project> findProjectsByEmployeeId(@Param("empId") Long employeeId);
}
```

### 6. Using R2DBC (Reactive)

```java
import org.springframework.r2dbc.core.DatabaseClient;
import reactor.core.publisher.Flux;
import reactor.core.publisher.Mono;

@Repository
@RequiredArgsConstructor
public class EmployeeReactiveRepository {
    
    private final DatabaseClient databaseClient;
    
    public Flux<Employee> findEmployeesByDepartment(Long deptId) {
        return databaseClient
            .sql("CALL GetDepartmentEmployees(:deptId)")
            .bind("deptId", deptId)
            .map((row, meta) -> {
                Employee emp = new Employee();
                emp.setId(row.get("emp_id", Long.class));
                emp.setName(row.get("emp_name", String.class));
                return emp;
            })
            .all();
    }
    
    public Mono<Void> updateEmployeeStatus(Long employeeId, String status) {
        return databaseClient
            .sql("CALL UpdateEmployeeStatus(:empId, :status)")
            .bind("empId", employeeId)
            .bind("status", status)
            .fetch()
            .rowsUpdated()
            .then();
    }
}
```

## 12. Performance Considerations

1. **Connection Pooling**:
   - Use HikariCP for connection pooling
   - Configure appropriate pool size based on your application load

2. **Batch Processing**:
   ```java
   @Transactional
   public void batchUpdateEmployees(List<Employee> employees) {
       jdbcTemplate.batchUpdate(
           "CALL UpdateEmployee(?, ?, ?)",
           new BatchPreparedStatementSetter() {
               @Override
               public void setValues(PreparedStatement ps, int i) throws SQLException {
                   Employee emp = employees.get(i);
                   ps.setLong(1, emp.getId());
                   ps.setString(2, emp.getName());
                   ps.setDouble(3, emp.getSalary());
               }
               @Override
               public int getBatchSize() {
                   return employees.size();
               }
           });
   }
   ```

3. **Caching**:
   - Use Spring Cache for frequently called procedures
   - Implement cache invalidation strategies

## 13. Security Best Practices

1. **SQL Injection Prevention**:
   - Always use parameterized queries
   - Avoid string concatenation in SQL
   - Use JPA/Hibernate parameter binding

2. **Input Validation**:
   ```java
   @Validated
   @Service
   public class EmployeeService {
       
       @Validated
       public void updateEmployee(@Valid EmployeeDTO employee) {
           // Implementation
       }
   }
   
   public class EmployeeDTO {
       @NotNull @Size(min = 1, max = 100)
       private String name;
       
       @Email
       private String email;
       
       @Min(30000) @Max(1000000)
       private Double salary;
   }
   ```

## 14. Testing Stored Procedures

```java
@SpringBootTest
@Transactional
public class EmployeeProcedureTest {
    
    @Autowired
    private TestEntityManager entityManager;
    
    @Autowired
    private EmployeeRepository employeeRepository;
    
    @Test
    public void testAddEmployee() {
        // Given
        String name = "Test User";
        String email = "test@example.com";
        
        // When
        Map<String, Object> result = employeeRepository.addEmployee(
            name, email, LocalDate.now(), 50000.0, 1L, null);
        
        // Then
        assertNotNull(result.get("p_emp_id"));
        assertEquals("Employee added successfully", result.get("p_status"));
    }
    
    @Test
    public void testGetEmployeeProjects() {
        // Given
        Long employeeId = 1L;
        
        // When
        List<Object[]> projects = employeeRepository.getEmployeeProjects(employeeId);
        
        // Then
        assertFalse(projects.isEmpty());
        // Additional assertions
    }
}
```

## 15. Monitoring and Logging

```java
@Aspect
@Component
@Slf4j
public class StoredProcedureLoggingAspect {
    
    @Around("execution(* com.yourpackage.repository.*.*(..))")
    public Object logStoredProcedureCall(ProceedingJoinPoint joinPoint) throws Throwable {
        String methodName = joinPoint.getSignature().getName();
        Object[] args = joinPoint.getArgs();
        
        long startTime = System.currentTimeMillis();
        
        try {
            log.info("Calling stored procedure: {} with args: {}", methodName, Arrays.toString(args));
            Object result = joinPoint.proceed();
            long executionTime = System.currentTimeMillis() - startTime;
            
            log.info("Stored procedure {} executed in {} ms", methodName, executionTime);
            return result;
            
        } catch (Exception e) {
            log.error("Error executing stored procedure: " + methodName, e);
            throw e;
        }
    }
}
```

## 16. Conclusion

This guide demonstrates how to integrate MySQL stored procedures with Spring Boot using JPA/Hibernate. You can choose the approach that best fits your needs:

1. **JPA's `@NamedStoredProcedureQuery`**: Best for simple stored procedures with basic result mapping
2. **`@Query` with native queries**: Good for complex result sets when you need more control
3. **`JdbcTemplate`/`SimpleJdbcCall`**: Most flexible for complex stored procedures with multiple result sets

Remember to handle transactions, exceptions, and security appropriately in your production application.


a comprehensive guide on integrating MySQL stored procedures with Spring Boot using JPA/Hibernate. Here's what's included:

Key Components:
Spring Boot Configuration
Maven dependencies
Database configuration
JPA/Hibernate settings
Entity Classes
Department and Employee entities with JPA annotations
@NamedStoredProcedureQuery for stored procedure mapping
Repository Layer
Spring Data JPA repositories
Stored procedure integration using:
@Procedure annotation
Native queries with @Query
Custom result set mapping
Service Layer
Business logic encapsulation
Transaction management
DTO transformations
REST Controllers
CRUD endpoints
Request/response handling
Input validation
Alternative Approaches
Using JdbcTemplate for complex procedures
Handling multiple result sets
Parameter mapping
How to Use:
Copy the code into a new Spring Boot project
Update the database configuration in application.properties
Run the application and test the endpoints
Example API Endpoints:
Add Employee: POST /api/employees
Update Salary: PUT /api/employees/{id}/salary?newSalary=80000
Get Department Stats: GET /api/departments/{id}/stats
Best Practices:
Transaction Management: Use @Transactional appropriately
Error Handling: Implement global exception handling
Performance: Use DTOs and pagination
Security: Add Spring Security and input validation
Testing: Write unit and integration tests






've enhanced the documentation to cover all major approaches for calling stored procedures in Spring Boot. Here's what's been added:

Comprehensive Coverage of Stored Procedure Integration
EntityManager with createStoredProcedureQuery()
Basic procedure calls
Handling multiple result sets
IN/OUT parameter management
JdbcTemplate.call()
Using CallableStatementCreator
Working with SimpleJdbcCall
Complex parameter mapping
JPA StoredProcedureQuery
Advanced result mapping with @SqlResultSetMapping
Constructor result mapping
Named parameter support
Spring Data JDBC
@Query with CALL syntax
Custom ResultSetExtractor
Batch operations
MyBatis Integration
@Select with stored procedures
Multiple result sets
Complex mappings
R2DBC (Reactive)
Non-blocking procedure calls
Reactive types (Mono/Flux)
Parameter binding
Additional Sections:
Performance Optimization
Connection pooling
Batch processing
Caching strategies
Security Best Practices
SQL injection prevention
Input validation
Secure coding
Testing
Integration tests
Mocking
Test data setup
Monitoring and Logging
AOP for procedure call logging
Performance metrics
Error tracking
When to Use Each Approach:
Simple CRUD: JPA @Procedure or @Query
Complex Business Logic: JdbcTemplate or EntityManager
High Performance: Batch processing with JdbcTemplate
Reactive Applications: R2DBC
Legacy Integration: MyBatis for complex SQL
The documentation now provides a complete reference for working with stored procedures in Spring Boot, from basic to advanced scenarios. Each approach includes code examples and best practices.



----------Difference---------

You're right that both approaches achieve similar results, but they have some key differences in implementation, flexibility, and maintainability. Let me break down the differences:

1. @Query with Native Query
java
@Query(value = "CALL GetDepartmentStats(:p_dept_id)", nativeQuery = true)
List<Object[]> getDepartmentStats(@Param("p_dept_id") Long departmentId);
Characteristics:

Direct SQL: Uses native SQL to call the stored procedure
Raw Results: Returns List<Object[]> where you need to manually map array indices to fields
Performance: Slightly better performance for simple cases
Flexibility: Can be used with any SQL, not just stored procedures
Maintenance: More error-prone due to string-based queries
Type Safety: Less type-safe, potential for runtime errors
2. @Procedure with ResultSet Mapping
java
@Procedure(name = "Department.getDepartmentStats")
List<DepartmentStatsDTO> getDepartmentStatsMapped(@Param("p_dept_id") Long departmentId);
Characteristics:

Type-Safe: Returns strongly-typed List<DepartmentStatsDTO>
Cleaner Code: No need for manual result mapping
Maintainable: Field mappings are explicit in the DTO
Refactoring: Safer for refactoring (IDE can help with method/field renames)
Documentation: Better self-documenting code
Key Differences:
Aspect	@Query with Native Query	@Procedure with DTO
Return Type	List<Object[]> (raw)	List<DepartmentStatsDTO> (typed)
Type Safety	Low (runtime errors possible)	High (compile-time safety)
Code Readability	Lower (magic array indices)	Higher (named fields)
Refactoring	Error-prone	IDE-friendly
Performance	Slightly faster	Minimal overhead
Use Case	Quick prototyping, complex SQL	Production code, maintainable solutions
Example of Manual Mapping (First Approach):
java
List<Object[]> results = departmentRepository.getDepartmentStats(deptId);
results.forEach(row -> {
    String deptName = (String) row[0];
    Long employeeCount = (Long) row[1];
    // Manual mapping required
});
Example with DTO (Second Approach):
java
List<DepartmentStatsDTO> results = departmentRepository.getDepartmentStatsMapped(deptId);
results.forEach(dto -> {
    // Direct access to typed fields
    String deptName = dto.getDeptName();
    Long employeeCount = dto.getEmployeeCount();
});
When to Use Which:
Use @Query with Native Query when:
You need to execute complex SQL that's not easily mapped
You're prototyping or writing one-off queries
Performance is critical and you want to avoid ORM overhead
Use @Procedure with DTO when:
You're building production code
You want type safety and better maintainability
The result structure is well-defined
You want to leverage IDE support for refactoring
Best Practice:
For most production applications, the DTO-based approach (@Procedure with proper result mapping) is recommended because:

It's more maintainable
Catches errors at compile-time
Makes the code more self-documenting
Is easier to refactor
Provides better IDE support
The performance difference is usually negligible compared to the benefits of type safety and maintainability, especially in enterprise applications.


