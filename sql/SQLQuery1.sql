-- ============================================
-- 图书管理系统数据库完整建表脚本
-- 适用 SQL Server 2014 及以上版本
-- ============================================

-- 如果数据库已存在则删除（可选，谨慎使用）
IF EXISTS (SELECT name FROM sys.databases WHERE name = 'LibraryDB')
BEGIN
    ALTER DATABASE LibraryDB SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
    DROP DATABASE LibraryDB;
END
GO

-- 创建数据库
CREATE DATABASE LibraryDB;
GO

USE LibraryDB;
GO

-- ============================================
-- 1. 操作员表（身份验证用）
-- ============================================
CREATE TABLE Operator (
    operator_id   VARCHAR(20)  PRIMARY KEY,
    name          NVARCHAR(50) NOT NULL,
    pwd           VARCHAR(50)  NOT NULL,   -- 实际项目应加密存储
    role          NVARCHAR(20) NOT NULL    -- 管理员 / 操作员
);
GO

-- ============================================
-- 2. 读者表 (使用 Unicode 避免中文截断)
-- ============================================
CREATE TABLE Reader (
    lib_card_no   VARCHAR(20)  PRIMARY KEY,
    name          NVARCHAR(50) NOT NULL,
    gender        NCHAR(1)     CHECK (gender IN (N'男', N'女')),
    birth_date    DATE,
    id_card       VARCHAR(18)  UNIQUE,
    unit          NVARCHAR(100),
    address       NVARCHAR(200),
    postcode      VARCHAR(10),
    phone         VARCHAR(20),
    reg_date      DATE         DEFAULT GETDATE(),
    borrow_area   NVARCHAR(50),
    max_books     INT          DEFAULT 5   CHECK (max_books > 0),
    borrow_days   INT          DEFAULT 30,
    photo         VARCHAR(200),
    occupation    NVARCHAR(50),
    status        NCHAR(2)     DEFAULT N'正常' CHECK (status IN (N'正常', N'注销'))
);
GO

-- ============================================
-- 3. 读者档案操作日志
-- ============================================
CREATE TABLE ReaderLog (
    log_id        INT IDENTITY(1,1) PRIMARY KEY,
    lib_card_no   VARCHAR(20)  NOT NULL,
    operator_id   VARCHAR(20)  NOT NULL,
    operation     NVARCHAR(20),       -- 办证/修改/注销
    op_date       DATETIME     DEFAULT GETDATE(),
    reason        NVARCHAR(200),
    approval      NVARCHAR(100),
    FOREIGN KEY (lib_card_no) REFERENCES Reader(lib_card_no),
    FOREIGN KEY (operator_id) REFERENCES Operator(operator_id)
);
GO

-- ============================================
-- 4. 图书主表
-- ============================================
CREATE TABLE Book (
    book_id       VARCHAR(20)  PRIMARY KEY,
    title         NVARCHAR(200) NOT NULL,
    author        NVARCHAR(100),
    publisher     NVARCHAR(100),
    pub_date      DATE,
    edition       INT,
    price         DECIMAL(10,2),
    summary       NVARCHAR(MAX),
    category_no   VARCHAR(30),
    call_no       VARCHAR(30),
    total_copies  INT          DEFAULT 0,
    location      NVARCHAR(50),
    storage_date  DATE
);
GO

-- ============================================
-- 5. 图书单册表（馆藏注册号）
-- ============================================
CREATE TABLE Copy (
    reg_no        VARCHAR(30)  PRIMARY KEY,
    book_id       VARCHAR(20)  NOT NULL,
    is_borrowed   BIT          DEFAULT 0,
    borrow_count  INT          DEFAULT 0,
    FOREIGN KEY (book_id) REFERENCES Book(book_id)
);
GO

-- ============================================
-- 6. 借书记录表
-- ============================================
CREATE TABLE Borrow (
    borrow_id     INT IDENTITY(1,1) PRIMARY KEY,
    lib_card_no   VARCHAR(20)  NOT NULL,
    reg_no        VARCHAR(30)  NOT NULL,
    borrow_date   DATE         NOT NULL,
    due_date      DATE         NOT NULL,
    return_date   DATE         NULL,
    operator_id   VARCHAR(20)  NOT NULL,
    FOREIGN KEY (lib_card_no) REFERENCES Reader(lib_card_no),
    FOREIGN KEY (reg_no) REFERENCES Copy(reg_no),
    FOREIGN KEY (operator_id) REFERENCES Operator(operator_id)
);
GO

-- ============================================
-- 7. 图书档案操作日志
-- ============================================
CREATE TABLE BookLog (
    log_id        INT IDENTITY(1,1) PRIMARY KEY,
    book_id       VARCHAR(20)  NOT NULL,
    operator_id   VARCHAR(20)  NOT NULL,
    operation     NVARCHAR(20),
    op_date       DATETIME     DEFAULT GETDATE(),
    reason        NVARCHAR(200),
    FOREIGN KEY (book_id) REFERENCES Book(book_id),
    FOREIGN KEY (operator_id) REFERENCES Operator(operator_id)
);
GO

-- ============================================
-- 索引（提高检索性能）
-- ============================================
CREATE INDEX idx_book_title ON Book(title);
CREATE INDEX idx_book_author ON Book(author);
CREATE INDEX idx_book_publisher ON Book(publisher);
CREATE INDEX idx_book_category ON Book(category_no);
CREATE INDEX idx_borrow_reader ON Borrow(lib_card_no);
CREATE INDEX idx_borrow_return ON Borrow(return_date);
CREATE INDEX idx_copy_book ON Copy(book_id);
CREATE INDEX idx_reader_name ON Reader(name);
GO

-- ============================================
-- 视图（只读查询，无需身份验证）
-- ============================================
CREATE VIEW v_available_copies AS
SELECT b.book_id, b.title, b.author, b.publisher, c.reg_no, b.location
FROM Book b
JOIN Copy c ON b.book_id = c.book_id
WHERE c.is_borrowed = 0;
GO

CREATE VIEW v_reader_borrow_history AS
SELECT r.lib_card_no, r.name AS reader_name, b.title, c.reg_no,
       br.borrow_date, br.due_date, br.return_date
FROM Borrow br
JOIN Reader r ON br.lib_card_no = r.lib_card_no
JOIN Copy c ON br.reg_no = c.reg_no
JOIN Book b ON c.book_id = b.book_id;
GO

CREATE VIEW v_borrowed_books AS
SELECT br.borrow_id, r.name AS reader_name, b.title, br.borrow_date, br.due_date
FROM Borrow br
JOIN Reader r ON br.lib_card_no = r.lib_card_no
JOIN Copy c ON br.reg_no = c.reg_no
JOIN Book b ON c.book_id = b.book_id
WHERE br.return_date IS NULL;
GO

-- ============================================
-- 测试数据
-- ============================================
INSERT INTO Operator (operator_id, name, pwd, role) VALUES 
('admin01', N'系统管理员', '123456', N'管理员'),
('op01', N'张借书', '123456', N'操作员');
GO

INSERT INTO Reader (lib_card_no, name, gender, id_card, max_books, status) VALUES
('R001', N'张三', N'男', '11010119900307663X', 5, N'正常'),
('R002', N'李四', N'女', '11010119950202888X', 3, N'正常'),
('R003', N'王小明', N'男', '11010120010315432X', 4, N'正常');
GO

INSERT INTO Book (book_id, title, author, publisher, total_copies, location) VALUES
('9787111111111', N'数据库系统概论', N'王珊', N'高等教育出版社', 3, N'书库A'),
('9787121123456', N'SQL Server从入门到精通', N'李华', N'清华大学出版社', 2, N'书库B'),
('9787302298899', N'Python编程从入门到实践', N'Eric Matthes', N'人民邮电出版社', 4, N'书库A');
GO

INSERT INTO Copy (reg_no, book_id, is_borrowed) VALUES
('CP001', '9787111111111', 0),
('CP002', '9787111111111', 0),
('CP003', '9787111111111', 0),
('CP004', '9787121123456', 0),
('CP005', '9787121123456', 0),
('CP006', '9787302298899', 0),
('CP007', '9787302298899', 0),
('CP008', '9787302298899', 0),
('CP009', '9787302298899', 0);
GO

PRINT '数据库 LibraryDB 创建成功，所有表、索引、视图和测试数据已就绪！';
GO