USE [LibraryDB]
GO
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[use_ReturnBook]
    @copy_reg_no VARCHAR(30),
    @operator_id VARCHAR(20)
AS
BEGIN
    DECLARE @borrow_id INT;
    DECLARE @is_borrowed BIT;

    -- 1. 检查图书单册是否存在
    SELECT @is_borrowed = is_borrowed
    FROM Copy
    WHERE reg_no = @copy_reg_no;

    IF @is_borrowed IS NULL
    BEGIN
        RAISERROR('图书单册不存在', 16, 1);
        RETURN;
    END

    -- 2. 检查图书是否处于借出状态（防御数据不一致）
    IF @is_borrowed = 0
    BEGIN
        RAISERROR('该书未被借出', 16, 1);
        RETURN;
    END

    -- 3. 找到未还的借书记录（UPDLOCK 防止并发修改）
    SELECT @borrow_id = borrow_id
    FROM Borrow WITH (UPDLOCK)
    WHERE reg_no = @copy_reg_no AND return_date IS NULL;

    IF @borrow_id IS NULL
    BEGIN
        RAISERROR('未找到对应的借书记录', 16, 1);
        RETURN;
    END

    -- 4. 核心还书操作
    BEGIN TRANSACTION;
    BEGIN TRY
        UPDATE Borrow
        SET return_date = GETDATE()
        WHERE borrow_id = @borrow_id;

        UPDATE Copy
        SET is_borrowed = 0
        WHERE reg_no = @copy_reg_no;

        COMMIT TRANSACTION;
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;
        THROW;
    END CATCH
END
GO