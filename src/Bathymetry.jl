module Bathymetry

import DataFrames: DataFrame
import Geodesy: LLA, euclidean_distance
import LinearAlgebra: norm

const Soundings = Vector{NTuple{3,Float64}}

function read(dirname)
  data = NTuple{3,Float64}[]
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
  data
end

function _bathy(s::Soundings, p)
  r = [norm(p .- x[1:2]) for x ∈ s]
  ndx = sortperm(r)
  r = r[ndx]
  r[1] == 0.0 && return s[ndx[1]][3]
  i = findfirst(r1 -> r1 > 20 * r[1], r)
  j = i === nothing ? length(r) : i - 1
  w = 1 ./ (r[1:j].^2)
  d = [x[3] for x ∈ s[ndx[1:j]]]
  sum(d .* w) / sum(w)
end

bathy(s::Soundings, p::LLA) = _bathy(s, (p.lon, p.lat))

function bathy(s::Soundings, p1::LLA, p2::LLA; spacing=10.0)
  d = euclidean_distance(p1, p2)
  n = round(Int, d / spacing)
  x = LinRange(p1.lon, p2.lon, n)
  y = LinRange(p1.lat, p2.lat, n)
  DataFrame(range=LinRange(0, d, n), location=LLA.(y, x), depth=[_bathy(s, (x[i], y[i])) for i ∈ 1:n])
end

end # module
