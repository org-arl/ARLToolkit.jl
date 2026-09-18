module HiDAQ

import ..SignalAnalysis: signal

const fs = 500_000.0
const nchannels = 4
const framelen = 2 * nchannels    # each frame has one big-endian Int16 per channel

"""
    info(filename)

Get metadata (sampling rate, number of channels, number of samples, duration)
for a HiDAQ recording. Throws an `ArgumentError` if the file does not look like
a valid HiDAQ recording.
"""
function info(filename)
  sz = filesize(filename)
  hdrlen = sz ≥ 4 ? Int(open(f -> ntoh(Base.read(f, Int32)), filename)) : 0
  round(Int, hdrlen / 66) == nchannels && hdrlen ≤ sz || throw(ArgumentError("$filename is not a HiDAQ file"))
  n = (sz - hdrlen) ÷ framelen
  (fs=fs, channels=nchannels, nsamples=n, duration=n/fs, hdrlen=hdrlen)
end

"""
    read(filename; channels=:, samples=:)

Read a HiDAQ recording as a signal with one channel per column. `channels`
selects the channels to read (1-based index, vector or range), and `samples`
is a range of sample indices to read. If `channels` is an integer, a single
channel signal is returned.

If a vector of filenames is given, the recordings are concatenated in time.
"""
function read(filename; channels=:, samples=:)
  md = info(filename)
  r = samples === Colon() ? (1:md.nsamples) : samples
  r isa AbstractUnitRange || throw(ArgumentError("samples must be a unit range"))
  checkbounds(1:md.nsamples, r)
  checkbounds(1:nchannels, channels)
  raw = Matrix{Int16}(undef, nchannels, length(r))
  open(filename) do f
    seek(f, md.hdrlen + (first(r) - 1) * framelen)
    read!(f, raw)
  end
  x = ntoh.(raw[channels,:]) ./ 2048
  signal(x isa AbstractMatrix ? permutedims(x) : x, fs)
end

function read(filenames::AbstractVector; kwargs...)
  signal(vcat((read(f; kwargs...) for f ∈ filenames)...), fs)
end

end # module
