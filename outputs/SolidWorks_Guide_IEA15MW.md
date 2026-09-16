# SolidWorks Geometry Guide — IEA 15 MW PMSG
## Complete Dimension Reference

All values in millimetres. Axial depth for ALL rings: **1700 mm**.

### Ring Dimensions (for circle tool — these are RADII)

When you click the Circle tool → click origin → drag → type in the popup box, SolidWorks expects the **RADIUS**.

| # | Feature Name     | Inner R (mm) | Outer R (mm) | Thickness | Material       | Status   |
|---|------------------|-------------|-------------|-----------|----------------|----------|
| 1 | Rotor_BackIron   | 4867.6      | 4967.6      | 100.0     | Si-steel       | DONE     |
| 2 | PM_Ring          | 4967.6      | 4992.6      | 25.0      | NdFeB          | TO DO    |
|   | *(Air-Gap)*      | *4992.6*    | *5000.0*    | *7.4*     | *Skip — empty* |          |
| 3 | Stator_Teeth     | 5000.0      | 5100.0      | 100.0     | Si-steel       | TO DO    |
| 4 | Stator_Yoke      | 5100.0      | 5235.0      | 135.0     | Si-steel       | TO DO    |
| 5 | Housing_Frame    | 5235.0      | 5275.0      | 40.0      | Struct. steel  | TO DO    |

### If Smart Dimension shows DIAMETER, use these:

| # | Feature Name     | Inner DIA (mm) | Outer DIA (mm) |
|---|------------------|----------------|-----------------|
| 2 | PM_Ring          | 9935.2         | 9985.2          |
| 3 | Stator_Teeth     | 10000.0        | 10200.0         |
| 4 | Stator_Yoke      | 10200.0        | 10470.0         |
| 5 | Housing_Frame    | 10470.0        | 10550.0         |

---

## Remaining Steps (4 rings to draw)

### RING 2: PM Layer

1. In Feature Tree → click **Front Plane**
2. Sketch tab → **Sketch**
3. **Circle tool** → click origin → drag → type **4967.6** → Enter
4. Circle tool again → click origin → drag → type **4992.6** → Enter
5. Green tick to close sketch
6. Features tab → **Extruded Boss/Base** → Depth = **1700** → tick
7. Right-click feature → Rename → **PM_Ring**

### RING 3: Stator Teeth

1. Front Plane → Sketch
2. Circle: **5000.0** (inner)
3. Circle: **5100.0** (outer)
4. Close sketch → Extrude **1700** → Rename → **Stator_Teeth**

### RING 4: Stator Yoke

1. Front Plane → Sketch
2. Circle: **5100.0** (inner)
3. Circle: **5235.0** (outer)
4. Close sketch → Extrude **1700** → Rename → **Stator_Yoke**

### RING 5: Housing / Frame

1. Front Plane → Sketch
2. Circle: **5235.0** (inner)
3. Circle: **5275.0** (outer)
4. Close sketch → Extrude **1700** → Rename → **Housing_Frame**

---

## After All 5 Rings Are Drawn

### Assign Materials (right-click each feature → Material → Edit Material)

| Feature          | Library Material         | Notes                                    |
|------------------|--------------------------|------------------------------------------|
| Rotor_BackIron   | AISI 1020 Steel          | Placeholder for Si-steel laminations     |
| PM_Ring          | Plain Carbon Steel       | NdFeB not in default library             |
| Stator_Teeth     | AISI 1020 Steel          | Placeholder for Si-steel laminations     |
| Stator_Yoke      | AISI 1020 Steel          | Placeholder for Si-steel laminations     |
| Housing_Frame    | AISI 1020 Steel          | Structural steel                         |

### Check Mass Properties

1. Evaluate tab → **Mass Properties**
2. Note down total mass (should be order ~200 tonnes for steel)
3. Save the part

---

## Thermal Loading — Steady-State Temperatures to Apply

These come from your 8-node LPTN model (100% rated load, T_amb = 25 C):

| Component        | Node | Temperature (C) | Delta T (K) |
|------------------|------|-----------------|-------------|
| Stator Windings  | T1   | 158             | 133         |
| Stator Teeth     | T2   | 115             | 90          |
| Stator Back-Iron | T3   | 50              | 25          |
| Housing/Frame    | T4   | 42              | 17          |
| Permanent Magnets| T6   | 144             | 119         |
| Rotor Back-Iron  | T7   | 80              | 55          |

### Thermal Expansion Results (from thermal_expansion.m)

| Metric                        | Value      | Safety     |
|-------------------------------|------------|------------|
| Nominal air-gap               | 7.40 mm    | —          |
| Stator bore outward           | +5.400 mm  | Gap grows  |
| Rotor surface outward         | +4.753 mm  | Gap shrinks|
| **Net gap change**            | **+0.647 mm** | **SAFE (+8.7%)** |
| Final hot air-gap             | 8.047 mm   | OK         |

### Upper-Bound Thermal Stresses

| Component        | Stress (MPa) | Yield (MPa) | Margin |
|------------------|-------------|-------------|--------|
| Windings (Cu)    | 271.3       | ~250 (ann.) | Tight  |
| Stator teeth     | 199.8       | ~350 (Si)   | OK     |
| Stator yoke      | 55.5        | ~350 (Si)   | Large  |
| Perm. magnets    | 152.3       | ~75 (brit.) | Review |
| Rotor back-iron  | 122.1       | ~350 (Si)   | OK     |
| Slot insulation  | 79.8        | —           | Check  |

---

## Next Steps After SolidWorks Geometry

1. **ANSYS Granta — Material Selection**
   - Import the geometry
   - Screen materials for thermal + mechanical constraints
   - CTE, yield strength, fatigue limit, density

2. **ANSYS Granta — DfM + Eco Audit**
   - Design for Manufacture analysis
   - Lifecycle Assessment (energy, CO2, recyclability)

3. **Chapter 4.2 — Structural Results**
   - Write up the structural analysis in thesis
