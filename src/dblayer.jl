const Conn = LibPQ.Connection
const Stmt = LibPQ.Statement
const Res = LibPQ.Result

execute(s::Stmt, params::Tuple; kwargs...) = execute(s, collect(params); kwargs...)
execute(args...) = LibPQ.execute(args...)

function fetch!(
    s::Stmt,
    vals::Union{AbstractVector, Tuple},
    args...;
    sink::Union{T, Type{T}} = NamedTuple,
    kwargs...
) where {T}
    result = execute(s, vals, args...; kwargs...)
    LibPQ.fetch!(sink, result)
end

prepare(args...) = LibPQ.prepare(args...)

num_rows(Res) = LibPQ.num_rows(Res)

function transaction(f::Function, db::Conn)
    returnval = try
        result = execute(db, "BEGIN;")
        close(result)
        returnval = f()
        execute(db, "COMMIT;")
        close(result)
        returnval
    catch y
        bt = catch_backtrace()
        result = execute(db, "ROLLBACK;")
        close(result)
        showerror(stderr, y)
        Base.show_backtrace(stderr, bt)
        rethrow(y)
    end
    return returnval
end
