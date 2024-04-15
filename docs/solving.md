# solving.jl

## Contents
1. [Program Structue](#program-structure)
2. [Function Definitions](#function-defitions)
    1. [getLastOneIndex()](#getlastoneindex)
    2. [enforece_strictlu_decreasing_vector](#enforce_strictlu_decreasing_vector=)
    2. [solvingError()](#solvingerror)
    3. [setUCConstraints()](#setuccostraints)
    4. [writeUCtoCSV()](#writeuctocsv)
    5. [calculteDAP()](#calculatedap)
    6. [setEDConstraints()](#setedconstraints)
    7. [writeEDtoCSVandUpdateSOC()](#writeedtocsvandupdatesoc)
    8. [solving()](#solving)

## Program Structure

The main solving loop is called from <code>main.jl</code> or <code>main_CLI.jl</code> and proceeds as such:

[solving():](#solving)
1. Initialize data structures and matrices to hold simulation variables
2. Set optimizater parameters
3. Start simulation loop: <code>Day d</code>
    1. Calculate energy storage bids**
    2. Set UC Constraints and solve[*](#setuccostraints)
    3. Extract and record UC results[*](#writeuctocsv)
    4. Caclulate day-ahead price from UC results[*](#calculatedap)
    5. Generate non-strategic storage bids**
    6. Start simulation loop: <code>Hour h</code>
        1. Start simulation loop: <code>Timestep t</code>
            1. Set ED constraints from UC results and solve[*](#setedconstraints)
            2. Record ED results and update energy storage SOC[*](#writeedtocsvandupdatesoc)
            3. Update initial generation for the next day
4. Once the main solving loop finishes, record final results

Lines with * indicate a function call. ** calls are from <code>bidding.jl</code>.

## Function Defitions

### getLastOneIndex()
* Function:
    * Returns last index in every row of an matrix that is equal to one.
* Input Parameters:
    * <code>matrix</code>: Matrix of interest to find last one indices.
    * <code>vector</code>: Vector of indices to pull from if one does not exist in matrix row.
    * <code>vector2</code>: Vector of indices to pull from if one exists in matrix row.

### enforece_strictlu_decreasing_vector()
* Function:
    * Enforces vector to be strictly decreasing.
* Input Parameters:
    * <code>v</code>: Vector to enforce strict constraint upon.
    * <code>delta</code>: Margin to lower vector elements by if consecutive elements are equal or violating constraints. Defaults to 1e-5.

### solvingError()
* Function:
    * Returns a solving error if an optimal solution is not found in ED or UC solving. Terminates program.
* Input Parameters:
    * <code>model</code>: Either UC or ED model that was not optimized fully
    * <code>type</code>: Either "<code>ED</code>" or "<code>UC</code>" to indicate which model failed
    * <code>d</code>: Day of model at which the solving error occurred
    * <code>h</code>: Hour within the day of model at which the solving error occurred (0 if UC solving error)
    * <code>t</code>: Timestep within the hour within the day of model at which the solving error occurred (0 if UC solving error)

### setUCCostraints()
* Function:
    * Sets unit commitment constraints prior to solving
* Input Parameters:
    * <code>ucmodel</code>: Unit commitment model to constrain
    * <code>ucpmodel</code>: Unit commitment price model to constrain
    * <code>LInput</code>: Power load (demand) for each node over time
    * <code>HAvailInput</code>: Available hydropower input over the day for generation
    * <code>WAvailInput</code>: Available wind input over the day for geneation
    * <code>SAvailInput</code>: Available solar input over the day for generation
    * <code>DADBids</code>: Historical day-ahead discharge bids for energy storage
    * <code>DADBidsInput</code>: Day-ahead discharge bids for energy storage
    * <code>DACBidsInput</code>: Day-ahead charging bids for energy storage
    * <code>UCHorizon</code>: Optimization horizon for UC model (number of hours)
    * <code>RM</code>: Reserve margin as a proportino of hoursly day-ahead lead prediction

### writeUCtoCSV()
* Function:
    *  Writes unit commitment results to CSV by appending to an external CSV file
    * TODO: Look at changing this to a single open/save at the end?
* Input Parameters:
    * <code>params</code>: Various model and solving parameters
    * <code>output_folder</code>: Output folder path to write UC results
    * <code>ucmodel</code>: Unit commitment model 
    * <code>Udf</code>: Generator up/down dataframe from UC results
    * <code>Vdf</code>: Generator start-up dataframe from UC results
    * <code>Wdf</code>: Generator shut-down dataframe from UC results
    * <code>Sdf</code>: Generator slack dataframe from UC results

### calculateDAP()
* Function:
    * Calculates day-ahead price using unit commitment results 
* Input Parameters:
    * <code>params</code>: Various model and solving parameters
    * <code>ucpmodel</code>: Unit commitment price model to optimize
    * <code>UCHorizon</code>: Optimization horizon for UC model (number of hours)
    * <code>U</code>: Generator up/down status from UC results
    * <code>V</code>: Generator start-up status from UC results
    * <code>W</code>: Generator shut-down status from UC results
    * <code>GPIniInput</code>: Initial thermal generator output in each economic dispatch time step

### setEDConstraints()
* Function:
    * Sets economic dispatch constraints given unit commitment results, day ahead prices, and energy storage agents
* Input Parameters:
    * <code>params</code>: Various model and solving parameters
    * <code>edmodel</code>: Economic dispatch to model at a timestep
    * <code>EDV</code>: Generator start-up status for economic dispatch optimization
    * <code>EDW</code>: Generator shut-down status for economic dispatch optimization
    * <code>EDU</code>: Generator up/down status for economic dispatch optimization
    * <code>U</code>: List of gneerator up/down status for all generators
    * <code>EDGPIni</code>:
    * <code>EDSteps</code>: Number of steps used in economic dispatch solving per hour
    * <code>strategic</code>: Boolean representing if energy storage agents should bid strategically or not
    * <code>bidmodels</code>: List of bid models strategic energy storage agents can use
    * <code>db</code>:
    * <code>cb</code>: 
    * <code>EDDBidInput</code>: Economic dispatch discharge bid input for energy storage
    * <code>EDCBidInput</code>: Economic dispatch charge bid input for energy storage
    * <code>segment_length</code>: TODO: This.
    * <code>ESSeg</code>: Number of segments used in the energy storage agents
    * <code>RTDBids</code>: Real-time discharge bid for energy storage
    * <code>RTCBids</code>: Real-time charge bid for energy storage
    * <code>AdjustedEDL</code>: Adjusted economic dispatch load for constraints
    * <code>AdjustedEDSolar</code>: Adjusted economic dispatch solar generation available
    * <code>AdjustedEDWind</code>: Adjusted economic dispatch wind generation available
    * <code>all_UCprices_df</code>: Dataframe containing all unit commitment prices to append results to # TODO: Why is this and the next variable in this section? Check.
    * <code>all_EDprices_df</code>: Dataframe containing all economic dispatch prices to append results to
    * <code>EDHorizon</code>: Economic dispatch time horizon to look over
    * <code>d</code>: Day of ED step
    * <code>h</code>: Hour within the day of ED step
    * <code>t</code>: Timestep within the hour within the day of ED step
    * <code>ts</code>: Timestep within the entire simulation of ED step


### writeEDtoCSVandUpdateSOC()
* Function:
    * Writes economic dispatch results to CSV files and updates state of charge of all energy storage agents
* Input Parameters:
    * <code>params</code>: Various model and solving parameters
    * <code>output_folder</code>: Output folder path to write ED results
    * <code>edmodel</code>: Economic dispatch model
    * <code>EDDBidInput</code>: Economic dispatch discharge bid inputs for energy storage
    * <code>EDCBidInput</code>: Economic dispatch charge bid inputs for energy storage
    * <code>EDU</code>: Economic dispatch up/down status for generators
    * <code>EDV</code>: Economic dispatch start-up status for generators
    * <code>EDW</code>: Economic dispatch shut-down status for generators
    * <code>all_EDprices_df</code>: Dataframe containing all economic dispatch prices to append results to
    * <code>storagezone</code>: TODO: What is this?
    * <code>PriceCap</code>: Price cap used to prevent high price in loss of load events
    * <code>EDGSMC</code>: Thermal generator segment marginal cost over EDHorizon time segments
    * <code>EDGMCcost</code>: Cost of thermal generators
    * <code>EDVOLL</code>: Economic dispatch value of loss load
    * <code>EDEScost</code>: Economic dispatch energy storage cost
    * <code>EDcost</code>: Economid dispatch cost
    * <code>EDSteps</code>: Number of intervals in an hour
    * <code>d</code>: Day of ED step
    * <code>h</code>: Hour within the day of ED step
    * <code>t</code>: Timestep within the hour within the day of ED step
* Returns:
    * <code>EDGPIni</code>: 
    * <code>EDSOCini</code>:
    * <code>all_EDprices_df</code>:


### solving()
* Function:
    * Primary solving interface used by <code>main.jl</code> for running simulations
* Input Parameters:
    * <code>params</code>: Various model and solving parameters
    * <code>Nday</code>: Number of days to simulate
    * <code>strategic</code>: Boolean to indicate whether energy storage agents bid strategically using pre-trained price prediction models or not
    * <code>DADBids</code>: Historical day-ahead discharge bids for energy storage
    * <code>DACBids</code>: Historical day-ahead charge bids for energy storage
    * <code>RTDBids</code>: Historical real-time discharge bids for energy storage
    * <code>RTCBids</code>: Historical real-time charge bids for energy storage
    * <code>ucmodel</code>: Unit commitment model to optimize daily
    * <code>ucpmodel</code>: Unit commitment price model to optimize daily for day-ahead price projections
    * <code>edmodel</code>: Economic dispatch model to optimize every 5-minutes
    * <code>bidmodels</code>: Energy storage bidding models for strategic bidding
    * <code>output_folder</code>: Output folder path for UC and ED results
    * <code>PriceCap</code>: Real-time price cap to prevent high prices in loss of load event
    * <code>ESSeg</code>: Number of discretized bid segments for energy storage
    * <code>UCHorizon</code>: Optimization horizon for UC model (1 hour segments)
    * <code>EDHorizon</code>: Optimization horizon for ED model (5 minute segments)
    * <code>EDSteps</code>: Number of intervals in an hour
    * <code>VOLL</code>: Value of Loss Load
    * <code>RM</code>: Reserve margin as a proportion of day-ahead load predictino
    * <code>ErrorAdjustment</code>: Parameter for day-ahead forecast error normalization
    * <code>LoadAdjustment</code>: Parameter for day-ahead and real-time load normalization