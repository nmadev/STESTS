# Unit Commitment, Unit Commitment Price, and Economic Dispatch Models



## Contents
1. [Unit Commitment](#unit-commitment)
    1. [Variables](#uc-variables)
    2. [Objective Function](#uc-objective-function)
    3. [Constraints](#uc-constraints)
2. [Unit Commitment Price](#unit-commitment-price)
    1. [Variables](#ucp-variables)
    2. [Objective Function](#ucp-objective-function)
    3. [Constraints](#ucp-constraints)
3. [Economic Dispatch](#economic-dispatch)
    1. [Variables](#ed-variables)
    2. [Objective Function](#ed-objective-function)
    3. [Constraints](#ed-constraints)

## Unit Commitment

### UC Variables
$$\begin{align*}
    n_{time} &: \text{Number of timesteps in UC horizon (24, 1-hour segments)} \\
    n_{trans} &: \text{Number of transmission lines between zones} \\
    n_{bus} &: \text{Number of buses (zones)} \\ 
    n_{UCgen} &: \text{Number of conventional generators} \\
    n_{storage} &: \text{Number of energy storage units} \\
    n_{GUC,Seg} &: \text{Number of segments for conventional generators}
\end{align*}$$

$$\begin{align*}
f &= M(n_{trans} \times n_{time}) &  \text{Transmission Line Loads}\\
\theta &= M(n_{bus} \times n_{time}) &  \text{Bus Phase Angles} \\
guc &= M(n_{UCgen} \times n_{time}) \geq 0 &  \text{Generator Output} \\
u &= M(n_{UCgen} \times n_{time}) \in {0, 1} &  \text{Generator on (1) / off (0) status} \\
v &= M(n_{UCgen} \times n_{time}) \in {0, 1} &  \text{Generator start-up (1), otherwise (0)} \\
w &= M(n_{UCgen} \times n_{time}) \in {0, 1} &  \text{Generator shut-down (1), otherwise (0)} \\
gh &= M(n_{bus} \times n_{time}) \geq 0 &  \text{Hydro output} \\
gs &= M(n_{bus} \times n_{time}) \geq 0 &  \text{Solar output} \\
gw &= M(n_{bus} \times n_{time}) \geq 0 &  \text{Wind output} \\
gh &= M(n_{bus} \times n_{time}) \geq 0 &  \text{Hydropower output} \\
s &= M(n_{bus} \times n_{time}) \geq 0 &  \text{Slack variable} \\
c &= M(n_{storage} \times n_{time}) \geq 0 &  \text{Storage charging} \\
d &= M(n_{storage} \times n_{time}) \geq 0 &  \text{Storage discharging} \\
e &= M(n_{storage} \times n_{time}) \geq 0 &  \text{Storage state of charge} \\
grr &= M(n_{UCgen} \times n_{time}) \geq 0 &  \text{Conventional generator reserve} \\
gucs &= M(n_{UCgen} \times n_{GUC,Seg} \times n_{time}) \geq 0 &  \text{Conventional generator segment output}
\end{align*}$$

### UC Objective Function

$$\begin{align*}
 \min_{u,v,guc,gucs,d,c,s} \bigg[ &\sum_{t = 1}^{n_{time}} \sum_{g = 1}^{N_{UCgen}} (FA \cdot GMC_{g} \cdot guc_{g,t} + FA \cdot GNLC_{g} \cdot u_{g,t} + GSUC_{g} \cdot v_{g,t}) \\
 + &\sum_{t = 1}^{n_{time}} \sum_{seg = 1}^{n_{UCseg}} \sum_{g = 1}^{UCgen} (FA \cdot GSMC_{g,seg} \cdot gucs_{g,seg,t})\\
 + &\sum_{t = 1}^{n_{time}} \sum_{es = 1}^{n_{storage}} (300 \cdot d_{es,t} - 0 \cdot c_{es,t}) \\
 + &\sum_{t = 1}^{n_{time}} \sum_{b = 1}^{n_{bus}} (VOLL \cdot s_{b,t}) \bigg]
\end{align*}$$

This objective function minimizes overall cost over conventional generator on/off status, generator start-up, generator output, energy storage charge/discharge, and slack conditions and is structured here as:

- The first line represents the cost from conventional generators split into generation cost, no load cost, and start-up cost, respectively. 
- The second line is the additional segment cost for the generators to account for non-linear generation marginal cost. 
- The third line represents the costs associated with charge/discharge of energy storage. The coefficients are used as place holders to initialize the model and is set during the solving script.
- The fourth line represents the high cost associated with any loss of load (slack conditions).

### UC Constraints

#### Load Balance Constraint

$$\begin{align*}
UCL_{b,t} &= genmap_{b} \cdot guc_{t} &\text{Conventional generator output} \\
    &+= gh_{b,t} &\text{Hydro output} \\
    &+= gs_{b,t} &\text{Solar output} \\
    &+= gw_{b,t} &\text{Wind output} \\
    &+= storagemap_{b} \cdot (d_{b,t} - c{b,t}) &\text{Energy storage input/output} \\
    &+= transmap_{b} \cdot f_{t} &\text{Transmission between buses} \\
    &+= s{b,t} &\text{Slack constraint at each bus} \\
    \forall\ &t \in \{1,...,n_{time}\}, \\
    &b \in \text{regions}
\end{align*}$$

The generation at each bus plus the net transmission to each bus is equal to the load at each bus at every timestep.

#### System Reserve Constraints

$$\begin{align*}
    grr_{g,t} &\leq GPmax_{g} \cdot u_{g,t} - guc_{g,t} \\
    grr_{g,t} &\leq GRU_{g} / 6. \\
    grr_{b,t} &\geq RM \cdot UCL_{b,t} \\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    g &\in \{1,...,n_{UCGen}\}, \\
    b &\in \{1,...,n_{bus}\}
\end{align*}$$

The reserve requirements are as follows:

- The first line indicates that the reserve requirement is upper-bounded by the the remaining output of the on conventional generators at any given time.
- The second line forces the ramp rate for 10 minutes to be greater than the reserve requirement. 
- The third line sets a lower bound on the reserve requirement as the reserve margin multiplied with the unit commitment load at each bus.

#### Transmission Constraints

$$\begin{align*}
    f_{l,t} &\leq T_{max,l} \\
    f_{l,t} &\geq -T_{max,l} \\
    f_{l,t} &= T\chi_{l} \cdot (\theta_{l1,t} - \theta_{l2,t}) \\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    l &\in \{1,...,n_{trans}\}
\end{align*}$$

- The first two lines are transmission line load constraints.
- The third line is a phase angle constraint for the lines.

#### Storage Constraints

- Charging/Discharging Maximum Power Constraints
$$\begin{align*}
    c_{i,t} &\leq EPC_{i} \\
    d_{i,t} &\leq EPD_{i} \\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    i &\in \{1,...,n_{storage}\}
\end{align*}$$

These are the maximum charge and discharge rates, respectively.

- State-of-charge constraints
$$\begin{align*}
    e_{i,t} &\leq ESOC_{i} \\
    e_{i,1} &= ESOC_{ini} + c_{i,1} * E\eta_{i} - d_{i,1} / E\eta_{i} \\
    e_{i,t} &= e_{i,t-1} + c_{i,1} * E\eta_{i} - d_{i,1} / E\eta_{i} & t \neq 1 \\
    e_{i,n_{time}} &\geq ESOC_{ini} \\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    i &\in \{1,...,n_{storage}\}
\end{align*}$$

- The first line enforces the maximum capacity of each energy storage unit.
- The second and third lines update the charge level of energy storage units given the charge/discharge amount at each time step.
- The fourth line requires the final state of charge of all energy storage units to be greater than the initial state of charge.

#### Must-Run Constraints

$$\begin{align*}
    u_{g,t} \geq GMustRun_{g} \\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    g &\in \{1,...,n_{UCGen}\}
\end{align*}$$

Generators that must run are constrained to be on while other generators are not constrained as such.

#### Conventional Generator Segment Constraints

$$\begin{align*}
    guc_{g,t} &= u_{g,t} \cdot GPmin_{g} + \sum_{seg} gucs_{g,seg,t} \\
    guc_{g,seg,t} &\leq GINCPmax_{g,t}  \\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    seg &\in \{1,...,n_{GUC,seg}\} \\
    g &\in \{1,...,n_{UCGen}\}
\end{align*}$$

- The first line constrains the total output of a generator to be the minimum generation plus the sum of the generation segments.
- The second line constrains the maximum generation output of each segment of every generator.

#### Generator Capacity Constraints

$$\begin{align*}
    guc_{g,t} &\geq u_{g,t} \cdot GPmin_{g} \\
    guc_{g,t} &\leq u_{g,t} \cdot GPmax_{g} \\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    g &\in \{1,...,n_{UCGen}\} 
\end{align*}$$

Constraints minimum and maximum generator outputs for all generators that are on at a given time.

#### Renewable Constraints

$$\begin{align*}
    gh_{i,t} &\leq HAvail_{i,t} \\
    gs_{i,t} &\leq SAvail_{i,t} \\
    gw_{i,t} &\leq WAvail_{i,t} \\
    \forall\ t &\in \{1,...,n_{time}\} \\
    i &\in \{1,...,n_{gen}\}
\end{align*}$$

Hydro, solar, and wind generation constraints, respectively.

#### Generator Ramp Constraints

$$\begin{align*}
    guc_{g,1} - GPIni_{i} &\leq GRU_{g} + GPMin_{g} \cdot v_{g,1} \\
    GPIni_{g} - guc_{g,1} &\leq GRD_{g} + GPMin_{g} \cdot w_{g,1} \\
    guc_{g,t + 1} - guc_{g,t} &\leq GRU_{g} + GPmin_{g} \cdot v_{g, t+1} & t\neq 1\\
    guc_{g,t} - guc_{g,t+1} &\leq GRD_{g} + GPmin_{g} \cdot w_{g, t+1} & t \neq 1\\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    g &\in \{1,...,n_{UCGen}\} 
\end{align*}$$

- The first two lines constrain the maximum output for the conventional generators directly after start-up and prior to shut-down, respectively.
- The third and fourth lines enforce the maximum ramp-up/ramp-down of the conventional generators.

#### State-Transition Constraints

$$\begin{align*}
    u_{g,1} - UInput_{i} &= v_{g,1} - w_{g,1} \\
    u_{g,t} - u_{g,t-1} &= v_{g,t} - w_{g,t}  & t \neq 1\\ 
    \forall\ t &\in \{1,...,n_{time}\}, \\
    g &\in \{1,...,n_{UCGen}\} 
\end{align*}$$

Constrains the generator up/down status with the transission variables $v$ and $w$.

#### Minimum Up/Down Time Constraints

$$\begin{align*}
    u_{g,t} &\geq \sum_{\max(1,GUT - t + 1)}^{t} v_{g,ts} \\
    1 - u_{g,t} &\geq \sum_{\max(1,GDT - t + 1)}^{t} w_{g,ts} \\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    g &\in \{1,...,n_{UCGen}\} 
\end{align*}$$

- The first line constrains the contiguous uptime for each generator to be at least the minimum uptime
- The second line constrains the contiguous downtime for each generator to be at least the minimum downtime

## Unit Commitment Price

### UCP Variables

$$\begin{align*}
    n_{time} &: \text{Number of timesteps in UC horizon (24, 1-hour segments)} \\
    n_{trans} &: \text{Number of transmission lines between zones} \\
    n_{bus} &: \text{Number of buses (zones)} \\ 
    n_{UCgen} &: \text{Number of conventional generators} \\
    n_{storage} &: \text{Number of energy storage units} \\
    n_{GUC,Seg} &: \text{Number of segments for conventional generators}
\end{align*}$$

$$\begin{align*}
f &= M(n_{trans} \times n_{time}) &  \text{Transmission Line Loads}\\
\theta &= M(n_{bus} \times n_{time}) &  \text{Bus Phase Angles} \\
guc &= M(n_{UCgen} \times n_{time}) \geq 0 &  \text{Generator Output} \\
U &= M(n_{UCgen} \times n_{time}) \in {0, 1} &  \text{Generator on (1) / off (0) status} \\
V &= M(n_{UCgen} \times n_{time}) \in {0, 1} &  \text{Generator start-up (1), otherwise (0)} \\
W &= M(n_{UCgen} \times n_{time}) \in {0, 1} &  \text{Generator shut-down (1), otherwise (0)} \\
gh &= M(n_{bus} \times n_{time}) \geq 0 &  \text{Hydro output} \\
gs &= M(n_{bus} \times n_{time}) \geq 0 &  \text{Solar output} \\
gw &= M(n_{bus} \times n_{time}) \geq 0 &  \text{Wind output} \\
gh &= M(n_{bus} \times n_{time}) \geq 0 &  \text{Hydropower output} \\
s &= M(n_{bus} \times n_{time}) \geq 0 &  \text{Slack variable} \\
c &= M(n_{storage} \times n_{time}) \geq 0 &  \text{Storage charging} \\
d &= M(n_{storage} \times n_{time}) \geq 0 &  \text{Storage discharging} \\
e &= M(n_{storage} \times n_{time}) \geq 0 &  \text{Storage state of charge} \\
grr &= M(n_{UCgen} \times n_{time}) \geq 0 &  \text{Conventional generator reserve} \\
gucs &= M(n_{UCgen} \times n_{GUC,Seg} \times n_{time}) \geq 0 &  \text{Conventional generator segment output}
\end{align*}$$

### UCP Objective Function

$$\begin{align*}
 \min_{guc,gucs,d,c,s} \bigg[ &\sum_{t = 1}^{n_{time}} \sum_{g = 1}^{N_{UCgen}} (FA \cdot GMC_{g} \cdot guc_{g,t}) \\
 + &\sum_{t = 1}^{n_{time}} \sum_{seg = 1}^{n_{UCseg}} \sum_{g = 1}^{UCgen} (FA \cdot GSMC_{g,seg} \cdot gucs_{g,seg,t})\\
 + &\sum_{t = 1}^{n_{time}} \sum_{es = 1}^{n_{storage}} (300 \cdot d_{es,t} - 0 \cdot c_{es,t}) \\
 + &\sum_{t = 1}^{n_{time}} \sum_{b = 1}^{n_{bus}} (VOLL \cdot s_{b,t}) \bigg]
\end{align*}$$

This objective function minimizes overall cost over conventional generator on/off status, generator start-up, generator output, energy storage charge/discharge, and slack conditions and is structured here as:

- The first line represents the cost from conventional generators. 
- The second line is the additional segment cost for the generators to account for non-linear generation marginal cost. 
- The third line represents the costs associated with charge/discharge of energy storage. The coefficients are used as place holders to initialize the model and is set during the solving script.
- The fourth line represents the high cost associated with any loss of load (slack conditions).

### UCP Constraints

#### Load Balance Constraint

$$\begin{align*}
UCL_{b,t} &= genmap_{b} \cdot guc_{t} &\text{Conventional generator output} \\
    &+= gh_{b,t} &\text{Hydro output} \\
    &+= gs_{b,t} &\text{Solar output} \\
    &+= gw_{b,t} &\text{Wind output} \\
    &+= storagemap_{b} \cdot (d_{b,t} - c{b,t}) &\text{Energy storage input/output} \\
    &+= transmap_{b} \cdot f_{t} &\text{Transmission between buses} \\
    &+= s{b,t} &\text{Slack constraint at each bus} \\
    \forall\ &t \in \{1,...,n_{time}\}, \\
    &b \in \text{regions}
\end{align*}$$

The generation at each bus plus the net transmission to each bus is equal to the load at each bus at every timestep.

#### System Reserve Constraints

$$\begin{align*}
    grr_{g,t} &\leq GPmax_{g} \cdot U_{g,t} - guc_{g,t} \\
    grr_{g,t} &\leq GRU_{g} / 6. \\
    grr_{b,t} &\geq RM \cdot UCL_{b,t} \\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    g &\in \{1,...,n_{UCGen}\}, \\
    b &\in \{1,...,n_{bus}\}
\end{align*}$$

The reserve requirements are as follows:

- The first line indicates that the reserve requirement is upper-bounded by the the remaining output of the on conventional generators at any given time.
- The second line forces the ramp rate for 10 minutes to be greater than the reserve requirement. 
- The third line sets a lower bound on the reserve requirement as the reserve margin multiplied with the unit commitment load at each bus.

#### Transmission Constraints

$$\begin{align*}
    f_{l,t} &\leq T_{max,l} \\
    f_{l,t} &\geq -T_{max,l} \\
    f_{l,t} &= T\chi_{l} \cdot (\theta_{l1,t} - \theta_{l2,t}) \\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    l &\in \{1,...,n_{trans}\}
\end{align*}$$

- The first two lines are transmission line load constraints.
- The third line is a phase angle constraint for the lines.

#### Storage Constraints

- Charging/Discharging Maximum Power Constraints
$$\begin{align*}
    c_{i,t} &\leq EPC_{i} \\
    d_{i,t} &\leq EPD_{i} \\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    i &\in \{1,...,n_{storage}\}
\end{align*}$$

These are the maximum charge and discharge rates, respectively.

- State-of-charge constraints
$$\begin{align*}
    e_{i,t} &\leq ESOC_{i} \\
    e_{i,1} &= ESOC_{ini} + c_{i,1} * E\eta_{i} - d_{i,1} / E\eta_{i} \\
    e_{i,t} &= e_{i,t-1} + c_{i,1} * E\eta_{i} - d_{i,1} / E\eta_{i} & t \neq 1 \\
    e_{i,n_{time}} &\geq ESOC_{ini} \\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    i &\in \{1,...,n_{storage}\}
\end{align*}$$

- The first line enforces the maximum capacity of each energy storage unit.
- The second and third lines update the charge level of energy storage units given the charge/discharge amount at each time step.
- The fourth line requires the final state of charge of all energy storage units to be greater than the initial state of charge.

#### Must-Run Constraints

Must run constraints are not used in the unit commitment price model.

#### Conventional Generator Segment Constraints

$$\begin{align*}
    guc_{g,t} &= U_{g,t} \cdot GPmin_{g} + \sum_{seg} gucs_{g,seg,t} \\
    guc_{g,seg,t} &\leq GINCPmax_{g,t}  \\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    seg &\in \{1,...,n_{GUC,seg}\} \\
    g &\in \{1,...,n_{UCGen}\}
\end{align*}$$

- The first line constrains the total output of a generator to be the minimum generation plus the sum of the generation segments.
- The second line constrains the maximum generation output of each segment of every generator.

#### Generator Capacity Constraints

$$\begin{align*}
    guc_{g,t} &\geq U_{g,t} \cdot GPmin_{g} \\
    guc_{g,t} &\leq U_{g,t} \cdot GPmax_{g} \\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    g &\in \{1,...,n_{UCGen}\} 
\end{align*}$$

Constraints minimum and maximum generator outputs for all generators that are on at a given time.

#### Renewable Constraints

$$\begin{align*}
    gh_{i,t} &\leq HAvail_{i,t} \\
    gs_{i,t} &\leq SAvail_{i,t} \\
    gw_{i,t} &\leq WAvail_{i,t} \\
    \forall\ t &\in \{1,...,n_{time}\} \\
    i &\in \{1,...,n_{gen}\}
\end{align*}$$

Hydro, solar, and wind generation constraints, respectively.

#### Generator Ramp Constraints

$$\begin{align*}
    guc_{g,1} - GPIni_{i} &\leq GRU_{g} + GPMin_{g} \cdot V_{g,1} \\
    GPIni_{g} - guc_{g,1} &\leq GRD_{g} + GPMin_{g} \cdot W_{g,1} \\
    guc_{g,t + 1} - guc_{g,t} &\leq GRU_{g} + GPmin_{g} \cdot V_{g, t+1} & t\neq 1\\
    guc_{g,t} - guc_{g,t+1} &\leq GRD_{g} + GPmin_{g} \cdot W_{g, t+1} & t \neq 1\\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    g &\in \{1,...,n_{UCGen}\} 
\end{align*}$$

- The first two lines constrain the maximum output for the conventional generators directly after start-up and prior to shut-down, respectively.
- The third and fourth lines enforce the maximum ramp-up/ramp-down of the conventional generators.

#### State-Transition Constraints

$U$, $V$, and $W$ are already set so no state-transition constraints are needed in the unit commitment price model.

#### Minimum Up/Down Time Constraints

$U$, $V$, and $W$ are already set so no up/down time constraints are needed in the unit commitment price model.

## Economic Dispatch

### ED Variables

$$\begin{align*}
    n_{time} &: \text{Number of timesteps in UC horizon (24, 1-hour segments)} \\
    n_{trans} &: \text{Number of transmission lines between zones} \\
    n_{bus} &: \text{Number of buses (zones)} \\ 
    n_{UCgen} &: \text{Number of conventional generators} \\
    n_{storage} &: \text{Number of energy storage units} \\
    n_{GUC,Seg} &: \text{Number of segments for conventional generators}
\end{align*}$$

$$\begin{align*}
f &= M(n_{trans} \times n_{time}) &  \text{Transmission Line Loads}\\
\theta &= M(n_{bus} \times n_{time}) &  \text{Bus Phase Angles} \\
guc &= M(n_{UCgen} \times n_{time}) \geq 0 &  \text{Generator Output} \\
U &= M(n_{UCgen} \times n_{time}) \in {0, 1} &  \text{Generator on (1) / off (0) status} \\
V &= M(n_{UCgen} \times n_{time}) \in {0, 1} &  \text{Generator start-up (1), otherwise (0)} \\
W &= M(n_{UCgen} \times n_{time}) \in {0, 1} &  \text{Generator shut-down (1), otherwise (0)} \\
gh &= M(n_{bus} \times n_{time}) \geq 0 &  \text{Hydro output} \\
gs &= M(n_{bus} \times n_{time}) \geq 0 &  \text{Solar output} \\
gw &= M(n_{bus} \times n_{time}) \geq 0 &  \text{Wind output} \\
gh &= M(n_{bus} \times n_{time}) \geq 0 &  \text{Hydropower output} \\
s &= M(n_{bus} \times n_{time}) \geq 0 &  \text{Slack variable} \\
c &= M(n_{storage} \times n_{time}) \geq 0 &  \text{Storage charging} \\
d &= M(n_{storage} \times n_{time}) \geq 0 &  \text{Storage discharging} \\
e &= M(n_{storage} \times n_{time}) \geq 0 &  \text{Storage state of charge} \\
grr &= M(n_{UCgen} \times n_{time}) \geq 0 &  \text{Conventional generator reserve} \\
gucs &= M(n_{UCgen} \times n_{GUC,Seg} \times n_{time}) \geq 0 &  \text{Conventional generator segment output} \\
Steps &= 12 & \text{Number of timesteps to consider in an hour} \\
PriceCap & & \text{Price cap to use with unfulfilled load}
\end{align*}$$

### ED Objective Function

### ED Constraints

$$\begin{align*}
 \min_{guc,gucs,d,c,s} \bigg[ &\sum_{t = 1}^{n_{time}} \sum_{g = 1}^{N_{UCgen}} (FA \cdot GMC_{g} \cdot guc_{g,t}) / Steps \\
 + &\sum_{t = 1}^{n_{time}} \sum_{seg = 1}^{n_{UCseg}} \sum_{g = 1}^{UCgen} (FA \cdot GSMC_{g,seg} \cdot gucs_{g,seg,t}) / Steps\\
 + &\sum_{t = 1}^{n_{time}} \sum_{es = 1}^{n_{storage}} (300 \cdot d_{es,t} - 0 \cdot c_{es,t})  / Steps \\
 + &\sum_{t = 1}^{n_{time}} \sum_{b = 1}^{n_{bus}} (PriceCap \cdot s_{b,t}) / Steps \bigg]
\end{align*}$$

This objective function minimizes overall cost over conventional generator on/off status, generator start-up, generator output, energy storage charge/discharge, and slack conditions and is structured here as:

- The first line represents the cost from conventional generators. 
- The second line is the additional segment cost for the generators to account for non-linear generation marginal cost. 
- The third line represents the costs associated with charge/discharge of energy storage. The coefficients are used as place holders to initialize the model and is set during the solving script.
- The fourth line represents the high cost associated with any loss of load (slack conditions). This is reduced to the price cap to closer match reality.

#### Load Balance Constraint

$$\begin{align*}
UCL_{b,t} &= genmap_{b} \cdot guc_{t} &\text{Conventional generator output} \\
    &+= gh_{b,t} &\text{Hydro output} \\
    &+= gs_{b,t} &\text{Solar output} \\
    &+= gw_{b,t} &\text{Wind output} \\
    &+= storagemap_{b} \cdot (d_{b,t} - c{b,t}) &\text{Energy storage input/output} \\
    &+= transmap_{b} \cdot f_{t} &\text{Transmission between buses} \\
    &+= s{b,t} &\text{Slack constraint at each bus} \\
    \forall\ &t \in \{1,...,n_{time}\}, \\
    &b \in \text{regions}
\end{align*}$$

The generation at each bus plus the net transmission to each bus is equal to the load at each bus at every timestep.

<!-- #### System Reserve Constraints

$$\begin{align*}
    grr_{g,t} &\leq GPmax_{g} \cdot U_{g,t} - guc_{g,t} \\
    grr_{g,t} &\leq GRU_{g} / 6. \\
    grr_{b,t} &\geq RM \cdot UCL_{b,t} \\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    g &\in \{1,...,n_{UCGen}\}, \\
    b &\in \{1,...,n_{bus}\}
\end{align*}$$

The reserve requirements are as follows:

- The first line indicates that the reserve requirement is upper-bounded by the the remaining output of the on conventional generators at any given time.
- The second line forces the ramp rate for 10 minutes to be greater than the reserve requirement. 
- The third line sets a lower bound on the reserve requirement as the reserve margin multiplied with the unit commitment load at each bus. -->

#### Transmission Constraints

$$\begin{align*}
    f_{l,t} &\leq T_{max,l} \\
    f_{l,t} &\geq -T_{max,l} \\
    f_{l,t} &= T\chi_{l} \cdot (\theta_{l1,t} - \theta_{l2,t}) \\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    l &\in \{1,...,n_{trans}\}
\end{align*}$$

- The first two lines are transmission line load constraints.
- The third line is a phase angle constraint for the lines.

#### Storage Constraints

- Charging/Discharging Maximum Power Constraints
$$\begin{align*}
    totalc_{i,t} &\leq EPC_{i} \\
    totald_{i,t} &\leq EPD_{i} \\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    i &\in \{1,...,n_{storage}\}
\end{align*}$$

These are the maximum charge and discharge rates, respectively.

- State-of-charge constraints
$$\begin{align*}
    totale_{i,t} &\leq ESOC_{i} \\
    e_{i,s,t} &= ESOC_{i} / ESSeg \\
    e_{i,s,1} &= ESOC_{ini,s} + (c_{i,s,1} * E\eta_{i} - d_{i,s,1} / E\eta_{i}) / Steps \\
    e_{i,s,t} &= e_{i,s,t-1} + (c_{i,s,1} * E\eta_{i} - d_{i,s,1} / E\eta_{i}) / Steps & t \neq 1 \\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    i &\in \{1,...,n_{storage}\}
\end{align*}$$

- The first line enforces the maximum capacity of each energy storage unit.
- The second and third lines update the charge level of energy storage units given the charge/discharge amount at each time step.
- The fourth line requires the final state of charge of all energy storage units to be greater than the initial state of charge.

#### Must-Run Constraints

Must run constraints are not used in the economic dispatch price model.

#### Conventional Generator Segment Constraints

$$\begin{align*}
    guc_{g,t} &= U_{g,t} \cdot GPmin_{g} + \sum_{seg} gucs_{g,seg,t} \\
    guc_{g,seg,t} &\leq GINCPmax_{g,t}  \\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    seg &\in \{1,...,n_{GUC,seg}\} \\
    g &\in \{1,...,n_{UCGen}\}
\end{align*}$$

- The first line constrains the total output of a generator to be the minimum generation plus the sum of the generation segments.
- The second line constrains the maximum generation output of each segment of every generator.

#### Generator Capacity Constraints

$$\begin{align*}
    guc_{g,t} &\geq U_{g,t} \cdot GPmin_{g} \\
    guc_{g,t} &\leq U_{g,t} \cdot GPmax_{g} \\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    g &\in \{1,...,n_{UCGen}\} 
\end{align*}$$

Constraints minimum and maximum generator outputs for all generators that are on at a given time.

#### Renewable Constraints

$$\begin{align*}
    gh_{i,t} &\leq HAvail_{i,t} \\
    gs_{i,t} &\leq SAvail_{i,t} \\
    gw_{i,t} &\leq WAvail_{i,t} \\
    \forall\ t &\in \{1,...,n_{time}\} \\
    i &\in \{1,...,n_{gen}\}
\end{align*}$$

Hydro, solar, and wind generation constraints, respectively.

#### Generator Ramp Constraints

$$\begin{align*}
    guc_{g,1} - GPIni_{i} &\leq GRU_{g} \\
    GPIni_{g} - guc_{g,1} &\leq GRD_{g} \\
    guc_{g,t - 1} - guc_{g,t} &\leq GRD_{g} / Steps & t\neq 1\\
    guc_{g,t} - guc_{g,t-1} &\leq GRU_{g} / Steps & t \neq 1\\
    \forall\ t &\in \{1,...,n_{time}\}, \\
    g &\in \{1,...,n_{UCGen}\} 
\end{align*}$$

- The first two lines constrain the maximum output for the conventional generators directly after start-up and prior to shut-down, respectively.
- The third and fourth lines enforce the maximum ramp-up/ramp-down of the conventional generators.

#### State-Transition Constraints

$U$, $V$, and $W$ are already set so no state-transition constraints are needed in the economic dispatch model.

#### Minimum Up/Down Time Constraints

$U$, $V$, and $W$ are already set so no up/down time constraints are needed in the economic dispatch model.