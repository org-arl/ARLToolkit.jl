module AIS

import DataFrames: DataFrame, select!
import CSV
import Geodesy: LLA
import ..ARLToolkit: dts

function read(filename; aoi=nothing, from=nothing, to=nothing, duration=nothing)
  to !== nothing && duration !== nothing && throw(ArgumentError("Both 'to' and 'duration' cannot be specificed"))
  to === nothing && duration !== nothing && (to = from + duration)
  df = CSV.read(filename, DataFrame; header=["yyyy", "mm", "dd", "HH", "MM", "SS", "mmsi", "lat", "lon", "sog", "cog", "heading"])
  df.SS .= min.(59, df.SS)
  df.time = dts.(df.yyyy, df.mm, df.dd, df.HH, df.MM, df.SS)
  df.location = LLA.(df.lat, df.lon)
  df = select!(df, [:time, :mmsi, :location])
  aoi === nothing || (df = filter(row -> row.location ∈ aoi, df))
  from === nothing || (df = filter(row -> row.time ≥ from, df))
  to === nothing || (df = filter(row -> row.time ≤ to, df))
  df
end

end # module
