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

function transaction(f::Function, db::Conn; top_level = true)
    if top_level
        returnval = try
            close(execute(db, "BEGIN;"))
            returnval = f()
            close(execute(db, "COMMIT;"))
            returnval
        catch err
            close(execute(db, "ROLLBACK;"))
            rethrow(err)
        end
    else
        returnval = f()
    end
    return returnval
end
