##===----------------------------------------------------------------------===##
##                                     YEPPP.JL                               ##
##                                                                            ##
##===----------------------------------------------------------------------===##
##                                                                            ##
##  This file provides access to Yeppp and handles checking for the existence ##
##  of the Yeppp library during import.                                       ##
##                                                                            ##
##===----------------------------------------------------------------------===##
module Yeppp
import Vectorize: functions, addfunction

# Cross-version compatibility
if VERSION < v"0.5.0-dev" # Julia v0.4
    OS = OS_NAME
else
    OS = Sys.KERNEL
end

# Attempt to locate Yeppp library before we proceed with compiling file
libyeppp_ = Libdl.find_library(["libyeppp"])
if libyeppp_ != "" # using system installed yeppp
    const global libyeppp = libyeppp_
else # using Vectorize.jl provided yppp
    currdir = @__FILE__
    bindir = currdir[1:end-12]*"deps/src/yeppp/binaries/"
    if OS == :Darwin
        @eval const global libyeppp = bindir*"macosx/x86_64/libyeppp.dylib"
    elseif OS == :Linux
        @eval const global libyeppp = bindir*"linux/x86_64/libyeppp.so"
    elseif OS == :NT
        @eval const global libyeppp = bindir*"windows/amd64/yeppp.dll"
    end
end

"""
`__init__()` -> Void

This function initializes the Yeppp library whenever the module is imported.
This allows us to precompile the rest of the module without asking the user
to explictly initialize Yeppp! on load. 
"""
function __init__()
    # Yeppp Initialization
    if isfile(libyeppp)
        const status = ccall(("yepLibrary_Init", libyeppp), Cint,
                             (), )
        status != 0 && error("Error initializing Yeppp library (error: ", status, ")")
    end
    
    return true
end


## This defines the argument and return types for every yepCore function; this are as follow:
##
## (First Argument Type, Second Argument Type, Return Type
##
const yepppcore = ((Int8, Int8, Int8), (UInt8, UInt8, UInt16),  (Int16, Int16, Int16),
                   (UInt16, UInt16, UInt32), (Int32, Int32, Int32),
                   (UInt32, UInt32, UInt64), (Int64, Int64, Int64),
                   (Float32, Float32, Float32), (Float64, Float64, Float64))

## This defines the mapping between argument types and Yeppp function name specifications
const identifier = Dict(Int8 => "V8s", Int16 => "V16s", Int32 => "V32s", Int64 => "V64s",
                        UInt8 => "V8u", UInt16 => "V16u", UInt32 => "V32u", UInt64 => "V64u",
                        Float32 => "V32f", Float64 => "V64f")

#### Yeppp Arithmetic taking two arguments and returning vector
for (f, fname, name) in ((:add, "Add", "addition"),  (:sub, "Subtract", "subtraction"),
                   (:mul, "Multiply", "multiplication"), (:max, "Max", "maximum"),
                   (:min, "Min", "minimum"))
    for (argtype1, argtype2, returntype) in yepppcore
        # generate Yeppp function name
        yepppname = string("yepCore_$(fname)_", identifier[argtype1], identifier[argtype2],
                           "_", identifier[returntype])
        addfunction(functions, (f, (Float64,Float64)), "Vectorize.Yeppp.$f") 
        @eval begin
            @doc """
            `$($f)(X::Vector{$($argtype1)}, Y::Vector{$($argtype2)})`
            Implements element-wise **$($name)** over two **Vector{$($argtype1)}**. Allocates
            memory to store result. *Returns:* **Vector{$($returntype)}**
            """ ->
            function ($f)(X::Vector{$argtype1}, Y::Vector{$argtype2})
                len = length(X)
                out = Array($returntype, len)
                ccall(($(yepppname, libyeppp)), Cint,
                          (Ptr{$argtype1}, Ptr{$argtype2}, Ptr{$returntype},  Clonglong),
                          X, Y, out, len)
                return out
            end
        end
    end
end

#### YepppMath functions returning vectors
for (f, fname) in [(:sin, "Sin"),  (:cos, "Cos"),  (:tan, "Tan"), (:log, "Log"), (:exp, "Exp")]
    yepppname = string("yepMath_$(fname)_V64f_V64f")
    name = string(f)
    f! = Symbol("$(f)!")
    # register functions for build
    addfunction(functions, (f, (Float64,)), "Vectorize.Yeppp.$f") 
    addfunction(functions, (f!, (Float64,Float64)), "Vectorize.Yeppp.$(f!)") 
    @eval begin
         @doc """
        `$($f)(X::Vector{Float64})`
        Implements element-wise **$($name)** over a **Vector{Float64}**. Allocates
        memory to store result. *Returns:* **Vector{Float64}**
        """ ->
        function ($f)(X::Vector{Float64}) # regular syntax
            out = Array(Float64, length(X))
            return ($f!)(out, X)
        end
        @doc """
        `$($f!)(result::Vector{Float64}, X::Vector{Float64})`
        Implements element-wise **$($name)** over a **Vector{Float64}** and overwrites
        the result vector with computed value. *Returns:* **Vector{Float64}** `result`
        """ ->
        function ($f!)(out::Vector{Float64}, X::Vector{Float64}) # in place syntax
            len = length(X)
            ccall(($(yepppname, libyeppp)), Cint,
                  (Ptr{Float64}, Ptr{Float64},  Clonglong),
                  X, out, len)
            return out
        end
    end
end

## YepppCore - functions that return scalars
for (T, Tscalar) in ((Float32, "S32f"), (Float64, "S64f"))
    for (f, fname, name) in [(:sum, "Sum", "sum"), (:sumsqr, "SumSquares", "sum-of-squares")]
        yepppname = string("yepCore_$(fname)_", identifier[T], "_", Tscalar)
        addfunction(functions, (f, (T,)), "Vectorize.Yeppp.$f")
        @eval begin
            @doc """
            `$($f)(X::Vector{$($T)})`
            Computes the **$($name)** of a **Vector{$($T)}**. Allocates
            memory to store result. *Returns:* **Vector{$($T)}**
            """ ->
            function ($f)(X::Vector{$T})
                len = length(X)
                out = Array($T, 1)
                ccall(($(yepppname, libyeppp)), Cint,
                      (Ptr{$T}, Ptr{$T},  Clonglong),
                      X, out, len)
                return out[1]
            end
        end
    end
end

end # End Module
