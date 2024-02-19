import docplex.cp.model as cp
import json
import pathlib
import os
import numpy as np
import random
import math


def get_machines_full(products, nr_stages, res_range, flexibility_score, product_operation_stage):
    d = [i for i in range(res_range[0], res_range[1]+1)]
    product_stages = {p : {s : 1 if s in product_operation_stage[p].values() else 0 for s in range(1, nr_stages+1)}  for p in products}
    product_nb_stages = {p : sum(product_stages[p].values()) for p in products}
    stage_machines = {s : 0 for s in range(1,nr_stages+1)}
    count = 0
    for s in range(1,nr_stages+1):
        if random.random() >= 0.7 and count < 1:
            stage_machines[s] = random.randint(res_range[0], res_range[1])
            count += 1
    mdl = cp.CpoModel()
    # variables
    M_s =  {s : cp.integer_var(name='M_{}'.format(s), domain = d)
            for s in range(1,nr_stages+1) 
            }   
    # constraints
    violation = cp.sum(cp.abs(cp.sum(M_s[s] * product_stages[p][s] for s in range(1, nr_stages+1)) - int(flexibility_score * product_nb_stages[p])) for p in products)
    mdl.add(cp.equal(M_s[s], stage_machines[s])  for s in range(1, nr_stages+1) if stage_machines[s] > 0) 
    mdl.add(cp.minimize(violation))
    res = mdl.solve(TimeLimit= 60, # TODO dynamic stopping cirteria? and other params to tune solver!
                    agent = "local",
                    execfile="C:/Program Files/IBM/ILOG/CPLEX_Studio221/cpoptimizer/bin/x64_win64/cpoptimizer.exe",
                    LogVerbosity = "Quiet",
                    trace_log = False)
    if res:
        print(res.get_objective_value()/len(products))
        nb_machines = np.zeros(nr_stages)
        for n in M_s:
            nb_machines[n-1] = res[M_s[n]]
        return nb_machines
    

def balance_full():
    processing_times = {}
    setup_times = {}

    return processing_times, setup_times


def get_setup_matrix(n, present_jobs:list, r):

    d = [0] + [i for i in range(r[0], r[1]+1)]

    mdl = cp.CpoModel()

    # variables
    S_ij =  { (i,j) : cp.integer_var(name='S_{}{}'.format(i,j), domain = d)
            for i in range(1,n+1) for j in range(1,n+1)
            }
    
    # constraints
    mdl.add(cp.diff(S_ij[i,j], S_ij[j,i]) for i in present_jobs for j in present_jobs if i != j)
    mdl.add(cp.diff(S_ij[i,j], 0) for i in present_jobs for j in present_jobs if i != j)
    mdl.add(cp.equal(S_ij[i,j], 0) for i in range(1,n+1) for j in range(1,n+1) if i == j or i not in present_jobs or j not in present_jobs)
    mdl.add(cp.less_or_equal(S_ij[i,j], S_ij[i,k] + S_ij[k,j]) for i in present_jobs for j in present_jobs for k in present_jobs if i != j and i != k and j != k)

    res = mdl.solve(TimeLimit= 600, # TODO dynamic stopping cirteria? and other params to tune solver!
                    agent = "local",
                    execfile="C:/Program Files/IBM/ILOG/CPLEX_Studio221/cpoptimizer/bin/x64_win64/cpoptimizer.exe",
                    LogVerbosity = "Quiet",
                    trace_log = False)

    if res:
        setupmatrix = np.zeros((n,n))
        for s in S_ij:
            setupmatrix[s[0]-1,s[1]-1] = res[S_ij[s]]


        return setupmatrix
    
# print(get_setup_matrix(10, [1,2,3,4,5], (10,30)))

def get_routing(products:list, res:list, nr_stages:int, product_operation_stage:dict,
                stage_res:dict, res_stage:dict, balanced:bool, flexibility_score:float,
                operation_machine_compatibility:dict,
                ):
    
    prod_stage = {i : [int(product_operation_stage[i][op]) for op in product_operation_stage[i]] for i in products}
    possible_res = {i : [r for s in prod_stage[i] for r in stage_res[s]] for i in products}

    mdl = cp.CpoModel()
    # variables
    A_ij =  {(i,j) : cp.integer_var(name='A_{}{}'.format(i,j), domain = [0,1])
                for i in products for j in res
            }

    mdl.add(A_ij[i,j] == 0 for i in products for j in res if j not in possible_res[i])
    mdl.add(cp.sum(A_ij[i,j] for i in products) == 1 for j in res)
    mdl.add(cp.sum(A_ij[i,j] for j in range(1,stage_res[s])) == 1 for i in products for s in prod_stage[i])
    mdl.add(cp.sum(A_ij[i,j] for i in products for j in res) == flexibility_score * len(products) * nr_stages)

    if balanced:
        obj = cp.sum(cp.max(cp.sum(A_ij[i,j] for j in res) for i in products) for s in range(1,nr_stages+1))
        mdl.add(cp.minimize(obj))

    res = mdl.solve(TimeLimit= 600, 
                    agent = "local",
                    execfile="C:/Program Files/IBM/ILOG/CPLEX_Studio221/cpoptimizer/bin/x64_win64/cpoptimizer.exe",
                    LogVerbosity = "Quiet",
                    trace_log = False)  
    if res:
        for a in A_ij:
            if a == 1:
                ops = "OP_" + str(prod_stage[a[0]].index(res_stage[a[1]])) 
                operation_machine_compatibility[str(a[0])][ops].append(str(a[1]))

    return operation_machine_compatibility

def createinstance(nr_stages:int, nr_products:int, res_range:tuple, skipping_prob:float,
                    full_routing:bool, flexibility_target:float, balanced:bool,
                    unrelated_res:bool, degree_of_unrelatedness:float, correlated_unrelatedness:bool,
                    processing_range:tuple, ratio_setup_processing:float = 1.0):
    """
    Creates an instance of the flow shop problem with the given parameters.
    """
    # generate Layout
    # Resources
    resources = []
    stage_resource = {}
    resource_stage = {}

    if full_routing:
        # products | routing | skipping
        products = ["PRODUCT_" + str(i+1) for i in range(nr_products)]
        operations = set()
        product_operation_stage = {}
        operations_per_product = {k :[] for k in products}
        operation_machine_compatibility = {}
        for p in products:
            count = 1
            stages_present = 0
            for i in range(1, nr_stages+1):
                if random.random() >= skipping_prob or (stages_present == 0 and i == nr_stages):
                    stages_present += 1
                    op_str = 'OP_{}'.format(count)
                    count += 1
                    operations.add(op_str)
                    product_operation_stage.setdefault(p, {}).setdefault(op_str, i)
                    operations_per_product[p].append(op_str)
        operations = list(operations)
        number_machine_stages = get_machines_full(products, nr_stages, res_range, flexibility_target, product_operation_stage)
        count = 1
        for i in range(1, nr_stages+1):
            tmp_res = []
            for _ in range(int(number_machine_stages[i-1])):
                resources.append('RES_{}'.format(count))
                tmp_res.append('RES_{}'.format(count))
                resource_stage['RES_{}'.format(count)] = str(i)
                count += 1
            stage_resource[str(i)] = tmp_res

        for p in products:
            for op_str in operations_per_product[p]:
                operation_machine_compatibility.setdefault(p, {}).setdefault(op_str, stage_resource[str(product_operation_stage[p][op_str])])

        processing_times, setup_times = balance_full()
        raise()

    else:
        count = 1
        for i in range(nr_stages):
            tmp_res = []
            for _ in range(random.randint(res_range[0], res_range[1])):
                resources.append('RES_{}'.format(count))
                tmp_res.append('RES_{}'.format(count))
                resource_stage['RES_{}'.format(count)] = str(i+1)
                count += 1
            stage_resource[str(i+1)] = tmp_res

    # products | routing | skipping
    flexibility_score = []
    products = ["PRODUCT_" + str(i+1) for i in range(nr_products)]
    operations = set()
    product_operation_stage = {}
    operations_per_product = {k :[] for k in products}
    operation_machine_compatibility = {}
    for p in products:
        count = 1
        for i in range(nr_stages):
            if random.random() >= skipping_prob:
                op_str = 'OP_{}'.format(count)
                count += 1
                operations.add(op_str)
                product_operation_stage.setdefault(p, {}).setdefault(op_str, i+1)
                operations_per_product[p].append(op_str)
                operation_machine_compatibility.setdefault(p, {}).setdefault(op_str, [])
                if full_routing:
                    operation_machine_compatibility[p][op_str] = stage_resource[str(i+1)]
                    flexibility_score.append(len(stage_resource[str(i+1)]))
                        
    operations = list(operations)
    if full_routing:
        flexibility_score_measure = sum(flexibility_score)/len(flexibility_score)
    else:
        operation_machine_compatibility = get_routing(products, resources, nr_stages, product_operation_stage,
                stage_resource, resource_stage, balanced, flexibility_target,
                operation_machine_compatibility)
        flexibility_score_measure = flexibility_target
    
    # processing | setups
    
    processing = {p : {op : {} for op in operations_per_product[p]} for p in products}
    if unrelated_res:
        if correlated_unrelatedness:
            base = {s: {p: random.randint(processing_range[0], processing_range[1]) for p in products} for s in range(1,nr_stages+1)}
            factor = {r: random.uniform(1-0.5*degree_of_unrelatedness, 1+ 0.5*degree_of_unrelatedness) for r in resources}

            for p in products:
                for op in operations_per_product[p]:
                    for res in operation_machine_compatibility[p][op]:
                        processing[p][op].setdefault(res, {}).setdefault("mean", round(base[product_operation_stage[p][op]][p] * factor[res]))

        else:
            for p in products:
                for op in operations_per_product[p]:
                    for res in operation_machine_compatibility[p][op]:
                        processing[p][op].setdefault(res, {}).setdefault("mean", random.randint(processing_range[0], processing_range[1]))

    else: #same time on any parallel machine
        for p in products:
            for op in operations_per_product[p]:
                tmp_time = random.randint(processing_range[0], processing_range[1])
                for res in operation_machine_compatibility[p][op]:
                    processing[p][op].setdefault(res, {}).setdefault("mean", tmp_time)


    setup_range = (math.floor(processing_range[0] * ratio_setup_processing), math.ceil(processing_range[1] * ratio_setup_processing))
    setup = {r:{} for r in resources}
    for r in resources:
        present_products = [p for p in products if r in operation_machine_compatibility[p][op] for op in operations_per_product[p]]
        matrix = get_setup_matrix(nr_products, present_products, setup_range)
        # tranlate matrix to setup dict
        for p in present_products:
            for pp in present_products:
                setup[r].setdefault(p, {}).setdefault(pp, matrix[products.index(p), products.index(pp)])
    
    # save instance as JSON

    # generate a figure?
    return flexibility_score_measure


createinstance(nr_stages= 10, nr_products = 10, res_range = (2,10), skipping_prob = 0.0,
                full_routing = True, flexibility_target = 3.0, balanced = True,
                unrelated_res = True, degree_of_unrelatedness = 0.2, correlated_unrelatedness = True,
                processing_range = (10,100), ratio_setup_processing = 1.0)