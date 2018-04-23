const Conn = LibPQ.Connection
const Stmt = LibPQ.Statement
const Res = LibPQ.Result

execute(s::Stmt, params::Tuple; kwargs...) = execute(s, collect(params); kwargs...)
execute(args...) = LibPQ.execute(args...)

prepare(args...) = LibPQ.prepare(args...)

num_rows(Res) = LibPQ.num_rows(Res)

function transaction(f::Function, db::Conn)
    returnval = try
        result = execute(db, "BEGIN;")
        clear!(result)
        returnval = f()
        execute(db, "COMMIT;")
        clear!(result)
        returnval
    catch
        result = execute(db, "ROLLBACK;")
        clear!(result)
        rethrow()
    end
    return returnval
end
