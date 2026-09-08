# KML/KMZ reader producing DataFrames in the same shape as GPXFile.read

module KML

import EzXML, ZipFile
import DataFrames: DataFrame, insertcols!
import Geodesy: LLA
import TimeZones: ZonedDateTime, FixedTimeZone, astimezone, localzone
import PooledArrays: PooledArray
import Dates: DateTime, Millisecond

const CONTAINERS = ("kml", "Document", "Folder", "Placemark", "MultiGeometry")
const TIME_RE = r"^(\d{4})(?:-(\d\d))?(?:-(\d\d))?(?:T(\d\d):(\d\d)(?::(\d\d)(?:\.(\d+))?)?)?(Z|[+-]\d\d:?\d\d)?$"

"""
    read(filename; tz=localzone())

Read a KML or KMZ file (or all such files in a directory) into a DataFrame with
columns `time`, `location`, `name` and `filename`. Each Placemark geometry
(`Point`, `LineString` or `gx:Track`) becomes a segment; when a file has more
than one segment a `segment_index` column is added. Times are converted to `tz`
and are `missing` where the file carries none.
"""
function read(filename; tz=localzone())
  if isdir(filename)
    filenames = filter(f -> occursin(r"\.km[lz]$", lowercase(f)), readdir(filename; join=true))
    return read(filenames; tz)
  end
  doc = endswith(lowercase(filename), ".kmz") ? read_kmz(filename) : EzXML.readxml(filename)
  segments = DataFrame[]
  collect_segments!(segments, EzXML.root(doc), missing, missing; filename, tz)
  isempty(segments) && throw(ErrorException("No track, path or point in KML file"))
  length(segments) == 1 && return segments[1]
  combine_segments(segments)
end

"""
    read(filenames::AbstractVector; tz=localzone())

Read several KML/KMZ files into one DataFrame, sorted by `time` when every row
has one.
"""
function read(filenames::AbstractVector; tz=localzone())
  df = vcat(read.(filenames; tz)...; cols=:union)
  df.name = PooledArray(df.name)
  df.filename = PooledArray(df.filename)
  any(ismissing, df.time) || sort!(df, :time)
  df
end

### helpers

function read_kmz(filename)
  zip = ZipFile.Reader(filename)
  try
    i = findfirst(f -> endswith(lowercase(f.name), ".kml"), zip.files)
    i === nothing && throw(ErrorException("No KML file in KMZ archive"))
    EzXML.parsexml(Base.read(zip.files[i], String))
  finally
    close(zip)
  end
end

function collect_segments!(segments, node, name, time; filename, tz)
  tag = EzXML.nodename(node)
  if tag == "Placemark"
    name = child_text(node, "name")
    time = placemark_time(node, tz)
  end
  if tag == "Point" || tag == "LineString"
    locations = parse_coordinates(child_text(node, "coordinates"))
    push!(segments, segment_df(fill(time, length(locations)), locations; name, filename))
  elseif tag == "Track"
    push!(segments, track2pts(node; name, filename, tz))
  elseif tag ∈ CONTAINERS
    for child ∈ EzXML.eachelement(node)
      collect_segments!(segments, child, name, time; filename, tz)
    end
  end
  segments
end

function child_text(node, tag)
  for child ∈ EzXML.eachelement(node)
    EzXML.nodename(child) == tag && return strip(EzXML.nodecontent(child))
  end
  missing
end

function placemark_time(node, tz)
  for child ∈ EzXML.eachelement(node)
    tag = EzXML.nodename(child)
    tag == "TimeStamp" && return parse_time(child_text(child, "when"), tz)
    tag == "TimeSpan" && return parse_time(child_text(child, "begin"), tz)
  end
  missing
end

function track2pts(node; name, filename, tz)
  times = ZonedDateTime[]
  locations = LLA{Float64}[]
  for child ∈ EzXML.eachelement(node)
    tag = EzXML.nodename(child)
    tag == "when" && push!(times, parse_time(EzXML.nodecontent(child), tz))
    tag == "coord" && push!(locations, lla(parse.(Float64, split(EzXML.nodecontent(child)))))
  end
  length(times) == length(locations) || throw(ErrorException("Track has $(length(times)) times but $(length(locations)) coordinates"))
  segment_df(times, locations; name, filename)
end

function segment_df(times, locations; name, filename)
  n = length(locations)
  time = any(ismissing, times) ? Vector{Union{Missing,ZonedDateTime}}(times) : Vector{ZonedDateTime}(times)
  df = DataFrame(; time, location=locations)
  df.name = repeat(PooledArray(Union{Missing,String}[name]), n)
  df.filename = repeat(PooledArray([filename]), n)
  df
end

combine_segments(segments) = vcat([insertcols!(x, :segment_index=>i) for (i,x) in enumerate(segments)]...)

parse_coordinates(::Missing) = throw(ErrorException("Geometry without coordinates"))
parse_coordinates(s) = [lla(parse.(Float64, split(t, ','))) for t ∈ split(s)]

lla(v) = LLA(v[2], v[1], length(v) > 2 ? v[3] : 0.0)

parse_time(::Missing, tz) = missing

# KML times are ISO 8601, possibly truncated to a date or year; no zone means UTC
function parse_time(s, tz)
  m = match(TIME_RE, strip(s))
  m === nothing && throw(ErrorException("Bad KML time: $s"))
  field(i) = m[i] === nothing ? 0 : parse(Int, m[i])
  ms = m[7] === nothing ? 0 : round(Int, 1000 * parse(Float64, "0." * m[7]))
  dt = DateTime(field(1), max(field(2), 1), max(field(3), 1), field(4), field(5), field(6)) + Millisecond(ms)
  offset = m[8] === nothing || m[8] == "Z" ? "+00:00" : m[8]
  astimezone(ZonedDateTime(dt, FixedTimeZone(offset)), tz)
end

end # module
