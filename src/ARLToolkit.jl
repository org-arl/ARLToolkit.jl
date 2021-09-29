module ARLToolkit

export AIS, GPX, CTD

include("utils.jl")
include("AIS.jl")
include("GPX.jl")
include("CTD.jl")

function __init__()
  @eval Base.show(io::IO, x::LLA) = prettyprint(io, x)
  @eval Base.print(io::IO, x::ZonedDateTime) = prettyprint(io, x)
end

end # module
