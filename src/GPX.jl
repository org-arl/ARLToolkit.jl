
module GPXFile

import ..GPX
import DataFrames: DataFrame
import Geodesy: LLA
import TimeZones: astimezone, localzone
import PooledArrays: PooledArray

function gpx_segment2pts(segment; tz=localzone())
    p = segment.points
    df = DataFrame(time=[astimezone(p1.time, tz) for p1 ∈ p], location=[LLA(p1.lat, p1.lon) for p1 ∈ p])
    df.filename = repeat(PooledArray([filename]), size(df, 1))
    df
end

function read(filename; tz=localzone())
  if isdir(filename)
    filenames = String[]
    for f ∈ readdir(filename; join=true)
      endswith(lowercase(f), ".gpx") && push!(filenames, f)
    end
    return read(filenames)
  end
  gpx = GPX.read_gpx_file(filename)
  length(gpx.tracks) > 1 && throw(ErrorException("More than one tracks in GPX file"))
  length(gpx.tracks[1].segments) > 1 && return gpx_segment2pts.(gpx.tracks[1].segments; tz=tz)

  gpx_segment2pts(gpx.tracks[1].segments[1])
end

function read(filenames::AbstractVector)
  df = vcat(read.(filenames)...)
  df.filename = PooledArray(df.filename)
  sort!(df, :time)
end

end # module
