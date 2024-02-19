mutable struct GES <: AbstractApproximator
    granularity::String
    envs::Vector{Env}
    objective::Vector{Any}
    priorityfunction::Priorityfunction
    bestweights::Vector{Float32}
    rng::AbstractRNG
    trainable::Bool
end

function createGES(granularity::String, env::Vector{Env}, prio::Priorityfunction; obj = [], rng = Random.default_rng(), kwargs...)
    if granularity == "global"
        bestweights = [0.0 for _ in 1:numberweights(prio)]
    else
    # TODO stage and resource granualrity
        error("not implemented yet")
    end
    GES(granularity, env, obj, prio, bestweights,rng, true) # TODO multiple envs...
end

function train!(a::Agent{GES}, generations, evalevery, testenvs, finaleval; showinfo = false, showprogressbar = true, TBlog = false)
    if evalevery > 0 && !TBlog
        @warn "Eval is not stored since no TBlogger is active"
    end
    
    ges = a.approximator
    for env in ges.envs # reset envs before starting training
        resetenv!(env)
    end

    if showprogressbar p = Progress(generations, 1, "Training Weights") end
    if TBlog logger = TBLogger("logs/$(a.problemInstance)/$(a.type)_$(a.actionspace)", tb_increment) end #TODO change overwrite via kwargs? but log files are large!
    for i in 1:generations

        # TODO define a update! function for GES
        update!(ges, a.objective)
         
        # TODO define values to log and logger function
        # if TBlog TBCallback(logger) end

        if showprogressbar
            # TODO define values to show in progressbar
            # ProgressMeter.next!(p; showvalues = [
            #                                     (:actor_loss, al),
            #                                     (:critic_loss, cl),
            #                                     (:entropy_loss, el),
            #                                     (:loss, l),
            #                                     (:norm, n),
            #                                     (:mean_reward, r),
            #                                     (:explained_variance, ev)
            #                                     ]
            #                     )
        end
        if showinfo
            println("actor loss after iteration $i: ", al)
            println("critic loss after iteration $i: ", cl)
            println("entropy loss after iteration $i: ", el)
            println("loss after iteration $i: ", l)
            println("norm after iteration $i: ", n)
            println("mean reward after iteration $i: ", r)
            println("explained variance after iteration $i: ", ev)
        end

        if evalevery > 0 && TBlog
            if i % evalevery == 0
                a.model = [ges.bestweights, ges.priorityfunction]
                values = testagent(a, testenvs)
                if TBlog TBCallbackEval(logger, a, values[1], values[6]) end
                #TODO logging of value
            end
        end
    end
    a.model = [ges.bestweights, ges.priorityfunction]

    if finaleval
        values = testagent(a, testenvs)
        if TBlog TBCallbackEval(logger, a, values[1], values[6]) end
        return values
    end
end

function update!(ges::GES, objective)
    # TODO define update! function for GES
    
    # placeholder!
    ges.bestweights = rand(Float32, numberweights(ges.priorityfunction))
end

function test(a::Agent{GES},env,nrseeds)
    testGES(a.model[1], a.model[2], env, a.objective, nrseeds, a.rng)
end

function nextaction(a::Agent{GES},env)
    # TODO has to be adapted for non global GES
    translateaction(a.model[1], env, a.model[2])
end

function testGES(weights ,prio, env, objective, nrsamples ,rng)
    metrics = []
    fitness = []
    gaps = []
    objective = -objective

    for i in 1:nrsamples
        isempty(env.samples) ? pointer = nothing : pointer = i
        tmpfitness, tmpmetrics = evalGES(weights, prio, env, objective, pointer, rng)
        append!(metrics, tmpmetrics)
        append!(fitness, tmpfitness)

        if env.type == "usecase"
            if objective == [-1.0,-0.0,-0.0,-0.0,-0.0,-0.0]
                piobjective = env.samples[pointer]["objective_[1, 0]"]
                append!(gaps, (tmpfitness/piobjective) -1)
            else
                piobjective = env.samples[pointer]["objective_[0, 1]"]
                append!(gaps, (tmpfitness - piobjective))
            end
        else
            piobjective = env.samples[pointer]["objective"]
            append!(gaps, (tmpfitness/piobjective) -1)
        end
    end

    return sum(fitness),fitness, gaps
end

function evalGES(weights, prio, env, objective, pointer, rng)
    metrics = [0,0,0,0,0,0]
    # reset env
    resetenv!(env)
    setsamplepointer!(env.siminfo,pointer)
    t = false
    state = flatstate(env.state)
    while !t
        action = translateaction(weights, env, prio)
        nextstate, rewards, t, info = step!(env, action, rng)

        metrics += rewards
    end

    fitness = dot(objective,metrics)
    return fitness, metrics
end
