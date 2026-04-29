-- ============================================
-- 游标存储过程：逾期图书催还清单
-- ============================================
CREATE PROCEDURE use_OverdueBooksCursor
AS
BEGIN
    DECLARE @lib_card_no VARCHAR(20);
    DECLARE @reg_no      VARCHAR(30);
    DECLARE @due_date    DATE;
    DECLARE @book_title  NVARCHAR(200);
    DECLARE @reader_name NVARCHAR(50);
    DECLARE @overdue_days INT;

    DECLARE overdue_cursor CURSOR FOR
        SELECT lib_card_no, reg_no, due_date
        FROM Borrow
        WHERE return_date IS NULL AND due_date < GETDATE();

    CREATE TABLE #overdue_result
    (
        book_title   NVARCHAR(200),
        reader_name  NVARCHAR(50),
        due_date     DATE,
        overdue_days INT
    );

    OPEN overdue_cursor;
    FETCH NEXT FROM overdue_cursor INTO @lib_card_no, @reg_no, @due_date;

    WHILE @@FETCH_STATUS = 0
    BEGIN
        SELECT @book_title = b.title
        FROM Copy c
        JOIN Book b ON c.book_id = b.book_id
        WHERE c.reg_no = @reg_no;

        SELECT @reader_name = name
        FROM Reader
        WHERE lib_card_no = @lib_card_no;

        SET @overdue_days = DATEDIFF(DAY, @due_date, GETDATE());

        INSERT INTO #overdue_result (book_title, reader_name, due_date, overdue_days)
        VALUES (ISNULL(@book_title, N'未知书名'), ISNULL(@reader_name, N'未知读者'), @due_date, @overdue_days);

        FETCH NEXT FROM overdue_cursor INTO @lib_card_no, @reg_no, @due_date;
    END

    CLOSE overdue_cursor;
    DEALLOCATE overdue_cursor;

    SELECT book_title   AS N'逾期图书',
           reader_name  AS N'借阅人',
           due_date     AS N'应还日期',
           overdue_days AS N'逾期天数'
    FROM #overdue_result
    ORDER BY overdue_days DESC;

    DROP TABLE #overdue_result;
END
GO