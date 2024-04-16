push!(LOAD_PATH, "./src/")
using STESTS, JuMP, Gurobi, CSV, DataFrames, Statistics

function main(
    strategic::Bool = false, 
    ratio::Float64 = 0.5, 
    UCHorizon::Int = 25, 
    EDHorizon::Int = 1, 
    NDay::Int = 1, 
    EDSteps::Int = 12, 
    ESSeg::Int = 1, 
    FuelAdjustment::Float64 = 1.2, 
    ErrorAdjustment::Float64 = 0.25, 
    LoadAdjustment::Float64 = 1.0,
    FilePath::String = "."
)
    # Read data from .jld2 file 
    params =
        STESTS.read_jld2(FilePath * "/data/ADS2032_7RegionNoise_4hrBES_5GWBES_Strategic.jld2")
    # model_filenames = ["models/4hrmodel1_5.jld2"]
    model_filenames = ["models/4hrmodel1_5.jld2"]
    # for i in eachindex(params.Eeta)
    #     if params.Eeta[i] == 0.8
    #         params.EStrategic[i] = 0
    #     elseif params.Eeta[i] == 0.9
    #         params.EStrategic[i] = 1
    #     else
    #         # Handle unexpected case, if necessary
    #         println("Unexpected value in params.Eeta at index $i: ", params.Eeta[i])
    #     end
    # end

    # strategic = true
    # ratio = 0.5
    RM = 0.03
    VOLL = 9000.0
    # UCHorizon = Int(25) # optimization horizon for unit commitment model, 24 hours for WECC data, 4 hours for 3-bus test data
    # EDHorizon = Int(1) # optimization horizon for economic dispatch model, 1 without look-ahead, 12 with 1-hour look-ahead
    # NDay = 2

    # EDSteps = Int(12) # number of 5-min intervals in a hour
    # ESSeg = Int(1)
    PriceCap = repeat(
        repeat((range(220, stop = 1000, length = 40))', outer = (7, 1)),
        outer = (1, 1, EDHorizon),
    )
    # FuelAdjustment = 1.2
    # ErrorAdjustment = 0.25
    # LoadAdjustment = 1.0

    output_folder =
        "output/Strategic/UC" *
        "$UCHorizon" *
        "ED" *
        "$EDHorizon" *
        "_Strategic_" *
        "$strategic" *
        "_Seg" *
        "$ESSeg" *
        "_Load" *
        "$LoadAdjustment" *
        "_Fuel" *
        "$FuelAdjustment" *
        "_Error" *
        "$ErrorAdjustment" *
        "_ratio" *
        "$ratio" *
        "_MIP0.1_DARTDP"
    mkpath(output_folder)
    mkpath(output_folder * "/Strategic")
    mkpath(output_folder * "/NStrategic")

    # Update strategic storage scale base on set ratio
    if strategic == true
        STESTS.update_battery_storage!(params, ratio, output_folder)
    end

    DABidsSingle = Matrix(
        CSV.read(FilePath * 
            "/2032 ADS PCM V2.4.1 Public Data/Processed Data/StorageDABids.csv",
            DataFrame,
        ),
    )
    RTBidsSingle = Matrix(
        CSV.read(FilePath * 
            "/2032 ADS PCM V2.4.1 Public Data/Processed Data/StorageRTBids.csv",
            DataFrame,
        ),
    )
    DADBids = repeat(DABidsSingle[:, 1]', size(params.storagemap, 1), 1)
    DACBids = repeat(DABidsSingle[:, 2]', size(params.storagemap, 1), 1)
    RTDBids = repeat(RTBidsSingle[:, 1]', size(params.storagemap, 1), 1)
    RTCBids = repeat(RTBidsSingle[:, 2]', size(params.storagemap, 1), 1)

    bidmodels = STESTS.loadbidmodels(model_filenames)
    storagebidmodels = STESTS.assign_models_to_storages(
        params,
        bidmodels,
        size(params.storagemap, 1),
    )

    # Formulate unit commitment model
    ucmodel = STESTS.unitcommitment(
        params,
        Horizon = UCHorizon, # optimization horizon for unit commitment model, 24 hours for WECC data, 4 hours for 3-bus test data
        VOLL = VOLL, # value of lost load, $/MWh
        RM = RM, # reserve margin
        FuelAdjustment = FuelAdjustment,
    )

    # Edit unit commitment model here
    # set optimizer, set add_bridges = false if model is supported by solver
    set_optimizer(ucmodel, Gurobi.Optimizer, add_bridges = false)
    set_optimizer_attribute(ucmodel, "OutputFlag", 0)
    # # modify objective function
    # @objective(ucmodel, Min, 0.0)
    # # modify or add constraints
    # @constraint(ucmodel, 0.0 <= ucmodel[:P][1,1] <= 0.0)

    ucpmodel = STESTS.unitcommitmentprice(
        params,
        Horizon = UCHorizon, # optimization horizon for unit commitment model, 24 hours for WECC data, 4 hours for 3-bus test data
        VOLL = VOLL, # value of lost load, $/MWh
        RM = RM, # reserve margin
        FuelAdjustment = FuelAdjustment,
    )

    # Edit unit commitment model here
    # set optimizer, set add_bridges = false if model is supported by solver
    set_optimizer(ucpmodel, Gurobi.Optimizer, add_bridges = false)
    set_optimizer_attribute(ucpmodel, "OutputFlag", 0)
    # # modify objective function
    # @objective(ucpmodel, Min, 0.0)
    # # modify or add constraints
    # @constraint(ucpmodel, 0.0 <= ucpmodel[:P][1,1] <= 0.0)

    #  Formulate economic dispatch model
    edmodel = STESTS.economicdispatch(
        params,
        PriceCap, # value of lost load, $/MWh
        ESSeg = ESSeg,
        Horizon = EDHorizon,
        Steps = EDSteps, # optimization horizon for unit commitment model, 24 hours for WECC data, 4 hours for 3-bus test data
        FuelAdjustment = FuelAdjustment,
    )

    # Edit economic dispatch model here
    # set optimizer, set add_bridges = false if model is supported by solver
    set_optimizer(edmodel, Gurobi.Optimizer, add_bridges = false)
    set_optimizer_attribute(edmodel, "OutputFlag", 0)
    # # modify objective function
    # @objective(edmodel, Min, 0.0)
    # # modify or add constraints
    # @constraint(edmodel, 0.0 <= edmodel[:P][1,1] <= 0.0)

    # TODO: Move these:
    ESMC = 10.0
    BAWindow = 1

    # Solve
    timesolve = @elapsed begin
        UCcost, EDcost = STESTS.solving(
            params,
            NDay,
            strategic,
            DADBids,
            DACBids,
            RTDBids,
            RTCBids,
            ucmodel,
            ucpmodel,
            edmodel,
            output_folder,
            PriceCap,
            storagebidmodels,
            ESSeg = ESSeg,
            ESMC = ESMC,
            UCHorizon = UCHorizon,
            EDHorizon = EDHorizon,
            EDSteps = EDSteps,
            BAWindow = BAWindow,
            VOLL = VOLL,
            RM = RM,
            FuelAdjustment = FuelAdjustment,
            ErrorAdjustment = ErrorAdjustment,
            LoadAdjustment = LoadAdjustment,
        )
    end
    @info "Solving took $timesolve seconds."

    println("The UC cost is: ", sum(UCcost))
    println("The ED cost is: ", sum(EDcost))
end

function read_CLI()
    # TODO: add a verbose argument? Might make outputs easier to read
    if size(ARGS, 1) != 11
        main()
    else
        strategic = cmp(ARGS[1], "strategic") == 0 ? true : false
        ratio = parse(Float64, ARGS[2])
        UCHorizon = parse(Int, ARGS[3])
        EDHorizon = parse(Int, ARGS[4])
        NDay = parse(Int, ARGS[5])
        EDSteps = parse(Int, ARGS[6])
        ESSeg = parse(Int, ARGS[7])
        FuelAdjustment = parse(Float64, ARGS[8])
        ErrorAdjustment = parse(Float64, ARGS[9])
        LoadAdjustment = parse(Float64, ARGS[10])
        data_file_path = ARGS[11]
        main(strategic, ratio, UCHorizon, EDHorizon, NDay, EDSteps, ESSeg, 
             FuelAdjustment, ErrorAdjustment, LoadAdjustment, data_file_path)
    end
end

read_CLI()