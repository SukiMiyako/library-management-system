-- ============================================
-- 触发器：借书时自动写入 ReaderLog
-- ============================================
CREATE TRIGGER trg_AfterBorrow
ON Borrow
AFTER INSERT
AS
BEGIN
    INSERT INTO ReaderLog (lib_card_no, operator_id, operation, op_date)
    SELECT lib_card_no, operator_id, N'借书', GETDATE()
    FROM inserted;
END
GO