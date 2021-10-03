import JLD2
import Geodesy: LLA, euclidean_distance
import Printf: @printf
import Plots: @recipe, @series, RecipesBase
import Dates: Dates, unix2datetime, DateTime
import TimeZones: localzone, ZonedDateTime, astimezone, @tz_str
import DataFrames: DataFrame, leftjoin
import OrderedCollections: OrderedDict

export cached, AOI, distance, minute, minutes, second, seconds, dts, @dts_str, xleftjoin, closest
export LLA, ZonedDateTime

### caching with JLD2 files

function cached(f, filename)
  if isfile(filename)
    return JLD2.jldopen(filename) do f
      JLD2.read(f, "df")
    end
  else
    df = f()
    JLD2.@save filename df
    return df
  end
end

### Geodesy utils

struct AOI{T}
  topleft::LLA{Float64}
  bottomright::LLA{Float64}
  mapimg::T
end

AOI(topleft::LLA{Float64}, bottomright::LLA{Float64}) = AOI(topleft, bottomright, nothing)

@recipe function plot(x::AOI{T}) where T
  tl = (x.topleft.lon, x.topleft.lat)
  br = (x.bottomright.lon, x.bottomright.lat)
  mapimg = x.mapimg
  size --> (1086,610)
  yflip --> false
  xlims --> (tl[1], br[1])
  ylims --> (br[2], tl[2])
  framestyle --> :none
  ticks --> nothing
  @series begin
    seriestype := :image
    range(tl[1], br[1]; length=size(mapimg,1)),
    range(tl[2], br[2]; length=size(mapimg,2)),
    mapimg[end:-1:1,:]
  end
end

@recipe function plot(x::Vector{LLA{T}}) where T
  @series begin
    [v.lon for v ∈ x], [v.lat for v ∈ x]
  end
end

@recipe function plot(x::LLA{T}) where T
  @series begin
    [x.lon], [x.lat]
  end
end

function Base.in(x::LLA, aoi::AOI)
  (x.lat < aoi.bottomright.lat || x.lat > aoi.topleft.lat) && return false
  (x.lon < aoi.topleft.lon || x.lon > aoi.bottomright.lon) && return false
  true
end

distance(p1::LLA, p2::LLA) = euclidean_distance(p1, p2)

prettyprint(io::IO, x::LLA) = @printf(io, "%0.6f°%c %0.6f°%c", abs(x.lat), x.lat < 0 ? 'S' : 'N', abs(x.lon), x.lon < 0 ? 'W' : 'E')

### datetime conversions

const minute = Dates.Minute(1)
const second = Dates.Second(1)
const minutes = minute
const seconds = second

function dts(yyyy, mm, dd, HH, MM, SS; tz=localzone())
  t = ZonedDateTime(yyyy, mm, dd, HH, MM, SS, tz"UTC")
  astimezone(t, tz)
end

function dts(s::String; tz=localzone(), format="yyyy-mm-dd HH:MM:SS")
  ZonedDateTime(DateTime(s, format), tz)
end

function dts(t; tz=localzone())
  t = ZonedDateTime(unix2datetime(t), tz"UTC")
  astimezone(t, tz)
end

macro dts_str(s)
  dts(s)
end

Base.isapprox(t1::ZonedDateTime, t2::ZonedDateTime; atol=10seconds) = abs(t2 - t1) ≤ atol

function prettyprint(io::IO, x::ZonedDateTime)
  zone = x.zone.offset.std.value == 28800 ? "SGT" : string(x.zone)
  print(io, Dates.format(x, "yyyy-mm-dd HH:MM:SS"), " ", zone)
end

### dataframe join utils

function closest(a, b; atol=Inf64)
  Δab = abs.(a .- b)
  ndx = argmin(Δab)
  Δab[ndx] ≤ atol && return ndx
  nothing
end

closest(; atol) = (a, b) -> closest(a, b; atol)

function xleftjoin(df1, df2, on, cols; compare=isequal, find=(a, b)->findfirst((compare).(a, b)))
  df3 = DataFrame()
  for row1 ∈ eachrow(df1)
    ndx = find(row1[on], df2[!,on])
    if ndx !== nothing
      data = OrderedDict{Symbol,Any}(pairs(df2[ndx,cols]))
      data[:__key] = row1[on]
      push!(df3, data; cols=:union)
    end
  end
  leftjoin(df1, df3; on = on=>:__key)
end
