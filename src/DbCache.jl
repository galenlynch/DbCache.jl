__precompile__()
module DbCache
using ODBC, Compat

export
    # types
    Conn,
    Stmt,
    DBCache,
    IDType,
    IDDimensionType,

    # macros
    @idinstance,
    @iddimension,

    # functions
    execute!,
    prepare,
    query,
    transaction,
    id_check,
    load!,
    id!,
    stmt,
    select_vals,
    insert_vals,
    prepare_error

# package code goes here
include("dblayer.jl")
include("dbcache.jl")

end # module
