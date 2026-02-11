module Bathymetry

import DataFrames: DataFrame
import Geodesy: LLA, euclidean_distance
import LinearAlgebra: norm
import DelimitedFiles: readdlm

include("EPSG3414.jl")

const Soundings = Vector{NTuple{3,Float64}}

function read(dirname)
  data = NTuple{3,Float64}[]
  if isfile(dirname) && endswith(dirname, ".xyz")
    for row ∈ eachrow(readdlm(dirname, ' ', Float64))
      lat, lon = EPSG3414.svy21_to_latlon(row[1], row[2])
      push!(data, (lon, lat, -row[3]))
    end
  else
    for filename ∈ filter(s -> endswith(s, ".txt"), readdir(dirname, join=true))
      open(filename, "r") do io
        for s ∈ eachline(io)
          m = match(r"^<SOUNDG .*>\( (.*) \)", s)
          if m !== nothing
            for x ∈ split(m[1], " ), ( ")
              try
                y = parse.(Float64, split(x, ","))
                push!(data, (y[1], y[2], y[3]))
              catch
                @warn "Bad data: $s"
              end
            end
          end
        end
      end
    end
  end
  data
end

function _bathy(s::Soundings, p::LLA; maxpts)
  r = [euclidean_distance(p, LLA(x[1], x[2])) for x ∈ s]
  ndx = sortperm(r)
  r = r[ndx]
  r[1] == 0.0 && return s[ndx[1]][3]
  i = findfirst(r1 -> r1 > 10 * r[1], r)
  j = i === nothing ? length(r) : min(maxpts, i - 1)
  w = 1 ./ (r[1:j].^2)
  d = [x[3] for x ∈ s[ndx[1:j]]]
  sum(d .* w) / sum(w)
end

bathy(s::Soundings, p::LLA; maxpts=100) = _bathy(s, p; maxpts)

function bathy(s::Soundings, p1::LLA, p2::LLA; spacing=10.0, maxpts=100)
  d = euclidean_distance(p1, p2)
  n = round(Int, d / spacing)
  x = LinRange(p1.lon, p2.lon, n)
  y = LinRange(p1.lat, p2.lat, n)
  DataFrame(range=LinRange(0, d, n), location=LLA.(y, x), depth=[_bathy(s, LLA(y[i], x[i]); maxpts) for i ∈ 1:n])
end

end # module
