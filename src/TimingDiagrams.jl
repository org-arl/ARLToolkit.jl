module TimingDiagrams

using Plots
using LinearAlgebra

export timingdiagram, node!, tx!

struct Node
  name::String
  pos::Vector{Float64}
  ypos::Float64
end

const nodes = Node[]
const speed = Ref(1.0)
const duration = Ref(0.0)
const timings = Float64[]

const theme = Dict{Symbol,Any}(
  :txheight => 10.0,
  :fontsize => 8,
  :ypad => 5.0,
  :tpad => 0.01,
  :txcolor => :blue,
  :rxcolor => :green,
  :linecolor => :lightgray,
  :nodecolor => :black
)

speed!(c) = (speed[] = c)
duration!(d) = (duration[] = d)

function timingdiagram(f; kwargs...)
  plt = plot(; border=:none, legend=false, yflip=true, kwargs...)
  empty!(nodes)
  empty!(timings)
  f()
  for n ∈ nodes
    plot!(plt, [minimum(timings) - theme[:tpad], maximum(timings) + theme[:tpad]], [n.ypos, n.ypos]; color=theme[:nodecolor])
    annotate!(plt, -theme[:tpad], n.ypos, text(n.name * " ", theme[:fontsize], :right))
  end
  empty!(nodes)
  empty!(timings)
  plt
end

function node!(name, pos; ypos=norm(pos))
  push!(nodes, Node(name, pos isa Real ? [Float64(pos)] : pos, ypos))
  length(nodes)
end

function tx!(t, from, to=setdiff(eachindex(nodes),from); duration=duration[], txlabel=nothing, txtiminglabel=nothing, rxlabels=nothing, rxtiminglabels=nothing)
  rxtimes = [t + norm(nodes[i].pos - nodes[from].pos) / speed[] for i ∈ to]
  duration > 0.0 && rect!(t, nodes[from].ypos, duration, theme[:txheight]; color=theme[:txcolor])
  txlabel === nothing || annotate!(t + duration/2, nodes[from].ypos - theme[:txheight] - theme[:ypad], text(txlabel, theme[:fontsize], :bottom))
  txtiminglabel === nothing || annotate!(t, nodes[from].ypos + theme[:ypad], text(txtiminglabel, theme[:fontsize], :top))
  for (i, rx) ∈ enumerate(to)
    plot!([t, rxtimes[i]], [nodes[from].ypos, nodes[rx].ypos]; color=theme[:linecolor])
    duration > 0.0 && rect!(rxtimes[i], nodes[rx].ypos, duration, theme[:txheight]; color=theme[:rxcolor])
    rxlabels === nothing || annotate!(rxtimes[i] + duration/2, nodes[rx].ypos - theme[:txheight] - theme[:ypad], text(rxlabels[i], theme[:fontsize], :bottom))
    rxtiminglabels === nothing || annotate!(rxtimes[i], nodes[rx].ypos + theme[:ypad], text(rxtiminglabels[i], theme[:fontsize], :top))
    end
  push!(timings, t)
  push!(timings, minimum(rxtimes))
  push!(timings, maximum(rxtimes) + duration)
  rxtimes
end

function rect!(t, y, dt, dy; color)
  plot!(Shape([t, t+dt, t+dt, t], [y, y, y-dy, y-dy]); color)
end

end # module
