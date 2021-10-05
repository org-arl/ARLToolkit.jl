module BLAS

using Dates
using DataFrames
using Distributions

# default problem is set up for tx and rx being DataFrames
# with only a time::DateTime column needed in each

Base.@kwdef struct Problem
  tx::DataFrame
  rx::DataFrame
  σₜ::Float64 = 10.0
  time::Function = x -> datetime2unix(DateTime(x.time))
  delay::Function = (tx, rx) -> 0.0
  passoc::Function = (tx, rx) -> 1.0
  pfalse::Function = rx -> 0.1
end

struct State
  score::Float64
  backlink::Union{State,Missing}
  assoc::Union{Pair{Int},Missing}
  i::Int
  j::Int
  μₜ::Float64
  σₜ::Float64
end

Base.show(io::IO, s::State) = print(io, "<i=$(s.i), j=$(s.j), μₜ=$(s.μₜ), $(s.assoc), $(s.score)>")

function Base.show(io::IO, ss::AbstractArray{State})
  print(io, "[\n")
  for s ∈ ss
    print(io, "  <i=$(s.i), j=$(s.j), μₜ=$(s.μₜ), $(s.assoc), $(s.score)>\n")
  end
  print(io, "]\n")
end

score(state) = state.score

function isduplicate(state, 𝒮)
  for s ∈ 𝒮
    s === state && continue
    (s.i != state.i || s.j != state.j || s.assoc !== state.assoc) && continue
    state.score > s.score && continue
    state.score < s.score && return true
    hash(state) < hash(s) && return true
  end
  false
end

function solve(P::Problem; nhypothesis=30)
  𝒮 = [State(0.0, missing, missing, 0, 0, 0.0, P.σₜ)]
  for (j, rx) ∈ enumerate(eachrow(P.rx))
    𝒮⁺ = State[]
    for state ∈ 𝒮
      # TODO: track σₜ better, adjusting it based on the time difference for each entry
      𝒟ₜ = Normal(state.μₜ, state.σₜ)
      pfalse = P.pfalse(rx)
      p = pfalse * pdf(𝒟ₜ, state.μₜ)
      push!(𝒮⁺, State(state.score + log10(p), state, missing, state.i, j, state.μₜ, state.σₜ))
      for i ∈ state.i+1:size(P.tx,1)
        tx = P.tx[i,:]
        Δt = P.time(rx) - P.time(tx) - P.delay(tx, rx)
        Δt < -3 * state.σₜ && break
        p = (1 - pfalse) * pdf(𝒟ₜ, Δt) * P.passoc(tx, rx)
        push!(𝒮⁺, State(state.score + log10(p), state, i => j, i, j, Δt, state.σₜ))
      end
    end
    sort!(𝒮⁺; by=score, rev=true)
    if isinf(𝒮⁺[1].score)
      @warn "Ran out of possibilities for RX[$j]!"
      @show 𝒮⁺
      break
    end
    filter!(s -> s.score ≥ 𝒮⁺[1].score - 1, 𝒮⁺)
    filter!(s -> !isduplicate(s, 𝒮⁺), 𝒮⁺)
    length(𝒮⁺) > nhypothesis && (𝒮⁺ = 𝒮⁺[1:nhypothesis])
    𝒮 = 𝒮⁺
  end
  assoc = DataFrame(txid=Int[], rxid=[])
  state = 𝒮[1]
  while state !== missing
    state.assoc === missing || push!(assoc, (state.assoc...,))
    state = state.backlink
  end
  sort!(assoc, :txid)
  assoc.txtime = P.tx[assoc.txid,:time]
  assoc.rxtime = P.rx[assoc.rxid,:time]
  assoc.Δt = [P.time(P.rx[assoc.rxid[i],:]) - P.time(P.tx[assoc.txid[i],:]) - P.delay(P.tx[assoc.txid[i],:], P.rx[assoc.rxid[i],:]) for i ∈ 1:size(assoc, 1)]
  assoc
end

end # module
