module ARLToolkit

export AIS, GPX, CTD, Logs
export UnetLogs, Message

include("utils.jl")
include("AIS.jl")
include("GPX.jl")
include("CTD.jl")
include("Logs.jl")

import .Logs: UnetLogs
import .Logs: Message

function __init__()
  @eval Base.show(io::IO, x::LLA) = prettyprint(io, x)
  @eval Base.print(io::IO, x::ZonedDateTime) = prettyprint(io, x)
end

end # module
