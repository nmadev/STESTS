using STESTS, JuMP, Gurobi

# Read data from .jld2 file
UCL, # hourly load for unit commitment, MW
genmap, # map of generators
GPmax, # maximum power output of generators
GPmin, # minimum power output of generators
GMC, # marginal cost of generators
transmap, # map of transmission lines
TX, # reactance of transmission lines
TFmax, # maximum power flow of transmission lines
GNLC, # no-load cost of generators
GRU, # ramp-up limit of generators
GRD, # ramp-down limit of generators
GSUC, # start-up cost of generators
GUT, # minimum up time of generators
GDT, # minimum down time of generators
GPini, # initial power output of generators
hydromap, # map of hydro units
HAvail, # availability of hydro units
renewablemap, # map of renewable units
RAvail = STESTS.read_jld2("./data/WECC240.jld2")

UCHorizon = Int(24) # optimization horizon for unit commitment model, 24 hours for WECC data, 4 hours for 3-bus test data
NDay = Int(size(UCL, 1) / UCHorizon)
EDSteps = Int(12) # number of 5-min intervals in a hour
EDL = repeat(UCL, inner = (EDSteps, 1)) # load for economic dispatch, MW, repeat by ED steps w/o noise
EDHorizon = Int(1) # optimization horizon for economic dispatch model, 1 without look-ahead, 12 with 1-hour look-ahead, 24 with 2-hour look-ahead, 48 with 4-hour look-ahead
#select first UCHorizon rows of UCL as initial input to unit commitment model
UCLInput = convert(Matrix{Float64}, UCL[1:UCHorizon, :]')
#select first EDHorizon rows of EDL as initial input to economic dispatch model
EDLInput = convert(Matrix{Float64}, EDL[1:EDHorizon, :]')

# Formulate unit commitment model
ucmodel = STESTS.unitcommitment(
    UCLInput,
    genmap,
    GPmax,
    GPmin,
    GMC,
    transmap,
    TX,
    TFmax,
    GNLC,
    GRU,
    GRD,
    GSUC,
    GUT,
    GDT,
    GPini,
    hydromap,
    HAvail,
    renewablemap,
    RAvail,
    Horizon = UCHorizon, # optimization horizon for unit commitment model, 24 hours for WECC data, 4 hours for 3-bus test data
    VOLL = 9000.0, # value of lost load, $/MWh
)

# Edit unit commitment model here
# set optimizer, set add_bridges = false if model is supported by solver
set_optimizer(ucmodel, Gurobi.Optimizer, add_bridges = false)
# # modify objective function
# @objective(ucmodel, Min, 0.0)
# # modify or add constraints
# @constraint(ucmodel, 0.0 <= ucmodel[:P][1,1] <= 0.0)

#  Formulate economic dispatch model
edmodel = STESTS.economicdispatch(
    EDLInput,
    genmap,
    GPmax,
    GPmin,
    GMC,
    transmap,
    TX,
    TFmax,
    GPini,
    hydromap,
    HAvail,
    renewablemap,
    RAvail,
    Horizon = UCHorizon, # optimization horizon for unit commitment model, 24 hours for WECC data, 4 hours for 3-bus test data
    VOLL = 9000.0, # value of lost load, $/MWh
)

# Edit economic dispatch model here
# set optimizer, set add_bridges = false if model is supported by solver
set_optimizer(edmodel, Gurobi.Optimizer, add_bridges = false)

# # modify objective function
# @objective(edmodel, Min, 0.0)
# # modify or add constraints
# @constraint(edmodel, 0.0 <= edmodel[:P][1,1] <= 0.0)

# Solve
cost = STESTS.solving(
    1,
    UCL,
    EDL,
    ucmodel,
    edmodel,
    UCHorizon = UCHorizon,
    EDSteps = EDSteps,
    EDHorizon = EDHorizon,
)