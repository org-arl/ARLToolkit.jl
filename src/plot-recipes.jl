import .Plots: @recipe, @series, RecipesBase

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

@recipe function plot(x::AbstractVector{<:LLA})
  @series begin
    [v.lon for v ∈ x], [v.lat for v ∈ x]
  end
end

@recipe function plot(x::LLA)
  @series begin
    [x.lon], [x.lat]
  end
end
