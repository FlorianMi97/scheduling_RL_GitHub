module SchedulingRL

using StatsBase
using Random
using JSON
using Plots
using GraphRecipes
using Distributions
using SparseArrays
using VegaLite
using DataFrames
using LinearAlgebra

using Flux
using ParameterSchedulers
using ProgressMeter
using Functors: @functor
using ChainRulesCore
using CircularArrayBuffers

# packages for outputs?
using PrettyTables
using Printf

# to hook outputs to TensorBoard
using TensorBoardLogger, Logging

# Write your package code here.
include("Sim/Environment.jl")
include("Agent.jl")

"""
    testing(experiment::Experiment)
"""
function testing()

end

export  createenv, setsamples!, statesize, actionsize,
        createGP, createE2E, createWPF, ActorCritic, GaussianNetwork, Priorityfunction, numberweights,
        createagent, updateagentsettings!, trainagent!, exportagent, showsettings, setenvs!, setobj!,
        testagent, creategantt, generatetestset, 
        createRule, createExpSequence, createRandomAction,
        createGES
        # add more visualization methods for results here?
        # and modes? like real time visualization of scheduling -> real time Gantt :D



end
