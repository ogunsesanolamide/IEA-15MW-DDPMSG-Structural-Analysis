%% rotor_fatigue_analysis.m
% ═══════════════════════════════════════════════════════════════════
%  IEA 15 MW PMSG — Rotor Back-Iron Fatigue Analysis
%
%  Dr Pablo's instruction: "Fatigue analysis: from wind speed variation
%  to LPTN transient → ΔT7(t) → thermal expansion δ(t) → cyclic
%  stress → rainflow counting → Palmgren-Miner damage D over 20 years"
%
%  Chain:
%    Wind speed V(t)  →  load fraction lf(t)
%    lf(t)  →  LPTN simulation  →  T7(t)  [Node 7, rotor back-iron]
%    T7(t)  →  ΔT7(t) = T7(t) − Tamb
%    ΔT7(t) →  thermal stress σ(t) = E·α·ΔT7(t)   [fully restrained]
%    σ(t)   →  rainflow cycle counting  →  (σ_a_i, n_i)
%    S-N:   N_i = (σ_f / σ_a_i)^m         [Basquin power law]
%    Miner: D_cycle = Σ (n_i / N_i)       [per simulation period]
%    Scale: D_20yr = D_cycle × (N_years × T_hours / T_sim_hours)
%
%  Material:  Structural steel (rotor back-iron)
%  Load:      V3 cyclic — 100%/30% every 2 hours (worst-case swing)
%
%  Author: O. Ogunsesan
% ═══════════════════════════════════════════════════════════════════
clear; clc; close all;

%% ── 1. MACHINE / MATERIAL PARAMETERS ────────────────────────────
P_rated  = 15e6;
eta      = 0.965;
Tamb     = 25;          % ambient [°C]
opts     = thermal_defaults();

Q_total = ((1 - eta) / eta) * P_rated;   % ≈ 544 kW

% Loss fractions
f_cu   = 0.45;
f_fe_t = 0.15;
f_fe_b = 0.10;
f_mag  = 0.20;
f_mech = 0.10;

% Structural steel — rotor back-iron
E_steel = 200e9;           % Young's modulus [Pa]
alpha   = 12e-6;           % CTE [1/K]  (structural steel)
rho_steel = 7850;          % density [kg/m³]
cp_steel  = 490;           % specific heat [J/(kg·K)]

% S-N Basquin parameters (structural steel, pulsating tension)
sigma_f = 600e6;   % fatigue strength coefficient [Pa]
m_exp   = 10;      % Basquin exponent (steel, R=-1 fully reversed)
sigma_e = 280e6;   % endurance limit [Pa]  (~0.5 × UTS for steel)

% Design life
years_design = 20;
hours_per_yr = 4000;      % offshore operational hours/year (conservative)
T_life_hr    = years_design * hours_per_yr;   % 80,000 h

%% ── 2. SIMULATE V3 CYCLIC PROFILE (100%/30% every 2h) ───────────
t_end = 150000;   % 41.7 h — captures many cycles including transient rise

lf_cyclic = @(t) 0.30 + 0.70*(mod(floor(t/7200),2)==0);

Q_sched = struct( ...
    'cu',   @(t) f_cu   * Q_total * lf_cyclic(t)^2, ...
    'fe_t', @(t) f_fe_t * Q_total * lf_cyclic(t),   ...
    'fe_b', @(t) f_fe_b * Q_total * lf_cyclic(t),   ...
    'mag',  @(t) f_mag  * Q_total * lf_cyclic(t)^2, ...
    'mech', @(t) f_mech * Q_total * lf_cyclic(t) );

fprintf('╔══════════════════════════════════════════════════════════╗\n');
fprintf('║   IEA 15 MW PMSG — Rotor Back-Iron Fatigue Analysis   ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');

fprintf('Running LPTN transient (cyclic 100%%/30%%, %.0f h) ...\n', t_end/3600);
out = thermal_transient_variable(Q_sched, Tamb, opts, t_end);
t   = out.t;
T7  = out.T(:,7);   % Rotor back-iron temperature

fprintf('  LPTN complete. T7: min=%.1f°C, max=%.1f°C, ΔT=%.1f K\n\n', ...
        min(T7), max(T7), max(T7)-min(T7));

%% ── 3. THERMAL STRESS HISTORY ────────────────────────────────────
%  Assume rotor back-iron is circumferentially restrained by the
%  structural ring:  σ_th(t) = E · α · ΔT7(t)   (fully constrained)
deltaT7 = T7 - Tamb;       % temperature rise above ambient [K]
sigma_th = E_steel * alpha * deltaT7;   % thermal stress [Pa]

fprintf('  Peak thermal stress σ_max = %.1f MPa\n', max(sigma_th)/1e6);
fprintf('  Min  thermal stress σ_min = %.1f MPa\n', min(sigma_th)/1e6);
fprintf('  Stress range Δσ           = %.1f MPa\n\n', (max(sigma_th)-min(sigma_th))/1e6);

%% ── 4. RAINFLOW COUNTING ─────────────────────────────────────────
%  Use a simple peak-valley extraction + range-mean counting.
%  (MATLAB Signal Processing Toolbox rainflow() not used — implemented
%   manually for portability.)

% Extract turning points (local peaks and valleys)
sigma_pv = extract_peaks_valleys(sigma_th);

% Rainflow counting  →  [amplitude, mean, count, range, mean] matrix
cycles = rainflow_simple(sigma_pv);   % returns [sigma_a, n_count]

if isempty(cycles)
    error('No cycles detected. Check signal and simulation time.');
end

sigma_a_vec = cycles(:,1);   % stress amplitude [Pa]
n_count_vec = cycles(:,2);   % number of half-cycles (convert: /2)

% Remove amplitudes below endurance limit (no damage)
above_endurance = sigma_a_vec > sigma_e;
sigma_a_used = sigma_a_vec(above_endurance);
n_used       = n_count_vec(above_endurance);

fprintf('  Rainflow: %d peaks/valleys → %d cycles detected\n', ...
        length(sigma_pv), sum(n_count_vec)/2);
fprintf('  Cycles above endurance limit (%.0f MPa): %d\n\n', ...
        sigma_e/1e6, sum(above_endurance));

%% ── 5. S-N AND PALMGREN-MINER ────────────────────────────────────
%  Basquin: N_i = (sigma_f / sigma_a_i)^m
if ~isempty(sigma_a_used)
    N_i   = (sigma_f ./ sigma_a_used) .^ m_exp;
    D_sim = sum(n_used ./ (2 * N_i));   % damage per simulation period
else
    D_sim = 0;
end

T_sim_hr = t_end / 3600;   % simulation length [hours]

% Extrapolate to 20-year life
%  Cyclic profile: 4 cycles/day (2h on, 2h off) → 4000 h/year
%  Each 2-hour block = one half-swing of ΔT7
%  Scale: D_20yr = D_sim × (T_life_hr / T_sim_hr)
if T_sim_hr > 0
    D_20yr = D_sim * (T_life_hr / T_sim_hr);
else
    D_20yr = 0;
end

% Annual damage rate
D_annual = D_sim * (hours_per_yr / T_sim_hr);

fprintf('  ─── PALMGREN-MINER DAMAGE SUMMARY ─────────────────────\n');
fprintf('  Simulation duration   : %.1f hours\n', T_sim_hr);
fprintf('  Damage in simulation  : D_sim   = %.4e\n', D_sim);
fprintf('  Annual damage rate    : D_annual = %.4e  per year\n', D_annual);
fprintf('  20-year fatigue damage: D_20yr  = %.4e\n', D_20yr);
if D_20yr >= 1.0
    fprintf('  ⚠  D_20yr ≥ 1 → FATIGUE FAILURE PREDICTED within design life!\n');
elseif D_20yr >= 0.1
    fprintf('  ⚠  D_20yr = %.2f → Meaningful fatigue accumulation.\n', D_20yr);
    fprintf('     Recommend reducing ΔT7 (better cooling or partial-load limit).\n');
else
    fprintf('  ✓  D_20yr = %.4f ≪ 1 → Fatigue life is adequate.\n', D_20yr);
    fprintf('     Rotor back-iron can sustain 20-year cyclic thermal loading.\n');
end

% Safety factor on fatigue (inverse of damage)
if D_20yr > 0
    SF_fatigue = 1 / D_20yr;
    fprintf('  Fatigue safety factor : SF = 1/D = %.1f\n', SF_fatigue);
end
fprintf('\n');

%% ── 6. THERMAL CYCLE COUNT ESTIMATE (20-year) ────────────────────
%  Cyclic profile: one complete on/off cycle every 2×2h = 4h = 14,400 s
cycle_period_hr = 4;    % hours per full 100%/30% cycle
n_cycles_life   = T_life_hr / cycle_period_hr;
fprintf('  Estimated thermal cycles over 20 years : %.0f cycles\n', n_cycles_life);
fprintf('  (assuming %d h/year operation, %.0f h period)\n\n', ...
        hours_per_yr, cycle_period_hr);

%% ── 7. FIGURE 1: T7(t) and σ_th(t) ─────────────────────────────
figure('Color','w','Name','Fatigue: T7 and Thermal Stress', ...
       'Position',[80 100 1100 650]);

% Load fraction
ax1 = subplot(3,1,1);
t_plot = linspace(0, t_end, 3000);
lf_vals = arrayfun(lf_cyclic, t_plot);
plot(t_plot/3600, lf_vals*100, 'LineWidth',1.8, 'Color',[0.47 0.67 0.19]);
xlabel('Time (hours)','FontSize',10);
ylabel('Load (%)','FontSize',10);
title('Cyclic Wind Load Profile (100%/30%, 2h period)','FontSize',12);
ylim([-5 115]); xlim([0 t_end/3600]);
grid on; box on;

% T7(t)
ax2 = subplot(3,1,2);
plot(t/3600, T7, 'LineWidth',2.0, 'Color',[0.47 0.67 0.19]);
hold on;
yline(max(T7), 'r:', 'LineWidth',1.0);
yline(min(T7), 'b:', 'LineWidth',1.0);
text(t_end/3600*0.02, max(T7)+1.5, sprintf('T_{7,max}=%.1f°C',max(T7)), ...
     'FontSize',9,'Color','r');
text(t_end/3600*0.02, min(T7)-3, sprintf('T_{7,min}=%.1f°C',min(T7)), ...
     'FontSize',9,'Color','b');
xlabel('Time (hours)','FontSize',10);
ylabel('T_7 Rotor Back-Iron (°C)','FontSize',10);
title(sprintf('Rotor Back-Iron Temperature — \\DeltaT_7 = %.1f K', max(T7)-min(T7)),'FontSize',12);
xlim([0 t_end/3600]); grid on; box on;

% σ_th(t)
ax3 = subplot(3,1,3);
plot(t/3600, sigma_th/1e6, 'LineWidth',2.0, 'Color',[0.85 0.33 0.10]);
hold on;
yline(sigma_e/1e6, 'k--', 'LineWidth',1.2, 'DisplayName', ...
      sprintf('Endurance limit (%.0f MPa)',sigma_e/1e6));
xlabel('Time (hours)','FontSize',10);
ylabel('\sigma_{thermal} (MPa)','FontSize',10);
title(sprintf('Cyclic Thermal Stress — \\sigma_{max}=%.1f MPa',max(sigma_th)/1e6),'FontSize',12);
legend('Location','southeast','FontSize',9);
xlim([0 t_end/3600]); grid on; box on;

linkaxes([ax1 ax2 ax3], 'x');

%% ── 8. FIGURE 2: S-N Curve with Operating Points ─────────────────
figure('Color','w','Name','S-N Curve + Rainflow', ...
       'Position',[120 80 900 500]);

% S-N curve
sigma_range = linspace(sigma_e*1.01, sigma_f*2, 500);
N_range = (sigma_f ./ sigma_range) .^ m_exp;

loglog(N_range, sigma_range/1e6, 'b-', 'LineWidth',2.0, 'DisplayName','S-N Basquin curve');
hold on;

% Endurance limit
loglog([1e3 1e12], [sigma_e/1e6 sigma_e/1e6], 'k--', 'LineWidth',1.2, ...
       'DisplayName',sprintf('Endurance limit %.0f MPa',sigma_e/1e6));

% Operating stress amplitudes from rainflow
if ~isempty(sigma_a_used)
    N_operating = (sigma_f ./ sigma_a_used) .^ m_exp;
    scatter(N_operating, sigma_a_used/1e6, 80, [0.85 0.33 0.10], 'filled', ...
            'DisplayName','Rainflow cycles (above S_e)');
end

xlabel('Number of cycles to failure N_f', 'FontSize',12);
ylabel('\sigma_a  Stress amplitude (MPa)', 'FontSize',12);
title('S-N Basquin Curve — Rotor Back-Iron Structural Steel', 'FontSize',13);
legend('Location','southwest','FontSize',10);
grid on; box on;
xlim([1e3 1e12]); ylim([50 800]);

%% ── 9. FIGURE 3: Cumulative Damage vs Time ───────────────────────
figure('Color','w','Name','Cumulative Miner Damage', ...
       'Position',[160 60 900 450]);

% Build cumulative damage in time
% Sort cycles by order of occurrence (approximate: uniform spread)
D_cumulative = linspace(0, D_sim, 1000);
t_axis_hr    = linspace(0, T_sim_hr, 1000);

% Extrapolate to 20 years
t_life_axis = linspace(0, T_life_hr, 500);
D_life_axis = D_sim / T_sim_hr * t_life_axis;

yyaxis left
plot(t_axis_hr, D_cumulative, 'LineWidth',2.0, 'Color',[0.47 0.67 0.19]);
ylabel('Miner damage D (simulation period)','FontSize',11);

yyaxis right
plot(t_life_axis/8760, D_life_axis, 'LineWidth',2.0, 'Color',[0.85 0.33 0.10], ...
     'LineStyle','--');
yline(1.0, 'r-', 'LineWidth',1.5);
text(18, 1.03, 'Failure D=1', 'Color','r','FontSize',10);
ylabel('Miner damage D (20-year projection)','FontSize',11);

xlabel('Time  (left: hours in simulation  |  right: years in service)','FontSize',11);
title(sprintf('Cumulative Palmgren-Miner Damage — D_{20yr} = %.4f', D_20yr),'FontSize',13);
grid on; box on;

%% ── 10. CONSOLE SUMMARY ─────────────────────────────────────────
fprintf('═══════════════════════════════════════════════════════════\n');
fprintf('  FATIGUE ANALYSIS SUMMARY — FOR CHAPTER\n');
fprintf('═══════════════════════════════════════════════════════════\n');
fprintf('  Load profile : Cyclic 100%%/30%% every 2 h\n');
fprintf('  T7 range     : %.1f°C – %.1f°C  (ΔT = %.1f K)\n', ...
        min(T7), max(T7), max(T7)-min(T7));
fprintf('  σ_th range   : %.1f – %.1f MPa\n', min(sigma_th)/1e6, max(sigma_th)/1e6);
fprintf('  E = %.0f GPa,  α = %.1e K⁻¹\n', E_steel/1e9, alpha);
fprintf('  S-N: σ_f=%.0f MPa, m=%d, σ_e=%.0f MPa\n', ...
        sigma_f/1e6, m_exp, sigma_e/1e6);
fprintf('  Thermal cycles / 20 yr : ~%.0f\n', n_cycles_life);
fprintf('  D_20yr = %.4e\n', D_20yr);
if D_20yr < 1
    fprintf('  → Fatigue life adequate. SF = %.1f\n', 1/max(D_20yr,1e-10));
else
    fprintf('  → ⚠ Fatigue failure risk. Redesign required.\n');
end
fprintf('═══════════════════════════════════════════════════════════\n\n');

%% ── 11. SAVE CSV ────────────────────────────────────────────────
outDir = fullfile(pwd,'outputs');
if ~exist(outDir,'dir'), mkdir(outDir); end

% Save rainflow summary
if ~isempty(cycles)
    sigma_a_MPa = cycles(:,1)/1e6;
    n_cyc       = cycles(:,2);
    N_fail      = (sigma_f ./ cycles(:,1)) .^ m_exp;
    Damage_i    = n_cyc ./ (2 * N_fail);
    T_cycle = table(sigma_a_MPa, n_cyc, N_fail, Damage_i, ...
                    'VariableNames',{'SigmaA_MPa','n_halfcycles','N_failure','Damage_i'});
    writetable(T_cycle, fullfile(outDir,'fatigue_rainflow.csv'));
    fprintf('Saved: outputs/fatigue_rainflow.csv\n');
end

% Save summary metrics
T_summary = table( ...
    {'Cyclic 100/30%'}, min(T7), max(T7), max(T7)-min(T7), ...
    max(sigma_th)/1e6, D_sim, D_20yr, n_cycles_life, ...
    'VariableNames',{'Profile','T7min_C','T7max_C','DeltaT7_K', ...
                     'SigmaMax_MPa','D_sim','D_20yr','Cycles_20yr'});
writetable(T_summary, fullfile(outDir,'fatigue_summary.csv'));
fprintf('Saved: outputs/fatigue_summary.csv\n');

%% ═══════════════════════════════════════════════════════════════════
%  LOCAL FUNCTIONS
% ═══════════════════════════════════════════════════════════════════

function pv = extract_peaks_valleys(x)
%EXTRACT_PEAKS_VALLEYS  Return turning-point sequence from signal x
    n  = length(x);
    dx = diff(x);
    % Turning points: sign changes in derivative
    keep = [true; (dx(1:end-1).*dx(2:end)) <= 0; true];
    pv = x(keep);
end

function cycles = rainflow_simple(pv)
%RAINFLOW_SIMPLE  Simplified 4-point rainflow counting on peak-valley sequence
%  Returns [sigma_amplitude, half_cycle_count]
%  Reference: ASTM E1049 simplified range-counting approach

    n = length(pv);
    stack = zeros(n,1);
    sp = 0;  % stack pointer
    result = zeros(n, 2);  % [amplitude, count]
    rc = 0;  % result count

    for i = 1:n
        sp = sp + 1;
        stack(sp) = pv(i);

        while sp >= 3
            s1 = stack(sp-2);
            s2 = stack(sp-1);
            s3 = stack(sp);
            X = abs(s3 - s2);
            Y = abs(s2 - s1);

            if X >= Y
                % Count range Y as a half-cycle
                rc = rc + 1;
                result(rc,:) = [Y/2, 0.5];
                % Discard s1 and s2 from stack
                stack(sp-2) = stack(sp);
                sp = sp - 2;
            else
                break;
            end
        end
    end

    % Residue: count remaining ranges as half-cycles
    for i = 1 : sp-1
        X = abs(stack(i+1) - stack(i));
        rc = rc + 1;
        result(rc,:) = [X/2, 0.5];
    end

    cycles = result(1:rc,:);
    % Merge same amplitudes
    if ~isempty(cycles)
        amp_vals = unique(cycles(:,1));
        merged = zeros(length(amp_vals),2);
        for k = 1:length(amp_vals)
            idx = cycles(:,1) == amp_vals(k);
            merged(k,:) = [amp_vals(k), sum(cycles(idx,2))];
        end
        cycles = merged;
    end
end
