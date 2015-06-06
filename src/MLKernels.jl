#===================================================================================================
  Kernel Functions Module
===================================================================================================#

module MLKernels

import Base: show, eltype, convert, promote #, call

export
    # Functions
    description,
    isposdef_kernel,
    iscondposdef_kernel,
    kernel,
    kernelparameters,
    kernel_dx,
    kernel_dy,
    kernel_dxdy,
    kernel_dp,
    kernelmatrix,
    kernelmatrix_dx,
    kernelmatrix_dy,
    kernelmatrix_dxdy,
    kernelmatrix_dp,
    center_kernelmatrix!,
    center_kernelmatrix,
    nystrom,

    kernelpath,

    # Types
    KernelVariable,
    BaseVariable,
    SubVariable,

    # Kernel Types
    Kernel,
        SimpleKernel,
            StandardKernel,
                SquaredDistanceKernel,
                    ExponentialKernel,
                    RationalQuadraticKernel,
                    PowerKernel,
                    LogKernel,
                ScalarProductKernel,
                    PolynomialKernel,
                    SigmoidKernel,
                SeparableKernel,
                    MercerSigmoidKernel,
            PeriodicKernel,
            ARD,
        CompositeKernel,
            KernelProduct,
            KernelSum

include("meta.jl")
include("auxfunctions.jl")
include("kernels.jl")
include("kernelderiv.jl")
include("kernelmatrix.jl")
include("kernelmatrixderiv.jl")
#include("kernelmatrixapprox.jl")

end # MLKernels
