module EPSG3414

### Code generated using Gemini

# SVY21 (EPSG:3414) -> WGS84 lat/lon (EPSG:4326)
# Inputs: easting (m), northing (m)
# Output: (lat_deg, lon_deg)

# WGS84 ellipsoid
const a  = 6378137.0                        # semi-major axis (m)
const f  = 1.0 / 298.257223563              # flattening
const e2 = 2f - f^2                         # first eccentricity squared
const e  = sqrt(e2)

# SVY21 Transverse Mercator parameters
const lat0_deg = 1.0 + 22.0/60.0            # latitude of origin = 1°22' N
const lon0_deg = 103.0 + 50.0/60.0          # central meridian   = 103°50' E
const k0 = 1.0                              # scale factor at central meridian
const FE = 28001.642                        # false easting (m)
const FN = 38744.572                        # false northing (m)

# Precompute radians
const φ0 = deg2rad(lat0_deg)
const λ0 = deg2rad(lon0_deg)

# Meridional arc coefficients
const A0 = 1 - e2/4 - 3*e2^2/64 - 5*e2^3/256
const A2 = (3/8) * (e2 + e2^2/4 + 15*e2^3/128)
const A4 = (15/256) * (e2^2 + 3*e2^3/4)
const A6 = (35/3072) * (e2^3)

# Helper: meridional arc from equator to latitude φ
meridional_arc(φ) = a * (A0*φ - A2*sin(2φ) + A4*sin(4φ) - A6*sin(6φ))

# Footpoint latitude series helper
function footpoint_lat(mu)
    # e1 is the third flattening
    e1 = (1 - sqrt(1 - e2)) / (1 + sqrt(1 - e2))
    s2 = sin(2*mu)
    s4 = sin(4*mu)
    s6 = sin(6*mu)
    s8 = sin(8*mu)
    mu +
    (3/2*e1 - 27/32*e1^3)*s2 +
    (21/16*e1^2 - 55/32*e1^4)*s4 +
    (151/96*e1^3)*s6 +
    (1097/512*e1^4)*s8
end

# Main conversion
function svy21_to_latlon(easting::Real, northing::Real)
    # Shift by false origin
    x = (easting - FE)
    y = (northing - FN)

    # Meridional arc from equator to the point: add arc to φ0
    M0 = meridional_arc(φ0)
    M  = M0 + y / k0

    # Compute footpoint latitude
    mu = M / (a * A0)
    φf = footpoint_lat(mu)

    # Radius of curvature
    sinφf = sin(φf)
    cosφf = cos(φf)
    tanφf = tan(φf)

    Nf = a / sqrt(1 - e2 * sinφf^2)                 # ν
    Rf = a * (1 - e2) / (1 - e2 * sinφf^2)^(3/2)    # ρ
    Tf = tanφf^2
    Cf = (e2 / (1 - e2)) * cosφf^2                  # η^2
    Df = x / (Nf * k0)

    # Latitude (radians) using series expansion
    φ = φf - (Nf * tanφf / Rf) * (
        Df^2 / 2 -
        (5 + 3*Tf + 10*Cf - 4*Cf^2 - 9*(e2/(1 - e2))) * Df^4 / 24 +
        (61 + 90*Tf + 298*Cf + 45*Tf^2 - 252*(e2/(1 - e2)) - 3*Cf^2) * Df^6 / 720
    )

    # Longitude (radians)
    λ = λ0 + (
        Df -
        (1 + 2*Tf + Cf) * Df^3 / 6 +
        (5 - 2*Cf + 28*Tf - 3*Cf^2 + 8*(e2/(1 - e2)) + 24*Tf^2) * Df^5 / 120
    ) / cosφf

    # Convert to degrees
    lat_deg = rad2deg(φ)
    lon_deg = rad2deg(λ)
    return lat_deg, lon_deg
end

end # module EPSG3414
