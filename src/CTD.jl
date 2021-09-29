module CTD

import DataFrames: DataFrame, DataFrameRow
import TimeZones: ZonedDateTime
import Dates: Second
import ..ARLToolkit: dts

function read(filename; mindepth=1.0, minmaxdepth=5.0)
  df = DataFrame(
    time = ZonedDateTime[],
    maxdepth = Float64[],
    lno = UnitRange{Int}[],
    filename = String[])
  t0 = nothing
  Δt = 2
  start = 0
  n0 = 0
  maxp = 0.0
  for (lno, line) ∈ enumerate(eachline(filename))
    m = match(r"^Date (.*) Time (.*) GMT Interval: (\d+)sec", line)
    if m !== nothing
      t0 = dts("20" * m[1] * " " * m[2]; format="yyyy-mm-dd HH-MM-SS")
      Δt = parse(Int, m[3])
      n0 = 0
      continue
    end
    m = match(r"^N(\d+) C(.+) T(.+) P(.+) c(.+)$", line)
    if m !== nothing
      n = parse(Int, m[1])
      n0 == 0 && (n0 = n)
      C = parse(Float64, m[2])
      p = parse(Float64, m[4])
      maxp = max(p, maxp)
      if p > mindepth && C > 1.0
        if start == 0
          start = lno
          maxp = 0.0
        end
      else
        if start > 0 && maxp > minmaxdepth
          push!(df, (t0 + Second(Δt * (n-n0)), maxp, start:(lno-1), filename))
          start = 0
        end
      end
      continue
    end
  end
  df
end

read(filenames::AbstractVector) = sort!(vcat(read.(f)...), :time)

function read(row::DataFrameRow)
  df = DataFrame(
    n = Int[],
    conductivity = Float64[],
    temperature = Float64[],
    depth = Float64[],
    soundspeed = Float64[])
  for (lno, line) ∈ enumerate(eachline(row.filename))
    lno ∈ row.lno || continue
    m = match(r"^N(\d+) C(.+) T(.+) P(.+) c(.+)$", line)
    if m !== nothing
      n = parse(Int, m[1])
      C = parse(Float64, m[2])
      T = parse(Float64, m[3])
      D = parse(Float64, m[4])
      c = parse(Float64, m[5])
      push!(df, (n, C, T, D, c))
    end
  end
  df
end

read(df::DataFrame, n) = read(df[n,:])

end # module
