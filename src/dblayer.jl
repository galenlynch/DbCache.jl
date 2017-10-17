const Conn = ODBC.DSN
const Stmt = ODBC.Statement
execute!(args...) = ODBC.execute!(args...)
prepare(args...) = ODBC.prepare(args...)
query(args...) = ODBC.query(args...)

function transaction(f::Function, db::Conn)
    returnval = try
        execute!(db, "BEGIN;")
        returnval = f()
        execute!(db, "COMMIT;")
        returnval
    catch
        execute!(db, "ROLLBACK;")
        rethrow()
    end
    return returnval
end
