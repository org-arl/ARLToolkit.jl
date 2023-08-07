
module GPXFile

import ..GPX
import DataFrames: DataFrame
import Geodesy: LLA
import TimeZones: astimezone, localzone
import PooledArrays: PooledArray
import DataFramesMeta:@transform!


function segment2pts(segment; filename=filename, tz=localzone())
    p = segment.points
    df = DataFrame(time=[astimezone(p1.time, tz) for p1 ∈ p], location=[LLA(p1.lat, p1.lon) for p1 ∈ p])
    df.filename = repeat(PooledArray([filename]), size(df, 1))
    df
end

combine_segments(gpx_segments) = vcat([@transform!(x,:segment_index=i) for (i,x) in enumerate(gpx_segments)]...)

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
  length(gpx.tracks[1].segments) > 1 && return segment2pts.(gpx.tracks[1].segments; filename=filename, tz=tz)|>combine_segments

  gpx_segment2pts(gpx.tracks[1].segments[1]; filename=filename, tz=tz)
end

function read(filenames::AbstractVector)
  df = vcat(read.(filenames)...)
  df.filename = PooledArray(df.filename)
  sort!(df, :time)
end

end # module
