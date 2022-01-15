module ARLToolkit

using Requires

export AIS, CTD, Logs, Bathymetry, BLAS, GPXFile
export UnetLogs, bathy

include("utils.jl")
include("AIS.jl")
include("CTD.jl")
include("Logs.jl")
include("Bathymetry.jl")
include("BLAS.jl")

import .Logs: UnetLogs
import .Bathymetry: bathy

function __init__()
  @eval Base.show(io::IO, x::LLA) = prettyprint(io, x)
  @eval Base.print(io::IO, x::ZonedDateTime) = prettyprint(io, x)
  @require GPX="b55ef746-885f-40a4-ab22-c8118be08013" include("GPX.jl")
  @require Plots="91a5bcdd-55d7-5caf-9e0b-520d859cae80" begin
    include("plot-recipes.jl")
    include("TimingDiagrams.jl")
  end
  @require Makie="ee78f7c6-11fb-53f2-987a-cfe4a2b5a57a" include("makie-recipes.jl")
end

end # module
