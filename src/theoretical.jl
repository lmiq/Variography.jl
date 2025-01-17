# ------------------------------------------------------------------
# Licensed under the MIT License. See LICENSE in the project root.
# ------------------------------------------------------------------

"""
    Variogram

A theoretical variogram model (e.g. Gaussian variogram).
"""
abstract type Variogram end

"""
    sill(γ)

Return the sill of the variogram `γ` when defined.
"""
sill(γ::Variogram) = γ.sill

"""
    nugget(γ)

Return the nugget of the variogram `γ` when defined.
"""
nugget(γ::Variogram) = γ.nugget

"""
    range(γ)

Return the maximum range of the variogram `γ` when defined.
"""
Base.range(γ::Variogram) = maximum(radii(γ.ball))

"""
    γ(u, v)

Evaluate the variogram at points `u` and `v`.
"""
function (γ::Variogram)(u::Point, v::Point)
  d = metric(γ.ball)
  x = coordinates(u)
  y = coordinates(v)
  h = evaluate(d, x, y)
  γ(h)
end

"""
    γ(U, v)

Evaluate the variogram at geometry `U` and point `v`.
"""
function (γ::Variogram)(U::Geometry, v::Point)
  us = _sample(γ, U)
  mean(γ(u, v) for u in us)
end

"""
    γ(u, V)

Evaluate the variogram at point `u` and geometry `V`.
"""
(γ::Variogram)(u::Point, V::Geometry) = γ(V, u)

"""
    γ(U, V)

Evaluate the variogram at geometries `U` and `V`.
"""
function (γ::Variogram)(U::Geometry, V::Geometry)
  us = _sample(γ, U)
  vs = _sample(γ, V)
  mean(γ(u, v) for u in us, v in vs)
end

"""
    result_type(γ, u, v)

Return result type of γ(u, v).
"""
result_type(γ::Variogram, u, v) = typeof(γ(u, v))

"""
    isstationary(γ)

Check if variogram `γ` possesses the 2nd-order stationary property.
"""
isstationary(γ::Variogram) = isstationary(typeof(γ))

"""
    isisotropic(γ)

Tells whether or not variogram `γ` is isotropic.
"""
isisotropic(γ::Variogram) = isisotropic(γ.ball)

"""
    pairwise(γ, domain)

Evaluate variogram `γ` between all elements in the `domain`.
"""
function pairwise(γ::Variogram, domain)
  u = first(domain)
  n = length(domain)
  R = result_type(γ, u, u)
  Γ = Matrix{R}(undef, n, n)
  pairwise!(Γ, γ, domain)
end

function pairwise!(Γ, γ::Variogram, domain)
  n = length(domain)
  @inbounds for j in 1:n
    vⱼ = domain[j]
    sⱼ = _sample(γ, vⱼ)
    for i in (j + 1):n
      vᵢ = domain[i]
      sᵢ = _sample(γ, vᵢ)
      Γ[i, j] = mean(γ(pᵢ, pⱼ) for pᵢ in sᵢ, pⱼ in sⱼ)
    end
    Γ[j, j] = mean(γ(pⱼ, pⱼ) for pⱼ in sⱼ, pⱼ in sⱼ)
    for i in 1:(j - 1)
      Γ[i, j] = Γ[j, i] # leverage the symmetry
    end
  end
  Γ
end

"""
    pairwise(γ, domain₁, domain₂)

Evaluate variogram `γ` between all elements of `domain₁` and `domain₂`.
"""
function pairwise(γ::Variogram, domain₁, domain₂)
  u = first(domain₁)
  v = first(domain₂)
  m = length(domain₁)
  n = length(domain₂)
  R = result_type(γ, u, v)
  Γ = Matrix{R}(undef, m, n)
  pairwise!(Γ, γ, domain₁, domain₂)
end

function pairwise!(Γ, γ::Variogram, domain₁, domain₂)
  m = length(domain₁)
  n = length(domain₂)
  @inbounds for j in 1:n
    vⱼ = domain₂[j]
    sⱼ = _sample(γ, vⱼ)
    for i in 1:m
      vᵢ = domain₁[i]
      sᵢ = _sample(γ, vᵢ)
      Γ[i, j] = mean(γ(pᵢ, pⱼ) for pᵢ in sᵢ, pⱼ in sⱼ)
    end
  end
  Γ
end

# -----------
# IO METHODS
# -----------

function Base.show(io::IO, γ::Variogram)
  T = typeof(γ)
  O = IOContext(io, :compact => true)
  name = string(nameof(T))
  params = String[]
  for fn in fieldnames(T)
    val = getfield(γ, fn)
    if val isa MetricBall
      if isisotropic(val)
        r = first(radii(val))
        push!(params, "range=$r")
      else
        r = Tuple(radii(val))
        push!(params, "ranges=$r")
      end
      m = nameof(typeof(metric(val)))
      push!(params, "metric=$m")
    else
      push!(params, "$fn=$val")
    end
  end
  print(O, name, "(", join(params, ", "), ")")
end

function Base.show(io::IO, ::MIME"text/plain", γ::Variogram)
  T = typeof(γ)
  O = IOContext(io, :compact => true)
  name = string(nameof(T))
  header = isisotropic(γ) ? name : name * " (anisotropic)"
  params = String[]
  for fn in fieldnames(T)
    val = getfield(γ, fn)
    if val isa MetricBall
      if isisotropic(val)
        r = first(radii(val))
        push!(params, "  └─range ⇨ $r")
      else
        r = Tuple(radii(val))
        push!(params, "  └─ranges ⇨ $r")
      end
      m = nameof(typeof(metric(val)))
      push!(params, "  └─metric ⇨ $m")
    else
      push!(params, "  └─$fn ⇨ $val")
    end
  end
  println(O, header)
  print(O, join(params, "\n"))
end

# ----------------
# IMPLEMENTATIONS
# ----------------

include("theoretical/gaussian.jl")
include("theoretical/exponential.jl")
include("theoretical/spherical.jl")
include("theoretical/matern.jl")
include("theoretical/cubic.jl")
include("theoretical/pentaspherical.jl")
include("theoretical/sinehole.jl")
include("theoretical/power.jl")
include("theoretical/nugget.jl")
include("theoretical/circular.jl")
