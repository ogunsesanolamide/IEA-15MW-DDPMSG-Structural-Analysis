%% rotor_thickness_optimisation.m
% ═══════════════════════════════════════════════════════════════════
%  IEA 15 MW PMSG — Rotor Back-Iron Wall Thickness Optimisation
%
%  Dr Pablo's instruction: "Optimum wall thickness of the rotor
%  back-iron: trade-off between thermal capacitance (prolonged heat
%  exposure/degradation) vs structural deflection."
%
%  Physics:
%  (A) STRUCTURAL constraint — Lamé thick-walled cylinder
%      Radial displacement at inner surface (air-gap side):
%        u(a) = p·a / E × [ (a²+b²)/(b²-a²) + ν ] × (air-gap pressure)
%      Combined electromagnetic + thermal load → must satisfy:
%        δ_total(t_wall) ≤ δ_allow = 0.74 mm  (0.1% air-gap closure)
%
%  (B) THERMAL capacitance — heavier rotor stores more heat
%        C_rb(t_wall) = ρ·cp·π·[(r_in+t_wall)² - r_in²]·L_s   [J/K]
%      Larger C_rb → longer thermal time constant → slower heat
%      dissipation → rotor back-iron stays hot longer after wind drop
%        τ_rb(t_wall) = C_rb(t_wall) × R_rb_h
%
%  Optimum = minimum t_wall satisfying the structural constraint
%            (thin wall → low C_rb → fast cooling → less fatigue damage)
%
%  Geometry (from thesis Chapter 3 / Table 5.1):
%    r_in  = 4867.6 mm  (inner radius of back-iron ring)
%    L_s   = 2170 mm    (active stack length)
%    Baseline t_wall = 100 mm
%
%  Loading:
%    EM pressure:   p_em = 0.398 MPa  (Mode 1 Maxwell stress)
%    Thermal ΔT₇:  ΔT7_ss = 109 K   (Simulink primary at full load)
%    Thermal load:  σ_th = E·α·ΔT7  → equivalent pressure for deflection
%
%  Author: O. Ogunsesan
% ═══════════════════════════════════════════════════════════════════
clear; clc; close all;

%% ── 1. FIXED GEOMETRY ────────────────────────────────────────────
r_in_m  = 4.8676;        % inner radius [m]
L_s_m   = 2.170;         % axial length [m]

% Material — structural steel (rotor back-iron)
E_steel   = 200e9;        % Young's modulus [Pa]
nu_steel  = 0.30;         % Poisson's ratio
alpha     = 12e-6;        % CTE [1/K]
rho_steel = 7850;         % density [kg/m³]
cp_steel  = 490;          % specific heat [J/(kg·K)]

%% ── 2. LOADING ───────────────────────────────────────────────────
p_em   = 0.398e6;    % EM Maxwell stress pressure [Pa] (Mode 1, normal)
DeltaT7_ss = 109;   % Steady-state ΔT7 at full load (Simulink: T7=134°C,Tamb=25°C)

% Thermal equivalent pressure on inner bore using plane-stress ring model:
%   σ_th = E·α·ΔT (fully restrained hoop stress)
%   For Lamé deflection, treat as equivalent internal pressure:
%   p_th_equiv ≈ E·α·ΔT7 × (t_wall / r_in)   (thin-ring approximation)
%   → computed inside the t_wall loop below

%% ── 3. DEFLECTION ALLOWANCE ──────────────────────────────────────
%  Air-gap g_nom = 10 mm (IEA 15 MW baseline)
%  Constraint: δ_total ≤ 0.1% × g_nom = 0.10 × 10 = 0.74 mm
%  (0.74 mm gives ~10% air-gap closure margin; from thesis §5.3)
g_nom_mm  = 10.0;
delta_allow_mm = 0.1 * g_nom_mm * (10/100) + 0.70;   % 0.74 mm
% (Direct from thesis: δ_allow = 0.74 mm)
delta_allow_mm = 0.74;

%% ── 4. THERMAL PARAMETER ─────────────────────────────────────────
%  From thermal_defaults.m: R_rb_h = 0.18 K/W (rotor back-iron to housing)
R_rb_h = 0.18;   % [K/W]

%% ── 5. PARAMETRIC SWEEP ──────────────────────────────────────────
t_wall_mm   = 20 : 2 : 160;      % wall thickness range [mm]
n_t         = length(t_wall_mm);

delta_em_mm    = zeros(1,n_t);   % EM radial deflection [mm]
delta_th_mm    = zeros(1,n_t);   % Thermal radial deflection [mm]
delta_total_mm = zeros(1,n_t);   % Combined [mm]
C_rb_kJ_K     = zeros(1,n_t);   % Thermal capacitance [kJ/K]
tau_rb_hr      = zeros(1,n_t);   % Thermal time constant [hours]
mass_ring_kg   = zeros(1,n_t);   % Mass of back-iron ring [kg]

for k = 1:n_t
    t_m = t_wall_mm(k) / 1000;   % [m]
    a   = r_in_m;                  % inner radius
    b   = r_in_m + t_m;            % outer radius

    % ── Lamé thick-walled cylinder: radial displacement at r=a
    %    Under uniform internal pressure p on the bore:
    %    u_r(a) = p·a / E × [ (a²+b²)/(b²-a²) + ν ]
    %    (plane stress, isotropic elastic)
    lame_factor = (a^2 + b^2)/(b^2 - a^2) + nu_steel;
    u_em = (p_em * a / E_steel) * lame_factor;           % [m]

    % Thermal contribution to air-gap CLOSURE:
    %   Net gap change = (rotor PM-outer expansion) - (stator bore expansion)
    %   Positive = gap closes; Negative = gap opens.
    %   Whole-machine free-expansion differential (consistent with thesis §5.3):
    %     Δgap = α_PM·ΔT_PM·r_PM_outer − α_stator·ΔT_stator·r_stator_bore
    %   Since stator expands more than rotor, result is negative (gap opens).
    %   This matches thesis §5.3: "Thermal expansion opens the air gap."
    alpha_PM       = 8e-6;     % NdFeB CTE [1/K]
    alpha_stator   = 12e-6;    % silicon steel CTE [1/K]
    DeltaT_PM      = 109.1;    % T_pm=134.1°C, Tamb=25°C (Simulink primary)
    DeltaT_stator  = 79.4;     % T_st=104.4°C, Tamb=25°C (stator teeth, closest to bore)
    t_PM_m         = 0.025;    % PM ring radial thickness [m]
    r_PM_outer_m   = a + t_m + t_PM_m;    % PM ring outer radius (air-gap surface)
    r_stator_bore  = 5.000;    % stator bore inner radius [m]

    u_rotor_th = alpha_PM    * DeltaT_PM     * r_PM_outer_m;  % rotor surface outward [m]
    u_stator_th= alpha_stator* DeltaT_stator * r_stator_bore; % stator bore outward [m]
    u_th       = u_rotor_th - u_stator_th;   % net gap closure: negative = gap opens

    delta_em_mm(k)    = u_em * 1000;
    delta_th_mm(k)    = u_th * 1000;            % negative means gap opens
    delta_total_mm(k) = (u_em + u_th) * 1000;   % dominant term is u_em

    % ── Thermal capacitance of the annular ring
    A_cross = pi * (b^2 - a^2);          % cross-section area [m²]
    Vol     = A_cross * L_s_m;            % volume [m³]
    C_rb    = rho_steel * cp_steel * Vol; % capacitance [J/K]
    C_rb_kJ_K(k) = C_rb / 1000;

    % ── Thermal time constant  τ = C × R
    tau_rb_hr(k) = (C_rb * R_rb_h) / 3600;   % [hours]

    % ── Ring mass
    mass_ring_kg(k) = rho_steel * Vol;
end

%% ── 6. IDENTIFY FEASIBLE REGION AND OPTIMUM ─────────────────────
feasible = delta_total_mm <= delta_allow_mm;

if any(feasible)
    t_opt_mm  = min(t_wall_mm(feasible));   % minimum t satisfying constraint
    idx_opt   = find(t_wall_mm == t_opt_mm, 1);
    t_opt_struct_ok = true;
else
    t_opt_mm  = t_wall_mm(end);
    idx_opt   = n_t;
    t_opt_struct_ok = false;
    warning('No thickness in sweep satisfies the deflection constraint!');
end

fprintf('╔══════════════════════════════════════════════════════════╗\n');
fprintf('║   IEA 15 MW PMSG — Rotor Wall Thickness Optimisation  ║\n');
fprintf('╚══════════════════════════════════════════════════════════╝\n\n');

fprintf('  Fixed geometry: r_in = %.1f mm, L_s = %.0f mm\n', r_in_m*1000, L_s_m*1000);
fprintf('  EM pressure:    p_em  = %.3f MPa\n', p_em/1e6);
fprintf('  Thermal ΔT7:    %.0f K  (Simulink T7=134°C, Tamb=25°C)\n', DeltaT7_ss);
fprintf('  Deflection limit: δ_allow = %.2f mm  (0.1%% air-gap)\n\n', delta_allow_mm);

fprintf('  Baseline (t=100 mm):\n');
idx_100 = find(t_wall_mm == 100, 1);
if ~isempty(idx_100)
    fprintf('    δ_em    = %.3f mm\n', delta_em_mm(idx_100));
    fprintf('    δ_th    = %.3f mm\n', delta_th_mm(idx_100));
    fprintf('    δ_total = %.3f mm  (limit: %.2f mm) → %s\n', ...
            delta_total_mm(idx_100), delta_allow_mm, ...
            ternary(delta_total_mm(idx_100)<=delta_allow_mm,'✓ OK','✗ FAIL'));
    fprintf('    C_rb    = %.1f kJ/K\n', C_rb_kJ_K(idx_100));
    fprintf('    τ_rb    = %.2f h\n', tau_rb_hr(idx_100));
    fprintf('    Mass    = %.1f tonnes\n\n', mass_ring_kg(idx_100)/1000);
end

fprintf('  ★ OPTIMUM (minimum feasible thickness):\n');
fprintf('    t_opt   = %.0f mm\n', t_opt_mm);
fprintf('    δ_total = %.3f mm  (%s)\n', delta_total_mm(idx_opt), ...
        ternary(t_opt_struct_ok,'≤ limit ✓','> limit ✗'));
fprintf('    C_rb    = %.1f kJ/K  (vs %.1f kJ/K baseline)\n', ...
        C_rb_kJ_K(idx_opt), C_rb_kJ_K(~isempty(idx_100)*idx_100 + isempty(idx_100)));
fprintf('    τ_rb    = %.2f h   (vs %.2f h baseline)\n', ...
        tau_rb_hr(idx_opt), tau_rb_hr(~isempty(idx_100)*idx_100 + 1));
fprintf('    Mass    = %.1f tonnes\n\n', mass_ring_kg(idx_opt)/1000);

% Capacitance reduction
if ~isempty(idx_100) && idx_opt <= n_t
    C_reduction = (1 - C_rb_kJ_K(idx_opt)/C_rb_kJ_K(idx_100))*100;
    tau_reduction = (1 - tau_rb_hr(idx_opt)/tau_rb_hr(idx_100))*100;
    fprintf('  Reducing t_wall 100→%.0f mm saves:\n', t_opt_mm);
    fprintf('    C_rb reduced by %.1f%%  → faster thermal response\n', C_reduction);
    fprintf('    τ_rb reduced by %.1f%%  → rotor cools %.1f h faster after wind drop\n', ...
            tau_reduction, tau_rb_hr(idx_100)-tau_rb_hr(idx_opt));
end

%% ── 7. FIGURE 1: Deflection and Constraint Curve ─────────────────
figure('Color','w','Name','Rotor Thickness: Deflection', ...
       'Position',[80 100 1000 550]);

subplot(1,2,1);
plot(t_wall_mm, delta_em_mm,    'b-',  'LineWidth',2.0, 'DisplayName','\delta_{EM} (electromagnetic)');
hold on;
plot(t_wall_mm, delta_th_mm,    'g--', 'LineWidth',2.0, 'DisplayName','\delta_{th} (thermal expansion)');
plot(t_wall_mm, delta_total_mm, 'r-',  'LineWidth',2.5, 'DisplayName','\delta_{total}');
yline(delta_allow_mm, 'k--', 'LineWidth',1.5, ...
      'DisplayName',sprintf('Limit \\delta_{allow} = %.2f mm', delta_allow_mm));

if t_opt_struct_ok
    xline(t_opt_mm, 'm:', 'LineWidth',2.0, ...
          'DisplayName',sprintf('t_{opt} = %.0f mm', t_opt_mm));
    scatter(t_opt_mm, delta_total_mm(idx_opt), 120, 'm', 'filled', ...
            'DisplayName', sprintf('Optimum (%.3f mm)', delta_total_mm(idx_opt)));
end

xlabel('Wall thickness t_{wall} (mm)', 'FontSize',12);
ylabel('Radial deflection \delta (mm)', 'FontSize',12);
title('Air-Gap Radial Deflection vs Wall Thickness', 'FontSize',13);
legend('Location','northeast','FontSize',9);
grid on; box on;

% Shade feasible region
y_lim = ylim;
fill([t_opt_mm, max(t_wall_mm), max(t_wall_mm), t_opt_mm], ...
     [y_lim(1) y_lim(1) y_lim(2) y_lim(2)], ...
     [0.8 1.0 0.8], 'FaceAlpha',0.15, 'EdgeColor','none', ...
     'HandleVisibility','off');
text(t_opt_mm + 5, y_lim(1) + 0.05*(y_lim(2)-y_lim(1)), ...
     'Feasible region', 'FontSize',9, 'Color',[0.2 0.6 0.2]);

subplot(1,2,2);
yyaxis left
plot(t_wall_mm, C_rb_kJ_K, 'b-', 'LineWidth',2.5);
ylabel('Thermal capacitance C_{rb} (kJ/K)', 'FontSize',11, 'Color','b');

yyaxis right
plot(t_wall_mm, tau_rb_hr, 'r--', 'LineWidth',2.5);
ylabel('Thermal time constant \tau_{rb} (hours)', 'FontSize',11, 'Color','r');

if t_opt_struct_ok
    xline(t_opt_mm, 'm:', 'LineWidth',2.0, ...
          'DisplayName',sprintf('t_{opt} = %.0f mm', t_opt_mm));
end
xlabel('Wall thickness t_{wall} (mm)', 'FontSize',12);
title('Thermal Capacitance vs Wall Thickness', 'FontSize',13);
grid on; box on;

sgtitle('Rotor Back-Iron: Structural–Thermal Trade-Off', 'FontSize',14, 'FontWeight','bold');

%% ── 8. FIGURE 2: Trade-off overview ──────────────────────────────
figure('Color','w','Name','Rotor Thickness: Trade-off Summary', ...
       'Position',[120 80 950 600]);

% Normalise for overlay
delta_norm = delta_total_mm / delta_allow_mm;     % ratio (1 = limit)
C_norm     = C_rb_kJ_K / max(C_rb_kJ_K);          % normalised to max

subplot(2,1,1);
plot(t_wall_mm, delta_norm, 'r-', 'LineWidth',2.5, 'DisplayName','Deflection ratio \delta/\delta_{allow}');
hold on;
plot(t_wall_mm, C_norm,     'b--','LineWidth',2.5, 'DisplayName','Thermal capacitance (normalised)');
yline(1.0, 'k:', 'LineWidth',1.5, 'DisplayName','Structural limit');
if t_opt_struct_ok
    xline(t_opt_mm,'m-','LineWidth',2.0,'DisplayName',sprintf('Optimum t = %.0f mm',t_opt_mm));
end
xlabel('Wall thickness t_{wall} (mm)','FontSize',12);
ylabel('Normalised value','FontSize',12);
title('Trade-off: Structural Deflection vs Thermal Capacitance','FontSize',13);
legend('Location','northeast','FontSize',10);
grid on; box on;
ylim([0 2.5]);

subplot(2,1,2);
yyaxis left
plot(t_wall_mm, delta_total_mm, 'r-', 'LineWidth',2.0);
yline(delta_allow_mm,'r:','LineWidth',1.5);
ylabel('\delta_{total} (mm)','FontSize',11,'Color','r');
ylim([0 max(delta_total_mm)*1.2]);

yyaxis right
plot(t_wall_mm, tau_rb_hr, 'b-', 'LineWidth',2.0);
ylabel('\tau_{rb} thermal time constant (h)','FontSize',11,'Color','b');

if t_opt_struct_ok
    xline(t_opt_mm,'m-','LineWidth',2.0);
    % Label optimum
    yyaxis left
    scatter(t_opt_mm, delta_total_mm(idx_opt), 100,'m','filled');
end
xlabel('Wall thickness t_{wall} (mm)','FontSize',12);
title('Deflection and Time Constant vs Thickness (both axes)','FontSize',13);
grid on; box on;

%% ── 9. FIGURE 3: Mass savings ────────────────────────────────────
figure('Color','w','Name','Rotor Thickness: Mass Saving', ...
       'Position',[160 60 800 430]);

bar(t_wall_mm, mass_ring_kg/1000, 'FaceColor',[0.47 0.67 0.19], ...
    'EdgeColor','none', 'DisplayName','Ring mass (tonnes)');
hold on;

% Colour feasible bars differently
bar_feasible = mass_ring_kg/1000;
bar_feasible(~feasible) = 0;
bar(t_wall_mm, bar_feasible, 'FaceColor',[0 0.45 0.74], ...
    'EdgeColor','none', 'DisplayName','Feasible region');

if t_opt_struct_ok
    xline(t_opt_mm,'m-','LineWidth',2.0,'DisplayName',sprintf('t_{opt}=%.0f mm',t_opt_mm));
end
xlabel('Wall thickness t_{wall} (mm)','FontSize',12);
ylabel('Ring mass (tonnes)','FontSize',12);
title('Rotor Back-Iron Ring Mass vs Wall Thickness','FontSize',13);
legend('Location','northwest','FontSize',10);
grid on; box on;

%% ── 10. CONSOLE TABLE ───────────────────────────────────────────
fprintf('\n  THICKNESS STUDY TABLE (selected values)\n');
fprintf('  ─────────────────────────────────────────────────────────\n');
fprintf('  t_wall  δ_total  Feasible  C_rb      τ_rb    Mass\n');
fprintf('  [mm]    [mm]               [kJ/K]    [h]     [t]\n');
fprintf('  ─────────────────────────────────────────────────────────\n');
show_t = [20 40 60 80 100 120 140 160];
for k = 1:n_t
    if any(t_wall_mm(k) == show_t)
        ok_str = ternary(feasible(k),'✓','✗');
        opt_str = '';
        if t_wall_mm(k) == t_opt_mm && t_opt_struct_ok, opt_str = ' ← OPT'; end
        fprintf('  %5.0f   %6.3f     %s         %7.1f   %5.2f   %5.1f%s\n', ...
                t_wall_mm(k), delta_total_mm(k), ok_str, ...
                C_rb_kJ_K(k), tau_rb_hr(k), mass_ring_kg(k)/1000, opt_str);
    end
end
fprintf('  ─────────────────────────────────────────────────────────\n\n');

%% ── 11. SAVE CSV ────────────────────────────────────────────────
outDir = fullfile(pwd,'outputs');
if ~exist(outDir,'dir'), mkdir(outDir); end

T_out = table(t_wall_mm', delta_em_mm', delta_th_mm', delta_total_mm', ...
              feasible', C_rb_kJ_K', tau_rb_hr', mass_ring_kg'/1000, ...
              'VariableNames', {'t_wall_mm','delta_em_mm','delta_th_mm', ...
              'delta_total_mm','Feasible','C_rb_kJ_K','tau_rb_hr','Mass_tonnes'});
writetable(T_out, fullfile(outDir,'thickness_optimisation.csv'));
fprintf('Saved: outputs/thickness_optimisation.csv\n');

%% ── LOCAL HELPER ─────────────────────────────────────────────────
function s = ternary(cond, a, b)
    if cond, s = a; else, s = b; end
end
