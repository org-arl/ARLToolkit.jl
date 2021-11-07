import JLD2
import FileIO
import Geodesy: LLA, euclidean_distance, ENUfromLLA, wgs84, LLAfromENU, ENU
import Printf: @printf
import Dates: Dates, unix2datetime, DateTime
import TimeZones: localzone, ZonedDateTime, astimezone, @tz_str
import DataFrames: DataFrame, leftjoin
import OrderedCollections: OrderedDict

export cached, AOI, distance, minute, minutes, second, seconds, dts, @dts_str, xleftjoin, closest
export LLA, ZonedDateTime, geo2pos, pos2geo

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

# set environment variable GEOAPIFY_APIKEY to auto-download maps (see https://www.geoapify.com)
# see https://apidocs.geoapify.com/docs/maps/map-tiles/ for list of available styles

function AOI(topleft::LLA{Float64}, bottomright::LLA{Float64}; style="osm-bright", width=1024)
  mapimg = nothing
  if "GEOAPIFY_APIKEY" ∈ keys(ENV)
    apikey = ENV["GEOAPIFY_APIKEY"]
    lat1, lon1, lat2, lon2 = topleft.lat, topleft.lon, bottomright.lat, bottomright.lon
    height = round(Int, width * abs(lat2 - lat1) / abs(lon2 - lon1))
    try
      cachedir = joinpath(tempdir(), "arltoolkit", "cache")
      filename = joinpath(cachedir, "map-$style-$lon1-$lat1-$lon2-$lat2-$width-$height.png")
      if !isfile(filename)
        mkpath(cachedir)
        download("https://maps.geoapify.com/v1/staticmap?style=$style&format=png&" *
          "area=rect:$lon1,$lat1,$lon2,$lat2&width=$width&height=$height&apiKey=$apikey",
          filename)
      end
      mapimg = FileIO.load(filename)
    catch ex
      @warn "Could not download map: $ex"
    end
  end
  AOI(topleft, bottomright, mapimg)
end

function Base.in(x::LLA, aoi::AOI)
  (x.lat < aoi.bottomright.lat || x.lat > aoi.topleft.lat) && return false
  (x.lon < aoi.topleft.lon || x.lon > aoi.bottomright.lon) && return false
  true
end

distance(p1::LLA, p2::LLA) = euclidean_distance(p1, p2)

function prettyprint(io::IO, x::LLA)
  @printf(io, "%0.6f°%c %0.6f°%c", abs(x.lat), x.lat < 0 ? 'S' : 'N', abs(x.lon), x.lon < 0 ? 'W' : 'E')
  iszero(x.alt) || @printf(io, " %+0.3fm", x.alt)
end

"""
    geo2pos(geo::LLA, origin::LLA)

Convert latitude/longitude to local coordinates. If altitude information
is non-zero, the returned position vector is a 3-vector, otherwise a 2-vector.
"""
function geo2pos(geo::LLA, origin::LLA)
  pos = ENUfromLLA(origin, wgs84)(geo)[1:3]
  geo.alt == 0.0 && (pos = pos[1:2])
  pos
end

"""
    pos2geo(pos::AbstractArray{<:Real}, origin::LLA)

Convert local coordinates to latitude/longitude. The input may be a 2-vector
or a 3-vector. If the input is a 2-vector, the altitude is assumed to be zero.
"""
function pos2geo(pos::AbstractArray{<:Real}, origin::LLA)
  length(pos) == 2 && (pos = vcat(pos, zero(eltype(pos))))
  length(pos) == 3 || throw(ArgumentError("Bad position vector"))
  LLAfromENU(origin, wgs84)(ENU(pos))
end

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
