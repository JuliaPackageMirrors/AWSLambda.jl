#==============================================================================#
# SNS/test/runtests.jl
#
# Copyright Sam O'Connor 2014 - All rights reserved
#==============================================================================#


using AWSCore
using AWSLambda
using AWSSNS
using Retry
using SymDict
using JSON
using Base.Test

AWSCore.set_debug_level(1)


#-------------------------------------------------------------------------------
# Load credentials...
#-------------------------------------------------------------------------------

aws = AWSCore.aws_config(
                         region = "ap-northeast-1",
                         lambda_bucket = "ocaws.jl.lambdatest.tokyo",
                         #region = "us-east-1",
                         #lambda_bucket = "ocaws.jl.lambdatest",
                         lambda_packages = ["Requests",
                                            "Nettle",
                                            "LightXML",
                                            "JSON",
                                            "DataStructures",
                                            "StatsBase",
                                            "DataFrames",
                                            "DSP",
                                            "GZip",
                                            "ZipFile",
                                            "IniFile",
                                            "SymDict",
                                            "XMLDict",
                                            "Retry"
                                           ])

#create_jl_lambda_base(aws)

#using AWSS3
#s3_copy(aws, "ocaws.jl.lambdatest", "jl_lambda_base.zip",
#             to_bucket="ocaws.jl.lambdatest.tokyo", to_path= "jl_lambda_base.zip")



#-------------------------------------------------------------------------------
# Lambda tests
#-------------------------------------------------------------------------------


# Count primes in the cloud...

λ = @λ aws function count_primes(low::Int, high::Int)
    count = length(primes(low, high))
    println("$count primes between $low and $high.")
    return count
end

@test invoke_lambda(aws, "count_primes", low = 10, high = 100)[:jl_data] == "21"


# Count primes in parallel...

function count_primes(low::Int, high::Int)
    w = 500000000
    counts = amap(λ, [(i, min(high,i + w)) for i = low:w:high])
    count = sum(counts)
    println("$count primes between $low and $high.")
    return count
end

@test count_primes(10, 10000000000) == 455052507



mktempdir() do tmp
    cd(tmp) do

        # Create a test module under "tmp"...

        mkpath("TestModule")
        open(io->write(io, """
            module TestModule

            export test_function

            __precompile__()

            test_function(x) = x * x

            end
        """), "TestModule/TestModule.jl", "w")

        push!(LOAD_PATH, "TestModule")

        # Create a lambda that uses the TestModule...
        λ = @λ aws function lambda_test(x)

            # Check that precompile cache is being used...
            @assert !Base.stale_cachefile("/var/task/TestModule/TestModule.jl",
                                          "/var/task/TestModule.ji")
            using TestModule
            return test_function(x)
        end

        @test λ(4) == 16
    end
end



#-------------------------------------------------------------------------------
# API Gateway tests
#-------------------------------------------------------------------------------


if false

for api in apigateway_restapis(aws)
    apigateway(aws, "DELETE", "/restapis/$(api["id"])")
end


apigateway_create(aws, "count_primes", (:low, :high))

end



#==============================================================================#
# End of file.
#==============================================================================#
