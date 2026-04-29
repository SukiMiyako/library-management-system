USE [LibraryDB]
GO
    /****** 对象:  StoredProcedure [dbo].[use_BorrowBook]    脚本日期: 2026/4/29 19:19:03 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO ALTER PROCEDURE [dbo].[use_BorrowBook] @reader_card_no VARCHAR(20),
    @copy_reg_no VARCHAR(30),
    @operator_id VARCHAR(20) AS BEGIN -- 声明变量（类型与真实字段匹配）
DECLARE @reader_status NCHAR(4);
DECLARE @max_books INT;
DECLARE @borrow_area NVARCHAR(100);
DECLARE @borrow_days INT;
DECLARE @is_borrowed BIT;
DECLARE @book_location NVARCHAR(100);
DECLARE @current_count INT;
-- 1. 查询读者信息
SELECT @reader_status = status,
    @max_books = ISNULL(max_books, 5),
    @borrow_area = borrow_area,
    @borrow_days = ISNULL(borrow_days, 30)
FROM Reader
WHERE lib_card_no = @reader_card_no;
IF @reader_status IS NULL
OR @reader_status <> N'正常' BEGIN RAISERROR('读者不存在或已注销', 16, 1);
RETURN;
END -- 2. 查询图书单册状态及位置
SELECT @is_borrowed = c.is_borrowed,
    @book_location = b.location
FROM Copy c
    JOIN Book b ON c.book_id = b.book_id
WHERE c.reg_no = @copy_reg_no;
IF @is_borrowed IS NULL BEGIN RAISERROR('图书单册不存在', 16, 1);
RETURN;
END IF @is_borrowed = 1 BEGIN RAISERROR('该图书已被借出', 16, 1);
RETURN;
END -- 3. 检查书库匹配
IF @borrow_area <> @book_location BEGIN RAISERROR('读者无权借阅该书库的图书', 16, 1);
RETURN;
END -- 4. 统计当前已借未还册数
SELECT @current_count = COUNT(*)
FROM Borrow
WHERE lib_card_no = @reader_card_no
    AND return_date IS NULL;
IF @current_count >= @max_books BEGIN RAISERROR('已达到最大借书册数', 16, 1);
RETURN;
END -- 5. 执行借书
BEGIN TRANSACTION;
BEGIN TRY
INSERT INTO Borrow (
        lib_card_no,
        reg_no,
        borrow_date,
        due_date,
        operator_id
    )
VALUES (
        @reader_card_no,
        @copy_reg_no,
        GETDATE(),
        DATEADD(DAY, @borrow_days, GETDATE()),
        @operator_id
    );
UPDATE Copy
SET is_borrowed = 1,
    borrow_count = borrow_count + 1
WHERE reg_no = @copy_reg_no;
COMMIT TRANSACTION;
END TRY BEGIN CATCH ROLLBACK TRANSACTION;
THROW;
END CATCH
END