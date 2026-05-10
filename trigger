-- ============================================================
-- PRACTICAL 6: Triggers and Cursors
-- Employee Management System
-- ============================================================

CREATE DATABASE IF NOT EXISTS EmployeeDB;
USE EmployeeDB;

-- ============================================================
-- TABLE SETUP
-- ============================================================

CREATE TABLE IF NOT EXISTS Employees (
    EmployeeID   INT PRIMARY KEY AUTO_INCREMENT,
    Name         VARCHAR(100) NOT NULL,
    Department   VARCHAR(100),
    Salary       DECIMAL(10,2),
    JoinDate     DATE,
    Email        VARCHAR(100)
);

-- Audit table to log all changes
CREATE TABLE IF NOT EXISTS Employee_Audit (
    AuditID    INT PRIMARY KEY AUTO_INCREMENT,
    EmployeeID INT,
    Action     VARCHAR(10),      -- INSERT, UPDATE, DELETE
    OldSalary  DECIMAL(10,2),
    NewSalary  DECIMAL(10,2),
    ChangedBy  VARCHAR(100) DEFAULT (USER()),
    ChangedAt  DATETIME DEFAULT CURRENT_TIMESTAMP
);

-- Sample data
INSERT INTO Employees (Name, Department, Salary, JoinDate, Email) VALUES
('Ravi Kumar',   'IT',      55000.00, '2020-06-01', 'ravi@company.com'),
('Priya Singh',  'HR',      42000.00, '2019-03-15', 'priya@company.com'),
('Amit Sharma',  'IT',      62000.00, '2018-09-01', 'amit@company.com'),
('Sunita Rao',   'Finance', 48000.00, '2021-01-10', 'sunita@company.com'),
('Vikram Patel', 'IT',      58000.00, '2017-05-20', 'vikram@company.com'),
('Meena Joshi',  'HR',      39000.00, '2022-08-01', 'meena@company.com'),
('Arjun Nair',   'Finance', 52000.00, '2020-12-01', 'arjun@company.com');

-- ============================================================
-- SECTION A: TRIGGERS
-- ============================================================

DELIMITER $$

-- TRIGGER 1: AFTER INSERT — log new employee additions
CREATE TRIGGER trg_after_insert_employee
AFTER INSERT ON Employees
FOR EACH ROW
BEGIN
    INSERT INTO Employee_Audit (EmployeeID, Action, NewSalary)
    VALUES (NEW.EmployeeID, 'INSERT', NEW.Salary);
END$$

-- TRIGGER 2: AFTER UPDATE — log salary or detail changes
CREATE TRIGGER trg_after_update_employee
AFTER UPDATE ON Employees
FOR EACH ROW
BEGIN
    INSERT INTO Employee_Audit (EmployeeID, Action, OldSalary, NewSalary)
    VALUES (NEW.EmployeeID, 'UPDATE', OLD.Salary, NEW.Salary);
END$$

-- TRIGGER 3: AFTER DELETE — log removed employees
CREATE TRIGGER trg_after_delete_employee
AFTER DELETE ON Employees
FOR EACH ROW
BEGIN
    INSERT INTO Employee_Audit (EmployeeID, Action, OldSalary)
    VALUES (OLD.EmployeeID, 'DELETE', OLD.Salary);
END$$

-- TRIGGER 4: BEFORE INSERT — Validate salary is positive
CREATE TRIGGER trg_before_insert_salary_check
BEFORE INSERT ON Employees
FOR EACH ROW
BEGIN
    IF NEW.Salary <= 0 THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Salary must be a positive value!';
    END IF;
END$$

-- TRIGGER 5: BEFORE UPDATE — prevent salary decrease
CREATE TRIGGER trg_before_update_no_decrease
BEFORE UPDATE ON Employees
FOR EACH ROW
BEGIN
    IF NEW.Salary < OLD.Salary THEN
        SIGNAL SQLSTATE '45000'
        SET MESSAGE_TEXT = 'Salary cannot be decreased!';
    END IF;
END$$

DELIMITER ;

-- ============================================================
-- TEST TRIGGERS
-- ============================================================

-- Test INSERT trigger
INSERT INTO Employees (Name, Department, Salary, JoinDate, Email)
VALUES ('Neha Gupta', 'IT', 47000.00, '2024-01-15', 'neha@company.com');

-- Test UPDATE trigger
UPDATE Employees SET Salary = 50000.00 WHERE Name = 'Neha Gupta';

-- Test DELETE trigger
DELETE FROM Employees WHERE Name = 'Neha Gupta';

-- View audit log
SELECT * FROM Employee_Audit ORDER BY ChangedAt DESC;

-- View all triggers
SHOW TRIGGERS;

-- ============================================================
-- SECTION B: CURSORS
-- Process salary increments for IT department employees
-- ============================================================

DELIMITER $$

-- Cursor 1: Give 10% salary increment to all IT dept employees
CREATE PROCEDURE ApplyITSalaryIncrement()
BEGIN
    DECLARE v_empID   INT;
    DECLARE v_name    VARCHAR(100);
    DECLARE v_salary  DECIMAL(10,2);
    DECLARE v_newSal  DECIMAL(10,2);
    DECLARE done      BOOLEAN DEFAULT FALSE;

    -- Declare the cursor
    DECLARE emp_cursor CURSOR FOR
        SELECT EmployeeID, Name, Salary
        FROM Employees
        WHERE Department = 'IT';

    -- Handler for end of cursor
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    -- Open the cursor
    OPEN emp_cursor;

    read_loop: LOOP
        -- Fetch one row at a time
        FETCH emp_cursor INTO v_empID, v_name, v_salary;

        IF done THEN
            LEAVE read_loop;
        END IF;

        -- Calculate 10% increment
        SET v_newSal = v_salary * 1.10;

        -- Apply the update
        UPDATE Employees SET Salary = v_newSal WHERE EmployeeID = v_empID;

        -- Optional: print what happened (use SELECT for visibility)
        SELECT CONCAT('Updated ', v_name, ': ', v_salary, ' → ', v_newSal) AS UpdateLog;
    END LOOP;

    -- Close the cursor
    CLOSE emp_cursor;

    SELECT 'IT Department salary increment of 10% applied!' AS Status;
END$$

-- Cursor 2: Process salary increments based on experience
-- > 5 years = 15% increment, 3-5 years = 10%, < 3 years = 5%
CREATE PROCEDURE ApplyExperienceBasedIncrement()
BEGIN
    DECLARE v_empID   INT;
    DECLARE v_name    VARCHAR(100);
    DECLARE v_salary  DECIMAL(10,2);
    DECLARE v_join    DATE;
    DECLARE v_years   INT;
    DECLARE v_pct     DECIMAL(5,2);
    DECLARE done      BOOLEAN DEFAULT FALSE;

    DECLARE exp_cursor CURSOR FOR
        SELECT EmployeeID, Name, Salary, JoinDate
        FROM Employees;

    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = TRUE;

    OPEN exp_cursor;

    exp_loop: LOOP
        FETCH exp_cursor INTO v_empID, v_name, v_salary, v_join;

        IF done THEN LEAVE exp_loop; END IF;

        -- Calculate years of experience
        SET v_years = TIMESTAMPDIFF(YEAR, v_join, CURDATE());

        -- Determine increment percentage
        IF v_years > 5 THEN
            SET v_pct = 0.15;
        ELSEIF v_years >= 3 THEN
            SET v_pct = 0.10;
        ELSE
            SET v_pct = 0.05;
        END IF;

        -- Apply increment
        UPDATE Employees
        SET Salary = Salary * (1 + v_pct)
        WHERE EmployeeID = v_empID;

        SELECT CONCAT(v_name, ' (', v_years, ' yrs) → ',
               ROUND(v_pct * 100), '% increment') AS IncrementLog;
    END LOOP;

    CLOSE exp_cursor;
    SELECT 'Experience-based increment applied!' AS Status;
END$$

DELIMITER ;

-- ============================================================
-- CALL CURSORS
-- ============================================================

-- View salaries before
SELECT EmployeeID, Name, Department, Salary FROM Employees ORDER BY Department;

-- Apply IT increment
CALL ApplyITSalaryIncrement();

-- View salaries after
SELECT EmployeeID, Name, Department, Salary FROM Employees ORDER BY Department;

-- View audit log after trigger fires from cursor updates
SELECT * FROM Employee_Audit ORDER BY ChangedAt DESC LIMIT 10;

-- Apply experience-based increment
CALL ApplyExperienceBasedIncrement();

-- Final salary view
SELECT EmployeeID, Name, Department, Salary FROM Employees ORDER BY Salary DESC;
