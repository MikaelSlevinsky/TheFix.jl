module TheFix
    using REPL

    function cleanse(expr; safe::Bool=true)
        return expr
    end

    function cleanse(expr::Symbol; safe::Bool = true)
        try
            Main.eval(expr)
        catch ex
            expr = replace(expr, ex; safe = safe)
        end
        return expr
    end

    function cleanse(expr::Expr; safe::Bool=true)
        start = expr.head == :(=) && expr.args[1] isa Symbol ? 2 : 1
        for i in start:length(expr.args)
            expr.args[i] = cleanse(expr.args[i]; safe = safe)
        end
        try
            Main.eval(expr)
        catch ex
            expr = replace(expr, ex; safe = safe)
        end
        return expr
    end

    function replace(expr::Symbol, ex::UndefVarError; safe::Bool=true)
        if !(first(string(expr)) == '.' && isdefined(Main, Symbol(string(expr)[2:end])))
            possibilities = REPL.levsort(String(ex.var), REPL.accessible(Main))
            if safe
                i = 1
                while i ≤ min(length(possibilities), 3)
                    if i == 1
                        @info "Couldn't find $(ex.var). Did you mean $(possibilities[i])?"
                    else
                        @info "Did you mean $(possibilities[i])?"
                    end
                    answer = lowercase(strip(readline(stdin)))
                    if isempty(answer) || answer == "y" || answer == "yes"
                        expr = Meta.parse(possibilities[i])
                        break
                    elseif answer == "n" || answer == "no"
                        i += 1
                    else
                        println(stdout, "Unrecognized answer. Answer `y` or `n`.")
                    end
                end
                if i > min(length(possibilities), 3)
                    @info "Couldn't find a fix. What did you mean?"
                    expr = Meta.parse(strip(readline(stdin)))
                end
            else
                expr = Meta.parse(first(possibilities))
            end
            @info "Fixing $ex with $expr."
        end
        return expr
    end

    function replace(expr::Expr, ex::DomainError; safe::Bool=true)
        if occursin("complex", ex.msg) || occursin("NaN result for non-NaN input.", ex.msg)
            for (i, arg) in enumerate(expr.args)
                if Main.eval(arg) isa Number && Main.eval(arg) == ex.val
                    expr.args[i] = :(Complex($arg))
                elseif arg isa Expr
                    if arg.head == :tuple
                        for (j, argt) in enumerate(arg.args)
                            if any(x -> x == ex.val, Main.eval(argt))
                                arg.args[j] = :(Complex.($argt))
                            end
                        end
                    end
                end
            end
            @info "Fixing $ex with $expr."
        elseif occursin("negative power", ex.msg)
            for (i, arg) in enumerate(expr.args)
                if arg == :(.^) || i == 1
                    continue
                elseif Main.eval(arg) isa Number && Main.eval(arg) == ex.val
                    expr.args[i] = :(float($arg))
                elseif Main.eval(arg) isa AbstractArray && any(x -> x == ex.val, Main.eval(arg))
                    expr.args[i] = :(float.($arg))
                elseif Main.eval(arg) isa Tuple && any(x -> x == ex.val, Main.eval(arg))
                    expr.args[i] = :(float.($arg))
                end
            end
            @info "Fixing $ex with $expr."
        else
            @warn "Exception $ex not implemented."
        end
        return expr
    end

    function replace(expr::Expr, ex::OverflowError; safe::Bool=true)
        if occursin("factorial", ex.msg)
            for (i, arg) in enumerate(expr.args)
                if Main.eval(arg) isa Integer
                    expr.args[i] = :(big($arg))
                elseif arg isa Expr
                    if arg.head == :tuple
                        for (j, argt) in enumerate(arg.args)
                            arg.args[j] = :(big.($argt))
                        end
                    end
                end
            end
            @info "Fixing $ex with $expr."
        elseif occursin("gcd", ex.msg)
            for (i, arg) in enumerate(expr.args)
                if Main.eval(arg) isa Integer
                    expr.args[i] = :(widen($arg))
                elseif arg isa Expr
                    if arg.head == :tuple
                        for (j, argt) in enumerate(arg.args)
                            arg.args[j] = :(widen.($argt))
                        end
                    end
                end
            end
            @info "Fixing $ex with $expr."
        elseif occursin("checked", ex.msg) || occursin("overflow", ex.msg)
            for (i, arg) in enumerate(expr.args)
                if Main.eval(arg) isa Integer || Main.eval(arg) isa Rational
                    expr.args[i] = :(widen($arg))
                elseif Main.eval(arg) isa AbstractArray
                    expr.args[i] = :(widen.($arg))
                elseif arg isa Expr
                    if arg.head == :tuple
                        for (j, argt) in enumerate(arg.args)
                            arg.args[j] = :(widen.($argt))
                        end
                    end
                end
            end
            @info "Fixing $ex with $expr."
        else
            @warn "Exception $ex not implemented."
        end
        return expr
    end

    function replace(expr::Expr, ex::DivideError; safe::Bool=true)
        for (i, arg) in enumerate(expr.args)
            if arg == :div
                while length(expr.args) > 3
                    pop!(expr.args)
                end
                expr.args[i] = :(/)
            elseif arg == :(÷) || arg == :cld || arg == :fld
                expr.args[i] = :(/)
            elseif arg == :rem || arg == :mod
                if length(expr.args) > 3
                    x = expr.args[2]
                    y = expr.args[3]
                    r = expr.args[4]
                    expr = :($x - $y*round($x/$y, $r))
                    break
                else
                    x = expr.args[2]
                    y = expr.args[3]
                    expr = :($x - $y*($x/$y))
                    break
                end
            elseif arg == :(%)
                x = expr.args[2]
                y = expr.args[3]
                expr = :($x - $y*($x/$y))
                break
            elseif arg == :divrem
                if length(expr.args) > 3
                    x = expr.args[2]
                    y = expr.args[3]
                    r = expr.args[4]
                    expr = :(($x/$y, $x - $y*round($x/$y, $r)))
                    break
                else
                    x = expr.args[2]
                    y = expr.args[3]
                    expr = :(($x/$y, $x - $y*($x/$y)))
                    break
                end
            end
        end
        @info "Fixing $ex with $expr."
        return expr
    end

    function replace(expr::Expr, ex::BoundsError; safe::Bool=true)
        if length(expr.args) == 2
            arg1 = expr.args[1]
            arg2 = expr.args[2]
            if Main.eval(arg2) isa Integer
                expr.args[2] = :(clamp($arg2, extrema(eachindex($arg1))...))
            elseif Main.eval(arg2) isa AbstractUnitRange
                expr.args[2] = :(intersect($arg2, eachindex($arg1)))
            end
        else
            arg1 = expr.args[1]
            for i in 2:length(expr.args)
                argi = expr.args[i]
                l, r = Main.eval(:(extrema(axes($arg1, $(i-1)))))
                idx = Main.eval(argi)
                if idx isa Integer
                    if first(idx) < l || last(idx) > r
                        expr.args[i] = :(clamp($argi, extrema(axes($arg1, $(i-1)))...))
                    end
                elseif idx isa AbstractUnitRange
                    if first(idx) < l || last(idx) > r
                        expr.args[i] = :(intersect($argi, axes($arg1, $(i-1))))
                    end
                end
            end
        end
        @info "Fixing $ex with $expr."
        return expr
    end

    function replace(expr, ex::Exception; safe::Bool=true)
        @warn "Exception $ex not implemented."
        return expr
    end

    function display_error(io::IO, stack::Base.ExceptionStack)
        printstyled(io, "ERROR: "; bold=true, color=Base.error_color())
        bt = Any[ (x[1], Base.scrub_repl_backtrace(x[2])) for x in stack ]
        Base.show_exception_stack(IOContext(io, :limit => true), bt)
    end

    """
        TheFix.@safeword(fix, safe)

    Create a safe word `fix` that may be used to correct common errors in the REPL.
    This creates a struct `fix` with no fields and the fix occurs by showing it.
    The Boolean variable `safe` indicates whether or not the user requests confirmation.

    # Examples
    ```jldoctest
    julia> TheFix.@safeword fix true

    julia> sine(4)
    ERROR: UndefVarError: sine not defined
    Stacktrace:
     [1] top-level scope at REPL[3]:1

    julia> fix
    [ Info: Couldn't find sine. Did you mean sin?
    y
    [ Info: Fixing UndefVarError(:sine) with sin.

    julia> sin(4)
    -0.7568024953079282

    julia> TheFix.@safeword FIX false

    julia> logarithm(3)
    ERROR: UndefVarError: logarithm not defined
    Stacktrace:
     [1] top-level scope at REPL[7]:1

    julia> FIX
    [ Info: Fixing UndefVarError(:logarithm) with log.

    julia> log(3)
    1.0986122886681098
    ```
    """
    macro safeword(fix, safe)
        return esc(quote
            export $fix

            struct $fix end

            function Base.show(io::IO, f::Type{$fix})
                file = open(TheFix.REPL.find_hist_file(), read = true, write = true)
                str = read(file, String)
                itr = findlast("# mode: julia", str)
                itr = findprev("# mode: julia", str, first(itr))
                nxt = itr[end] + 3
                lst = first(findnext("# time:", str, nxt)) - 2
                expr = TheFix.cleanse(Meta.parse(str[nxt:lst]); safe = $safe)
                try
                    printstyled(io, "\n"*TheFix.REPL.JULIA_PROMPT, bold=true; color=202)
                    println(io, string(expr))
                    show(io, "text/plain", Main.eval(expr))
                    hist = Base.active_repl.mistate.current_mode.hist
                    !isempty(hist.history) && isequal(:julia, last(hist.modes)) && string(expr) == last(hist.history) && return
                    push!(hist.modes, :julia)
                    push!(hist.history, string(expr))
                    TheFix.REPL.history_reset_state(hist)
                    entry = """
                    # time: $(Libc.strftime("%Y-%m-%d %H:%M:%S %Z", time()))
                    # mode: julia
                    $(replace(string(expr), r"^"ms => "\t"))
                    """
                    seekend(file)
                    print(file, entry)
                    flush(file)
                catch ex
                    Base.invokelatest(TheFix.display_error, io, current_exceptions())
                end
            end
        end)
    end
end # module
