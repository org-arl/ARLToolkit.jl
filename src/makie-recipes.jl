using .Makie: Makie

Makie.plottype(::AOI) = Makie.Image

function Makie.convert_arguments(P::Type{<:Makie.Image}, aoi::AOI)
  Makie.convert_arguments(P,
    range(aoi.topleft.lon, aoi.bottomright.lon; length=size(aoi.mapimg,2)),
    range(aoi.topleft.lat, aoi.bottomright.lat; length=size(aoi.mapimg,1)),
    rotr90(aoi.mapimg))
end
