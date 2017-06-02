const Conn = ODBC.DSN
const Stmt = ODBC.Statement
execute!(args...) = ODBC.execute!(args...)
prepare(args...) = ODBC.prepare(args...)
query(args...) = ODBC.query(args...)

function transaction(f::Function, db::Conn)
    try
        execute!(db, "BEGIN;")
        f()
        execute!(db, "COMMIT;")
    catch
        execute!(db, "ROLLBACK;")
        rethrow()
    end
end
