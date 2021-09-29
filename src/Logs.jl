module Logs

import DataFrames: DataFrame
import OrderedCollections: OrderedDict
import ..ARLToolkit: dts

struct LogFormat
  delimiter::Char
  columns::AbstractVector{Pair{Symbol,Any}}
end

const UnetLogs = LogFormat('|', [
  :time => s -> dts(parse(Int64, s)/1000),
  :level => Symbol,
  :source => string,
  :text => string
])

function read(filename, fmt, filters=nothing; limit=nothing)
  df = DataFrame()
  for (lno, line) ∈ enumerate(eachline(filename))
    cols = split(line, fmt.delimiter)
    length(cols) == length(fmt.columns) || continue
    entry = NamedTuple(first(key) => last(key)(value) for (key, value) ∈ zip(fmt.columns, cols))
    if filters !== nothing
      filters isa AbstractVector || (filters = [filters])
      for f1 ∈ filters
        rv = f1(entry)
        if rv isa NamedTuple
          entry = rv
        elseif rv === nothing || rv === false
          entry = nothing
          break
        elseif rv !== true
          throw(ErrorException("Bad return value from filter: $rv"))
        end
      end
      entry === nothing && continue
    end
    push!(df, entry; cols=:union)
    limit !== nothing && size(df, 1) ≥ limit && break
  end
  df
end

function Message(clazz)
  e -> begin
    m = match(r"^(.+): ?\w+ ?\[(.*)\]:? ?(.*)$", e.text)
    m === nothing && return
    m[1] == clazz || return
    data = OrderedDict(pairs(e))
    delete!(data, :text)
    data[:clazz] = clazz
    for kv ∈ split(m[2], ' ')
      if contains(kv, ':')
        k, v = split(kv, ':')
        try
          v = parse(Int, v)
        catch
          try
            v = parse(Float64, v)
          catch
            # its ok
          end
        end
        data[Symbol(k)] = v
      else
        break
      end
    end
    m[3] === nothing || m[3] == "" || (data[:extra] = m[3])
    NamedTuple(data)
  end
end

end # module
