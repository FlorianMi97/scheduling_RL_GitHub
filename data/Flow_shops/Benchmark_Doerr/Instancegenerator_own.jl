using DelimitedFiles
using JSON
using Distributions
using StatsBase
using Random

################################################################################################################################
# generate instance
"""
    createinstance(;nrstages::Int, nrproducts::Int, skippingprob::Float16, unrelatedmachines::Bool, degreeofunrelatedness::Float16
                    eligablemachines::Bool, routingoverlap::Float16, flexibilityscore::Float16,
                    processingmeanrange::Vector{Float64}, ratiosetupprocessing::Float64, nrjobsperproduct::Vector{Int},
                    processingratiominmean::Float64, processinguncertaintytype::String, setupratiominmean::Float64,
                    setupuncertaintytype::String) 
                    -> Dict()
    
    Params:
        ----------------------Layout----------------------------------------
        nrstages::Int defines the number of stages in the flow shop
        nrproducts::Int defines the number of products
        skippingprob::Float16 defines the probability of a product skipping a stage
        unrelatedmachines::Bool defines if parallel machines are unrelated or not
        degreeofunrelatedness::Float16 defines the degree of unrelatedness of the machines
        eligablemachines::Bool defines if parallel machines are eligable or not
        routingoverlap::Float16 defines the probability of a product routing overlapping with another product
        flexibilityscore::Float16 defines the flexibility score of the instance
        processingmeanrange::Vector{Float64} defines the range of the mean of the distribution
        ratiosetupprocessing::Float64 defines the ratio of the mean of the setup to the mean of the processing time
        ----------------------Orderbook-------------------------------------
        nrjobsperproduct::Vector{Int} defines the min and max number of jobs per product
        ----------------------Uncertain Times-----------------------------------------
        processingratiominmean::Float64 defines the ratio of the min to the mean of the distribution
        processinguncertaintytype::String defines the type of uncertainty (Deterministic, Exponential, Uniform)
        setupratiominmean::Float64 defines the ratio of the min to the mean of the distribution
        setupuncertaintytype::String defines the type of uncertainty (Deterministic, Exponential, Uniform)

    Return:
        Dict() with all information needed to create an environment
    



"""
function createinstance(;nrstages::Int, nrproducts::Int, skippingprob::Float16, unrelatedmachines::Bool, degreeofunrelatedness::Float16,
                    eligablemachines::Bool, routingoverlap::Float16, flexibilityscore::Float16,
                    processingmeanrange::Vector{Float64}, ratiosetupprocessing::Float64, nrjobsperproduct::Vector{Int},
                    processingratiominmean::Float64, processinguncertaintytype::String, setupratiominmean::Float64,
                    setupuncertaintytype::String) 
                    # -> Dict()
    
    # TODO add check if all para


    

end

function checktriangularinequality(matrix)
    c = size(matrix)[1]
    for i in 1:c
        for j in 1:c
            for k in 1:c
                if allunique([i,j,k])
                    if matrix[i,j] + matrix[j,k] < matrix[i,k]
                        return false
                    end
                end
            end
        end
    end
    return true
end

# generate a asymmetric matrix of size nrproducts x nrproducts that fulfilles triangular inequality and only samples values in a given intervals
function setupmatrix(nrproducts, setuprange, rng = MersenneTwister(1234))
    variablesdict = Dict((i,j) => [k for k in range(setuprange[1],setuprange[2])] for i in 1:nrproducts for j in 1:nrproducts)
    matrix = zeros(nrproducts,nrproducts)
    for i in 1:nrproducts
        for j in 1:nrproducts
            if i == j
                matrix[i,j] = 0
            else
                matrix[i,j] = sample(rng, variablesdict[(i,j)])
                filter!(e -> e ≠ matrix[i,j],variablesdict[(j,i)])
            end
        end
    end

    for i in 1:nrproducts
        for j in 1: nrproducts
            for k in 1:nrproducts
                if allunique([i,j,k])
                    if matrix[i,j] + matrix[j,k] < matrix[i,k]
                        println("issue")
                        matrix[i,k] = matrix[i,j] + matrix[j,k]
                    end
                end

            end
        end
    end

    checktriangularinequality(matrix) ? println("works") : println("does not work")
    return matrix
end 


##############################################################
# Helper functions
"""
    distribution(type::String,mean::Float64, ratiominmean::Float64, ratiomaxmean::Float64) -> Dict()    
    Dict includes:
    type::String (distribution name in Distributions.jl)
    min::Float
    parameters::Vector{Float} (dependend on type and function in Distributions.jl)
    max::Float (optional)
    mean::Flaot (optional)
"""
function distribution(type::String, mean::Float64, ratiominmean::Float64, ratiomaxmean::Float64)
    if type ∉ ["Exponential","Gamma","Normal","LogNormal", "Deterministic"]
        throw(DomainError(type, "either type is not supported (yet) or has a spelling mistake"))
    end
    if mean == 0.0
        return Dict("type" => "Nonexisting")
    else

        distdict = Dict("type" => type, "mean" => mean)

        # add min
        merge!(distdict, Dict("min" => ratiominmean*mean))

        # add optional max
        merge!(distdict, Dict("max" => ratiomaxmean != 1.0 ? ratiomaxmean*mean : nothing))

        # TODO add parameters
        # "Exponential" => 1
        if type == "Exponential"
            parameters = [(1-ratiominmean)*mean]
        # "Gamma" => 2,
        # "Normal" => 2,
        # "LogNormal" => 2)
        merge!(distdict, Dict("parameters" => parameters))
        end

        return distdict
    end
end

function generateInstance(;case::String, distributiontype::String = "Exponential", ratiominmean::Float64,
                            ratiomaxmean::Float64=1.0, distparameters = nothing, sensitivityAnalysis = false, nrjobsperproduct = [5,20])
    dir = pwd()
    # filename = "hhhhhh-0" # TODO loop over all files!
    filename = "llmlmm-3"
    filepath = string(dir,"/data/Flow_shops/Benchmark_Kurz/raw_data/",filename,".ft")
    data = readdlm(filepath)
    # println(data)

    # TODO use code to loop over files later!
    # TODO select fitting raw data instances for cases -> see excluded below!
    # dir = pwd()
    # foldername = string(dir,"/data/Instances/Flow_shops/Benchmark_Kurz/raw_data")
    # filesinfolder = readdir(foldername)
    # filesinfolder = [file for file in filesinfolder if file[end-2:end] == ".ft"]
    # if case[2] == 'g'
    #   filesinfolder = [file for file in filesinfolder if (file[6] = 'l' || file[6] = 'm')]
    # end
    # if case[1] == 'n'
    #   filesinfolder = [file for file in filesinfolder if (file[4:5] != "ll")]
    # end

    # for filename in filesinfolder
    #     data = readdlm(string(foldername, filename))

    # TODO sensitivity analysis loop:
    # -> different setting for uncertainity -> just change settings. #TODO add possibility for dependent uncertainity?
    # -> different elvels of ranges for setups -> multiply them with random numbers in intervals! 

    nrstages = data[4,2]
    nrproducts = data[3,2]-1
    nrjobs = 0
    orders = Dict()

    increment = (8+nrproducts)

    products = [string("PRODUCT_",i) for i in 1:nrproducts]
    
    resources = []
    resource_stage = Dict()
    stage_resources = Dict()
    count = 0
    stage = 0
    for i in range(9, step = increment, length = (nrstages))
        stage +=1
        tmpincrease = data[i,2]
        addM = [string("RES_", i+count) for i in 1:tmpincrease]
        append!(resources,addM)
        merge!(resource_stage, Dict(m => stage for m in addM))
        merge!(stage_resources, Dict(stage => addM))
        count += tmpincrease
    end

    # only for identical machines!
    if case[1] == 'i'
        stage = 0
        count = [0 for _ in products]
        operations_product = Dict(p => [] for p in products)
        processing_product = Dict(p => Dict() for p in products)
        product_ops_stage = Dict(p => Dict() for p in products)
        for i in range(13, step = increment, length = nrstages)
            stage += 1
            for (ii,j) in enumerate(products)
                tmpT = Float64(data[i,ii+1])
                if tmpT != 0.0
                    count[ii] +=1
                    push!(operations_product[j],string("OP_",count[ii]))
                    merge!(processing_product[j], Dict(string("OP_",count[ii]) =>
                        Dict(m => distribution(distributiontype, tmpT, ratiominmean, ratiomaxmean)
                        for m in stage_resources[stage])))
                    merge!(product_ops_stage[j], Dict(string("OP_",count[ii]) => stage))
                end
            end
        end
        operations = unique([i for x in values(operations_product) for i in x])
        ops_mach_comp = Dict(p => Dict(o => stage_resources[product_ops_stage[p][o]] for o in operations_product[p]) for p in products)


        # CASE ii: identical machines & individual jobs
        if case[2] == 'i'
            for (i,p) in enumerate(products)
                # TODO add due date based on lb and ub provided in instances?
                orders[string("ORD_",i)] = Dict("product" => p, "due_date" => nothing)
                nrjobs +=1
            end

        # CASE ig: identical machines & product groups
        else
            count = 0
            for p in products
                # sample number of jobs per product
                tmpNrjobs = rand(DiscreteUniform(nrjobsperproduct[1], nrjobsperproduct[2]))
                for _ in 1: tmpNrjobs
                    count +=1
                    nrjobs +=1
                    # TODO add due date based on lb and ub provided in instances?
                    orders[string("ORD_",count)] = Dict("product" => p, "due_date" => nothing)
                end
            end
        end
            
        setup = Dict(m => Dict(p => Dict() for p in products) for m in resources)
        for (i,j) in enumerate(range(16,step = increment, length = nrstages))
            for (ii,jj) in enumerate(j:(j+nrproducts-1))
                for i3 in 1:nrproducts
                    for m in stage_resources[i]
                        merge!(setup[m][products[ii]], Dict(products[i3] =>
                            distribution(distributiontype,data[jj,i3+1] == 90000 ? 0.0 : Float64(data[Int(jj),i3+1]) ,ratiominmean, ratiomaxmean)))
                    end
                end
            end
        end

    # non identical machines -> varying process/setup times and compatibility
    else
        # ops_mach_comp = Dict(p => Dict(o => stage_resources[product_ops_stage[p][o]] for o in operations_product[p]) for p in products)
        ops_mach_comp = Dict(p => Dict() for p in products)
        stage = 0
        count = [0 for _ in products]
        operations_product = Dict(p => [] for p in products)
        processing_product = Dict(p => Dict() for p in products)
        product_ops_stage = Dict(p => Dict() for p in products)
        product_stage_ops = Dict(p => Dict() for p in products)
        for i in range(13, step = increment, length = nrstages)
            stage += 1
            for (ii,j) in enumerate(products)
                tmpT = Float64(data[i,ii+1])
                if tmpT != 0.0
                    count[ii] +=1
                    push!(operations_product[j],string("OP_",count[ii]))

                    # check if multiple machines on stage
                    if length(stage_resources[stage]) > 1
                        # sample compatible machines uniformly 
                        merge!(ops_mach_comp[j], Dict(string("OP_",count[ii]) => sample(stage_resources[stage],
                                                                                rand(DiscreteUniform(max(stage_resources[stage]-2,1),
                                                                                stage_resources[stage])))))
                    else
                        merge!(ops_mach_comp[j], Dict(string("OP_",count[ii]) => stage_resources[stage]))
                    end

                    merge!(processing_product[j], Dict(string("OP_",count[ii]) =>
                        Dict(m => distribution(distributiontype, Float64(rand(DiscreteUniform(tmpT-10,tmpT+10))), ratiominmean, ratiomaxmean)
                        for m in ops_mach_comp[j][string("OP_",count[ii])])))
                    merge!(product_ops_stage[j], Dict(string("OP_",count[ii]) => stage))
                    merge!(product_stage_ops[j], Dict(stage => string("OP_",count[ii])))
                end
            end
        end
        operations = unique([i for x in values(operations_product) for i in x])
        
        # individual jobs
        if case[2] =='i'
            for (i,p) in enumerate(products)
                # TODO add due date based on lb and ub provided in instances?
                orders[string("ORD_",i)] = Dict("product" => p, "due_date" => nothing)
                nrjobs +=1
            end
        # product groups
        else
            count = 0
            for p in products
                # sample number of jobs per product
                tmpNrjobs = rand(DiscreteUniform(nrjobsperproduct[1], nrjobsperproduct[2]))
                for _ in 1: tmpNrjobs
                    count +=1
                    nrjobs +=1
                    # TODO add due date based on lb and ub provided in instances?
                    orders[string("ORD_",count)] = Dict("product" => p, "due_date" => nothing)
                end
            end
        end

        # same as ii but sample setup for each machine / check compatibility
        setup = Dict(m => Dict(p => Dict() for p in products) for m in resources)
        for (i,j) in enumerate(range(16,step = increment, length = nrstages))
            for (ii,jj) in enumerate(j:(j+nrproducts-1))
                for i3 in 1:nrproducts
                    for m in stage_resources[i]
                        if i in keys(product_stage_ops[products[i3]]) && i in keys(product_stage_ops[products[ii]])
                            if m in ops_mach_comp[products[i3]][product_stage_ops[products[i3]][i]] && m in ops_mach_comp[products[ii]][product_stage_ops[products[ii]][i]]
                                merge!(setup[m][products[ii]], Dict(products[i3] =>
                                    distribution(distributiontype,data[jj,i3+1] == 90000 ? 0.0 : Float64(data[Int(jj),i3+1]),ratiominmean, ratiomaxmean)))
                            else
                                merge!(setup[m][products[ii]], Dict(products[i3] => Dict("type" => "Nonexisting")))
                            end
                        else
                            merge!(setup[m][products[ii]], Dict(products[i3] => Dict("type" => "Nonexisting")))
                        end
                    end
                end
            end
        end
    end

    # concatenate all info in one dict
    instancedict = Dict()
    merge!(instancedict,Dict("NrJobs" => nrjobs))
    merge!(instancedict,Dict("orders" => orders)) # orders
    merge!(instancedict,Dict("operations_per_product" => operations_product)) # ops per products
    merge!(instancedict,Dict("operations" => operations)) # operations
    merge!(instancedict,Dict("operation_machine_compatibility" => ops_mach_comp)) # machine compatibility
    merge!(instancedict,Dict("NrStages" => nrstages)) # NrStages
    merge!(instancedict,Dict("products" => products)) # products
    merge!(instancedict,Dict("resources" => resources)) # resources/machines
    merge!(instancedict,Dict("resource_stage" => resource_stage)) # resources stages
    merge!(instancedict,Dict("stage_resource" => stage_resources)) # stage resources
    merge!(instancedict,Dict("product_operation_stage" => product_ops_stage)) # product ops stage
    merge!(instancedict,Dict("processing_time" => processing_product)) # Processing
    merge!(instancedict,Dict("setup_time" => setup)) # setups
    
    # specify file name to generate new instance
    samplesFile = string(dir,"/data/Flow_shops/Benchmark_Kurz/base_setting/data_",case,"/",filename,"_", case,"_",distributiontype[1:4],string(ratiominmean)[3:end],".json")
    open(samplesFile, "w") do f
        JSON.print(f,instancedict,4)
    end

end



print(setupmatrix(100,[10,50]))


