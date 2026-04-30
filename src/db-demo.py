import pyodbc

# 连接 SQL Server（根据你的实际环境修改）
conn = pyodbc.connect(
    'DRIVER={ODBC Driver 17 for SQL Server};'
    'SERVER=.\\SQLEXPRESS;'            # 改成 .\SQLEXPRESS 或者你的服务器名
    'DATABASE=LibraryDB;'
    'TRUSTED_CONNECTION=yes;'      # Windows认证
)

cursor = conn.cursor()

# 1. 测试借书
print("=== 测试借书 ===")
try:
    cursor.execute("EXEC use_BorrowBook ?, ?, ?", 'R001', 'C001', 'OP01')
    conn.commit()
    print("借书成功")
except Exception as e:
    print(f"借书失败: {e}")

# 2. 测试还书
print("\n=== 测试还书 ===")
try:
    cursor.execute("EXEC use_ReturnBook ?, ?", 'C001', 'OP01')
    conn.commit()
    print("还书成功")
except Exception as e:
    print(f"还书失败: {e}")

# 3. 查询借书记录
print("\n=== 最新借书记录 ===")
cursor.execute("SELECT TOP 3 * FROM Borrow ORDER BY borrow_id DESC")
for row in cursor.fetchall():
    print(row)

cursor.close()
conn.close()