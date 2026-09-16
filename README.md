# IEA/NREL 15 MW DD-PMSG: Rotor Ring Structural Analysis

MATLAB implementation of the structural optimisation of the rotor ring for the IEA/NREL 15 MW offshore direct-drive permanent magnet synchronous generator (DD-PMSG). Covers the electromagnetic, inertial and thermal load cases, an analytical wall-thickness sweep, finite element verification, and fatigue life under measured wind loading.

Developed as part of a Master of Research thesis at Edinburgh Napier University, supervised by Dr Pablo Jaen-Sola.

Companion repository: [IEA-15MW-DDPMSG-Thermal-Analysis](https://github.com/ogunsesanolamide/IEA-15MW-DDPMSG-Thermal-Analysis), which provides the nodal temperatures this work takes as input.

## The problem

The rotor ring is governed by deformation, not strength. Magnet attraction across the air gap pulls the ring inward, and the air gap may not close by more than 2.03 mm, which is 20 per cent of its nominal value. At every feasible wall thickness the factor of safety against yield stays above 3, while the deformation margin is a few per cent. Any sensible optimisation therefore targets stiffness rather than stress.

## Headline result

| | Wall | Mass | Bore closure |
|---|---|---|---|
| As designed | 60 mm | 32.8 t | 1.00 mm |
| Optimised | 30 mm | 16.4 t | 2.00 mm |
| Minimum feasible | 29.5 mm | 16.1 t | 2.03 mm |

A 50 per cent mass reduction while remaining inside the air-gap constraint, with a factor of safety of 3.17 at the optimum.

## Method

**Electromagnetic loading** uses a 36-sector Maxwell stress method. Mode 0 applies a uniform 447 kPa around the bore. Mode 1 applies a sinusoidal distribution with a peak sector value of 461.7 kPa, representing rotor eccentricity. Mode 1 governs.

**Deformation** is solved with the Lamé exact solution for a thick-walled cylinder, applied per sector. This captures hoop response but cannot represent circumferential bending, which is the limitation the later topology optimisation work addresses.

**Load cases combined:** electromagnetic bore pressure, self-weight at 9.76 m/s² representing the 6 degree shaft tilt, centrifugal loading at 0.79 rad/s, rated torque of 21 MN·m, and thermal expansion driven by rotor temperatures from the thermal model.

**Verification** is against Bichan et al. (2024) for the air-gap closure criterion, and against a PDE Toolbox finite element model for displacement, stress and modal response.

**Fatigue** uses SCADA records from Penmanshiel Wind Farm. Wind speed drives the thermal model, temperature history drives thermal expansion, and the resulting deflection history is reduced by ASTM E1049-85 rainflow counting and accumulated by Palmgren-Miner against a Basquin curve with σ_f = 600 MPa and m = 10. The dominant cycle comes from extended shutdowns and cold restarts rather than from turbulence, because the rotor thermal time constant of 5.39 hours attenuates anything faster.

## What's in here

| File | Purpose |
|---|---|
| `em_pressure.m` | Maxwell stress across the air gap, 36-sector method, Mode 0 and Mode 1 |
| `Gravity_load.m` | Self-weight at 9.76 m/s², accounting for the 6 degree shaft tilt |
| `centrifugal_load.m` | Centrifugal loading at rated 0.79 rad/s |
| `torque_shear.m` | Shear from 21 MN·m rated torque |
| `combine_loads.m` | Superposes the load cases and writes the combined summary |
| `rotor_thickness_optimisation.m` | Analytical wall-thickness sweep against the closure constraint |
| `structural_optimisation_36sector.m` | 36-sector Lamé solution and sector-wise deformation |
| `FEA_Rotor_Ring_PDE.m` | Finite element verification: displacement, von Mises, modal shapes |
| `rotor_fatigue_analysis.m` | Rainflow counting and Palmgren-Miner damage accumulation |
| `fatigue_wind_driven_36sector.m` | Wind-driven fatigue using Penmanshiel SCADA records |

## Outputs

`outputs/` holds the computed load cases and results as CSV: air-gap closure, electromagnetic pressure, centrifugal and gravity loads, torque shear, slot insulation stress, thickness optimisation, fatigue rainflow and summary, and the combined structural load summary. `outputs/SolidWorks_Guide_IEA15MW.md` documents the geometry used to build the CAD model.

## Geometry and material

Rotor ring bore radius 5.080 m, axial length 2.170 m. Material SA216 WCB cast steel: Young's modulus 200 GPa, Poisson's ratio 0.3, density 7,850 kg/m³, yield 250 MPa.

The later ANSYS topology optimisation work uses AISI 304 instead, on the supervisor's instruction, and is kept in a separate repository.

## References

Gaertner, E. et al. (2020) *Definition of the IEA 15-Megawatt Offshore Reference Wind Turbine*. NREL/TP-5000-75698.

Bichan, M., Jaen-Sola, P., Gonzalez-Delgado, D. and Oterkus, E. (2024) 'On the integrity of large-scale direct-drive wind turbine electrical generator structures: an integrated design methodology for optimisation, considering thermal loads and novel techniques', *Machines*, 12(4), 277. doi: 10.3390/machines12040277.

McDonald, A.S., Mueller, M.A. and Polinder, H. (2008) 'Structural mass in direct-drive permanent magnet electrical generators', *IET Renewable Power Generation*, 2(1), pp. 3 to 15.

Penmanshiel Wind Farm SCADA data, Cubico Sustainable Investments, Zenodo, doi: 10.5281/zenodo.5946808.
