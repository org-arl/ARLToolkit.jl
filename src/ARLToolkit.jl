module ARLToolkit

export AIS, GPX, CTD, Logs
export UnetLogs, Message, bathy

include("utils.jl")
include("AIS.jl")
include("GPX.jl")
include("CTD.jl")
include("Logs.jl")
include("Bathymetry.jl")

import .Logs: UnetLogs
import .Logs: Message
import .Bathymetry: bathy

function __init__()
  @eval Base.show(io::IO, x::LLA) = prettyprint(io, x)
  @eval Base.print(io::IO, x::ZonedDateTime) = prettyprint(io, x)
end

end # module
