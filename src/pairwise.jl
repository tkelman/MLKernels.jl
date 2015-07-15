#===================================================================================================
  Pairwise Computation
===================================================================================================#

function init_pairwise{T<:FloatingPoint}(X::Matrix{T}, is_trans::Bool = false)
    n = size(X, is_trans ? 2 : 1)
    Array(T, n, n)
end

function init_pairwise{T<:FloatingPoint}(X::Matrix{T}, Y::Matrix{T}, is_trans::Bool = false)
    n_dim = is_trans ? 2 : 1
    n = size(X, n_dim)
    m = size(Y, n_dim)
    Array(T, n, m)
end

## Calculate the gramian matrix of X
function gramian_X!{T<:Base.LinAlg.BlasReal}(G::Matrix{T}, X::Matrix{T}, store_upper::Bool = true)
    (n = size(G, 1)) == size(G, 2) == size(X, 1) || throw(DimensionMismatch("Supplied kernel matrix must be square and have same number of rows as X."))
    BLAS.syrk!(store_upper ? 'U' : 'L', 'N', one(T), X, zero(T), G)
end

function gramian_Xt!{T<:Base.LinAlg.BlasReal}(G::Matrix{T}, X::Matrix{T}, store_upper::Bool = true)
    (n = size(G, 1)) == size(G, 2) == size(X, 2) || throw(DimensionMismatch("Supplied kernel matrix must be square and have the same number of colums as X."))
    BLAS.syrk!(store_upper ? 'U' : 'L', 'T', one(T), X, zero(T), G)  # 'T' -> C := αA'A + βC
end


# Returns the upper right corner of the gramian of [Xᵀ Yᵀ]ᵀ or [X Y]
function gramian_XY!{T<:Base.LinAlg.BlasReal}(G::Matrix{T}, X::Matrix{T}, Y::Matrix{T}, is_trans::Bool = false)
    size(X, 2) == size(Y, 2) || throw(DimensionMismatch("X must have as many columns as Y."))
    size(X, 1) == size(G, 1) || throw(DimensionMismatch("Supplied kernel matrix must have as many rows as X has rows."))
    size(Y, 1) == size(G, 2) || throw(DimensionMismatch("Supplied kernel matrix must have as many columns as Y has rows."))
    BLAS.gemm!('N', 'T', one(T), X, Y, zero(T), G)
end

function gramian_XY!{T<:Base.LinAlg.BlasReal}(G::Matrix{T}, X::Matrix{T}, Y::Matrix{T}, is_trans::Bool = false)
    size(X, 1) == size(Y, 1) || throw(DimensionMismatch("X must have as many rows as Y."))
    size(X, 2) == size(G, 1) || throw(DimensionMismatch("Supplied kernel matrix must have as many rows as X has columns."))
    size(Y, 2) == size(G, 2) || throw(DimensionMismatch("Supplied kernel matrix must have as many columns as Y has columns."))
    BLAS.gemm!('T', 'N', one(T), X, Y, zero(T), G)
end

function kappa_array!{T<:FloatingPoint}(κ::Kernel{T}, X::Matrix{T})
    @inbounds @simd for i = 1:length(X)
        X[i] = kappa(κ, X)
    end
    X
end
kappa_array{T<:FloatingPoint}(κ::Kernel{T}, X::Matrix{T}) = kappa_array!(κ, copy(X))


#===========================================================================
  Pairwise Single Matrix
===========================================================================#

for (fn, dim_n, dim_p, formula) in (
        (:pairwise_X!, 1, 2, parse("kappa(κ, X[j,i], X[k,i])")),
        (:pairwise_Xt!, 2, 1, parse("kappa(κ, X[i,j], X[i,k])"))
    )
    @eval begin

        function ($fn){T<:FloatingPoint}(K::Matrix{T}, κ::AdditiveKernel{T}, X::Matrix{T}, store_upper::Bool)
            (n = size(X,$dim_n)) == size(K,1) == size(K,2) || throw(DimensionMismatch("Kernel matrix must be square and match X."))
            p = size(X,$dim_p)
            for k = 1:n, j = store_upper ? (1:k) : (k:n)
                v = 0
                @inbounds @simd for i = 1:p
                    v += $formula
                end
                K[j,k] = v
            end
        end

        function ($fn){T<:FloatingPoint}(K::Matrix{T}, κ::AdditiveKernel{T}, X::Matrix{T}, w::Vector{T}, store_upper::Bool)
            (n = size(X,$dim_n)) == size(K,1) == size(K,2) || throw(DimensionMismatch("Kernel matrix must be square and match X."))
            (p = size(X,$dim_p)) == length(w) || throw(DimensionMismatch("Weight vector w must match X."))
            w² = w.^2
            for k = 1:n, j = store_upper ? (1:k) : (k:n)
                v = 0
                @inbounds @simd for i = 1:p
                    v += w²[i] * $formula
                end
                K[j,k] = v
            end
        end

    end
end

function pairwise!{T<:FloatingPoint}(K::Matrix{T}, κ::AdditiveKernel{T}, X::Matrix{T}, is_trans::Bool = false, store_upper::Bool = true, symmetrize::Bool = true)
    if is_trans
        pairwise_Xt!(K, κ, X, store_upper)
    else
        pairwise_X!(K, κ, X, store_upper)
    end
    symmetrize ? (store_upper ? syml!(K) : symu!(K)) : K
end
function pairwise{T<:FloatingPoint}(κ::AdditiveKernel{T}, X::Matrix{T}, is_trans::Bool = false, store_upper::Bool = true, symmetrize::Bool = true)
    pairwise!(init_pairwise(X, is_trans), κ, X, is_trans, store_upper, symmetrize)
end

function pairwise!{T<:FloatingPoint}(K::Matrix{T}, κ::AdditiveKernel{T}, X::Matrix{T}, w::Vector{T}, is_trans::Bool = false, store_upper::Bool = true, symmetrize::Bool = true)
    if is_trans
        pairwise_Xt!(K, κ, X, w, store_upper)
    else
        pairwise_X!(K, κ, X, w, store_upper)
    end
    symmetrize ? (store_upper ? syml!(K) : symu!(K)) : K
end
function pairwise{T<:FloatingPoint}(κ::AdditiveKernel{T}, X::Matrix{T}, w::Vector{T}, is_trans::Bool = false, store_upper::Bool = true, symmetrize::Bool = true)
    pairwise!(init_pairwise(X, is_trans), κ, X, w, is_trans, store_upper, symmetrize)
end


#===========================================================================
  Pairwise Double Matrix
===========================================================================#

for (fn, dim_n, dim_p, formula) in (
        (:pairwise_XY!, 1, 2, parse("kappa(κ, X[j,i], Y[k,i])")),
        (:pairwise_XtYt!, 2, 1, parse("kappa(κ, X[i,j], Y[i,k])"))
    )
    @eval begin

        function ($fn){T<:FloatingPoint}(K::Matrix{T}, κ::AdditiveKernel{T}, X::Matrix{T}, Y::Matrix{T})
            (n = size(X,$dim_n)) == size(K,1) || throw(DimensionMismatch(""))
            (m = size(Y,$dim_n)) == size(K,2) || throw(DimensionMismatch(""))
            (p = size(X,$dim_p)) == size(Y,$dim_p) || throw(DimensionMismatch(""))
            for k = 1:m, j = 1:n
                v = 0
                @inbounds @simd for i = 1:p
                    v += $formula
                end
                K[j,k] = v
            end
        end

        function ($fn){T<:FloatingPoint}(K::Matrix{T}, κ::AdditiveKernel{T}, X::Matrix{T}, Y::Matrix{T}, w::Vector{T})
            (n = size(X,$dim_n)) == size(K,1) || throw(DimensionMismatch(""))
            (m = size(Y,$dim_n)) == size(K,2) || throw(DimensionMismatch(""))
            (p = size(X,$dim_p)) == size(Y,$dim_p) == length(w) || throw(DimensionMismatch(""))
            w² = w.^2
            for k = 1:m, j = 1:n
                v = 0
                @inbounds @simd for i = 1:p
                    v += w²[i] * $formula
                end
                K[j,k] = v
            end
        end

    end
end

function pairwise!{T<:FloatingPoint}(K::Matrix{T}, κ::AdditiveKernel{T}, X::Matrix{T}, Y::Matrix{T}, is_trans::Bool = false)
    if is_trans
        pairwise_XtYt!(K, κ, X, Y)
    else
        pairwise_XY!(K, κ, X, Y)
    end
    K
end
function pairwise{T<:FloatingPoint}(κ::AdditiveKernel{T}, X::Matrix{T}, Y::Matrix{T}, is_trans::Bool = false)
    pairwise!(init_pairwise(X, Y), κ, X, Y, is_trans)
end

function pairwise!{T<:FloatingPoint}(K::Matrix{T}, κ::AdditiveKernel{T}, X::Matrix{T}, Y::Matrix{T}, w::Vector{T}, is_trans::Bool = false)
    if is_trans
        pairwise_XtYt!(K, κ, X, Y, w)
    else
        pairwise_XY!(K, κ, X, Y, w)
    end
    K
end
function pairwise{T<:FloatingPoint}(κ::AdditiveKernel{T}, X::Matrix{T}, Y::Matrix{T}, w::Vector{T}, is_trans::Bool = false)
    pairwise!(init_pairwise(X, Y), κ, X, Y, w, is_trans)
end


#===========================================================================
  Optimized Separable Kernel
===========================================================================#

# Base Scalar Product

pairwise_X!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::ScalarProductKernel{T}, X::Matrix{T}, store_upper::Bool) = gramian!(K, X, false, store_upper, false)
pairwise_Xt!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::ScalarProductKernel{T}, X::Matrix{T}, store_upper::Bool) = gramian!(K, X, true, store_upper, false)

pairwise_X!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::ScalarProductKernel{T}, X::Matrix{T}, w::Vector{T}, store_upper::Bool) = gramian!(K, scale(X, w), false, store_upper, false)
pairwise_Xt!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::ScalarProductKernel{T}, X::Matrix{T}, w::Vector{T}, store_upper::Bool) = gramian!(K, scale(w, X), false, store_upper, false)

pairwise_X!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::ScalarProductKernel{T}, X::Matrix{T}, Y::Matrix{T}, store_upper::Bool) = gramian!(K, X, Y, false, store_upper, false)
pairwise_Xt!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::ScalarProductKernel{T}, X::Matrix{T}, Y::Matrix{T}, store_upper::Bool) = gramian!(K, X, Y, true, store_upper, false)

pairwise_X!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::ScalarProductKernel{T}, X::Matrix{T}, Y::Matrix{T}, w::Vector{T}, store_upper::Bool) = gramian!(K, scale(X, w.^2), Y, false, store_upper, false)
pairwise_Xt!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::ScalarProductKernel{T}, X::Matrix{T}, Y::Matrix{T}, w::Vector{T}, store_upper::Bool) = gramian!(K, scale(w.^2, X), Y, false, store_upper, false)

# Separable Kernel

function pairwise_X!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::SeparableKernel{T}, X::Matrix{T}, store_upper::Bool)
    Z = kappa_array(κ, X)
    gramian_X!(K, Z, store_upper)
end
function pairwise_Xt!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::SeparableKernel{T}, X::Matrix{T}, store_upper::Bool)
    Z = kappa_array(κ, X)
    gramian_Xt!(K, Z, store_upper)
end

function pairwise_X!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::ScalarProductKernel{T}, X::Matrix{T}, w::Vector{T}, store_upper::Bool)
    Z = scale!(kappa_array(κ, X), w)
    gramian_X!(K, Z, store_upper)
end
function pairwise_Xt!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::ScalarProductKernel{T}, X::Matrix{T}, w::Vector{T}, store_upper::Bool)
    Z = scale!(kappa_array(X, κ), w)
    gramian_Xt!(K, Z, store_upper)
end

function pairwise_X!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::SeparableKernel{T}, X::Matrix{T}, Y::Matrix{T})
    Z = kappa_array(κ, X)
    V = kappa_array(κ, Y)
    gramian_X!(K, Z, V)
end
function pairwise_Xt!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::SeparableKernel{T}, X::Matrix{T}, Y::Matrix{T})
    Z = kappa_array(κ, X)
    V = kappa_array(κ, Y)
    gramian_Xt!(K, Z, V)
end

function pairwise_X!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::ScalarProductKernel{T}, X::Matrix{T}, Y::Matrix{T}, w::Vector{T})
    Z = scale!(kappa_array(κ, X), w)
    V = scale!(kappa_array(κ, Y), w)
    gramian_X!(K, Z, Y)
end
function pairwise_Xt!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::ScalarProductKernel{T}, X::Matrix{T}, Y::Matrix{T}, w::Vector{T})
    Z = scale!(kappa_array(X, κ), w)
    V = scale!(kappa_array(κ, Y), w)
    gramian_Xt!(K, Z, Y)
end


#===========================================================================
  Optimized Squared Distance Kernel
===========================================================================#

function squared_distance!{T<:FloatingPoint}(K::Matrix{T}, xᵀx::Vector{T}, store_upper::Bool)
    (n = length(xᵀx)) == size(K,1) == size(K,2) || throw(DimensionMismatch("Kernel matrix must be square."))
    @inbounds for j = 1:n, i = store_upper ? (1:j) : (j:n)
        K[i,j] = xᵀx[i] - 2K[i,j] + xᵀx[j]
    end
    K
end

function pairwise_X!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::SquaredDistanceKernel{T,:t1}, X::Matrix{T}, store_upper::Bool)
    gramian_X!(K, X, store_upper)
    squared_distance!(K, diag(K), store_upper)
end

function pairwise_Xt!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::SquaredDistanceKernel{T,:t1}, X::Matrix{T}, store_upper::Bool)
    gramian_Xt!(K, X, store_upper)
    squared_distance!(K, diag(K), store_upper)
end

function pairwise_X!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::SquaredDistanceKernel{T,:t1}, X::Matrix{T}, w::Vector{T}, store_upper::Bool)
    gramian_X!(K, scale(X, w), store_upper)
    squared_distance!(K, diag(K), store_upper)
end

function pairwise_Xt!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::SquaredDistanceKernel{T,:t1}, X::Matrix{T}, w::Vector{T}, store_upper::Bool)
    gramian_Xt!(K, scale(w, X), store_upper)
    squared_distance!(K, diag(K), store_upper)
end

function squared_distance!{T<:FloatingPoint}(K::Matrix{T}, xᵀx::Vector{T}, yᵀy::Vector{T})
    n,m = size(K)
    n == length(xᵀx) || throw(DimensionMismatch(""))
    m == length(yᵀy) || throw(DimensionMismatch(""))
    @inbounds for j = 1:m, i = 1:n
        K[i,j] = xᵀx[i] - 2K[i,j] + yᵀy[j]
    end
    K
end

function pairwise_X!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::SquaredDistanceKernel{T,:t1}, X::Matrix{T}, Y::Matrix{T}, store_upper::Bool)
    gramian_X!(K, X, Y)
    squared_distance!(K, dot_rows(X), dot_rows(Y))
end

function pairwise_Xt!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::SquaredDistanceKernel{T,:t1}, X::Matrix{T}, Y::Matrix{T}, store_upper::Bool)
    gramian_Xt!(K, X, Y)
    squared_distance!(K, dot_columns(X), dot_columns(Y))
end

function pairwise_X!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::SquaredDistanceKernel{T,:t1}, X::Matrix{T}, Y::Matrix{T}, w::Vector{T}, store_upper::Bool)
    Z = scale(X, w)
    V = scale(Y, w)
    gramian_X!(K, Z, V)
    squared_distance!(K, dot_rows(Z), dot_rows(V))
end

function pairwise_Xt!{T<:Base.LinAlg.BlasReal}(K::Matrix{T}, κ::SquaredDistanceKernel{T,:t1}, X::Matrix{T}, Y::Matrix{T}, w::Vector{T}, store_upper::Bool)
    Z = scale(w, X)
    V = scale(w, Y)
    gramian_Xt!(K, X, Y)
    squared_distance!(K, dot_columns(Z), dot_columns(V))
end