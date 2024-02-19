using StatsPlots
using Flux
using ParameterSchedulers
using SchedulingRL

#--------------------------------------------------------------------------------------------------------------
# setup environment
#--------------------------------------------------------------------------------------------------------------
instance = "useCase_2_stages"
# Env_AIA = createenv(as = "AIA",instanceType = "usecase", instanceName = instance)
Env_AIM = createenv(as = "AIM",instanceType = "usecase", instanceName = instance)
# Env_AIAR = createenv(as = "AIAR",instanceType = "usecase", instanceName = instance)
#--------------------------------------------------------------------------------------------------------------
# setup test environments with samples
#--------------------------------------------------------------------------------------------------------------
testenvs = [Dict("layout" => "Flow_shops" ,
                    "instancetype" => "usecase" ,
                    "instancesettings" => "base_setting",
                    "datatype" => "data_ii",
                    "instancename" =>instance)]

# testenvs_AIA = generatetestset(testenvs, 100, actionspace = "AIA")
testenvs_AIM = generatetestset(testenvs, 100, actionspace = "AIM")
# testenvs_AIAR = generatetestset(testenvs, 100, actionspace = "AIAR")

#--------------------------------------------------------------------------------------------------------------
# Features implemented
# JOB FEATURES
        # "DD"  :  job due date -> never updated use ones.
        # "RO"  :  remaining operations of job 
        # "RW"  :  remaining work of job
        # "ON"  :  average operating time of next operation of job
        # "JS"  :  job slack time (DD - RW - CT)
        # "RF"  :  routing flexibility of remaining operations of job

# MACHINES FEATURES
        # "EW"  :  expected future workload of a machine (proportionally if multiple possible machines)
        # "CW"  :  current workload of a machine (proportionally if multiple possible machines)
        # "JWM" :  Future jobs waiting for machine (proportionally if multiple possible machines)
        # "CJW" :  current jobs waiting (proportionally if multiple possible machines)

# JOB-MACHINES FEATURES
        # "TT"  :  total time of job machine pair (including waiting idle setup processing)
        # "PT"  :  processing time of job machine pair
        # "ST"  :  setup time of job machine pair
        # "NI"  :  required idle time of a machine
        # "NW"  :  needed waiting time of a job
        # "SLA" :  binary: 1 if setupless alternative is available when setup needs to be done, 0 otherwise
        # "BSA" :  binary: 1 if better setup alternative is available, 0 otherwise
        # "DBA" :  returns possitive difference between setup time of current setup and best alternative

# GENERAL
        # "CT"  :  current time

#--------------------------------------------------------------------------------------------------------------
# Makespan

# SIMPLE RULE SPT
# SPT_AIM = createagent(createRule(Priorityfunction("TT")),"AIM")
# result_rule_AIM = testagent(SPT_AIM, testenvs_AIM)

# # GES
# priorule = Priorityfunction("TT + EW + RW")
# Agent_GES_AIM = createagent(createGES("global",[Env_AIM], priorule), "AIM")
# println("GES weights: ", Agent_GES_AIM.approximator.bestweights)
# results_GES_AIM = trainagent!(Agent_GES_AIM, generations = 1, evalevery = 0, finaleval = true, testenvs = testenvs_AIM)
# println("GES weights: ", Agent_GES_AIM.approximator.bestweights)
# println("GES values: ", results_GES_AIM[1])
# # boxplot results
# graph_makespan = boxplot([result_rule_AIM[10], results_GES_AIM[10]],
#         label = ["SPT" "GES"],
#         title = "Gaps to optimal makespan",
#         ylabel = "gap",
#         xlabel = "model")



#--------------------------------------------------------------------------------------------------------------
# Total Tardiness

# SIMPLE RULE: EDD
EDD_AIM = createagent(createRule(Priorityfunction("DD")),"AIM",obj = [0.0,0.0,1.0,0.0,0.0,0.0])
result_rule_AIM = testagent(EDD_AIM,testenvs_AIM)
println("EDD AIM: ", result_rule_AIM[6])

# # GES
priorule = Priorityfunction("TT + EW + RW + JS + DD")
Agent_GES_AIM = createagent(createGES("global",[Env_AIM], priorule ), "AIM", obj = [0.0,0.0,1.0,0.0,0.0,0.0])
results_GES_AIM = trainagent!(Agent_GES_AIM, generations = 1, evalevery = 0, finaleval = true, testenvs = testenvs_AIM)
print("GES: " , results_GES_AIM[1])
# boxplot results
boxplot([result_rule_AIM[10], results_GES_AIM[10]],
        label = ["EDD" "GES"],
        title = "Differences to optimal total tardiness",
        ylabel = "difference",
        xlabel = "model")


