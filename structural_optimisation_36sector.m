% =========================================================================
% structural_optimisation_36sector.m
%
% 36-Sector Analytical Structural Optimisation — IEA/NREL 15 MW PMSG Rotor
%
% Geometry (IEA-15-240-RWT GitHub STEP file):
%   Inner bore radius  a = 5,080 mm
%   As-designed wall   t = 60 mm  (outer radius b = 5,140 mm)
%   Axial length       L = 2,170 mm
%   Nominal air-gap    g = 10 mm
%   Deformation limit  = 2.03 mm  (Bichan et al. 2024, Table 3)
%
% Load cases:
%   Mode 0 — uniform EM pressure 447 kPa  (FEA cross-validation basis)
%   Mode 1 — sinusoidal EM 433.4-461.7 kPa, 36-sector analytical method
%             per Bichan et al. (2024) / Dr P. Jaen-Sola supervision
%
% Material: Carbon Steel SA216 (Bichan et al. 2024)
%   E = 200 GPa, nu = 0.30, rho = 7850 kg/m^3
%   alpha = 1.15164e-5 /K, sigma_yield ~ 250 MPa
%
% Thermal inputs — Chapter 3A Simulink LPTN (rated load, T_amb = 25 C):
%   T7 Rotor back-iron : T_rb = 133.96 C  (DeltaT = 108.96 K)
%   T6 Permanent magnets: T_pm = 134.07 C
%   DeltaT_cyclic = 87 K (100%-to-30% wind transition, 30% load T_rb ~ 47 C)
%
% Fatigue: Basquin S-N  sigma_f = 600 MPa, m = 10  (Suresh 1998)
%
% Author    : O. Ogunsesan, Edinburgh Napier University, MRes 2025/26
% Supervisor: Dr P. Jaen-Sola
% Reference : Bichan et al. (2024) Machines 12, 277. doi:10.3390/machines12040277
% =========================================================================

clear; clc; close all;

%% ===== 1. GEOMETRY ======================================================
a           = 5.080;        % Inner bore radius [m]  (GitHub STEP file)
g_nom       = 0.010;        % Nominal air-gap [m]
L_axial     = 2.170;        % Axial stack length [m]
delta_allow = 2.03e-3;      % Max allowable bore closure [m]  (Bichan et al. Table 3)
t_designed  = 0.060;        % As-designed wall thickness [m]

% Thickness sweep: 50%-to-300% of as-designed 60 mm (Bichan et al. convention)
%   Lower bound = 60 x 0.50 = 30 mm; Upper bound = 60 x 4.00 = 240 mm
t_sweep = [0.025, 0.030, 0.040, 0.050, 0.060, ...
           0.080, 0.100, 0.120, 0.160, 0.200, 0.240];

%% ===== 2. MATERIAL (Carbon Steel SA216) =================================
E            = 200e9;       % Young's modulus [Pa]
nu           = 0.30;        % Poisson's ratio
rho          = 7850;        % Density [kg/m^3]
alpha        = 1.15164e-5;  % Coefficient of thermal expansion [1/K]
sigma_yield  = 250e6;       % Yield strength [Pa]
c_p          = 502;         % Specific heat [J/(kg.K)]

% Basquin S-N fatigue parameters (Suresh 1998 / Bichan et al.)
sigma_f      = 600e6;       % Fatigue strength coefficient [Pa]
m_basquin    = 10;          % Basquin exponent

%% ===== 3. LOAD PARAMETERS (Bichan et al. 2024) ==========================
% 3.1  EM Maxwell pressure
p_Mode0   = 447.00e3;       % Mode 0: uniform [Pa]
p_mean    = 447.55e3;       % Mode 1: mean [Pa]
p_amp     =  14.15e3;       % Mode 1: half-amplitude [Pa]
p_min     = p_mean - p_amp; % = 433.4 kPa
p_max     = p_mean + p_amp; % = 461.7 kPa

% 3.2  Other loads
T_torque  = 21e6;           % Rated torque [N.m]
g_eff     = 9.76;           % Effective gravity (6-deg shaft tilt) [m/s^2]
omega     = 0.79;           % Rated angular velocity [rad/s]

% 3.3  Thermal (Chapter 3A Simulink LPTN, rated load, T_amb = 25 C)
T_rb        = 133.96;       % Rotor back-iron temperature [C]
T_pm        = 134.07;       % PM temperature [C]
T_amb       = 25.0;         % Ambient [C]
DeltaT_rb   = T_rb - T_amb;    % = 108.96 K
DeltaT_cyclic = 87;         % Operational cycling range [K]

%% ===== 4. 36-SECTOR ANGULAR GRID =======================================
N_sec     = 36;
theta_deg = (0:10:350)';            % Sector centre angles [deg], 36x1
theta_rad = theta_deg * pi/180;
p_theta   = p_mean + p_amp .* sin(theta_rad);  % Sinusoidal EM pressure [Pa]

%% ===== 5. LAME FORMULAE =================================================
% Radial bore deflection (inward positive):
%   u(a) = (p * a / E) * [(a^2 + b^2)/(b^2 - a^2) + nu]
lame_delta = @(p, b) (p .* a / E) .* ((a^2 + b^2)./(b^2 - a^2) + nu);

% Hoop stress at inner bore:
%   sigma_h = p * (a^2 + b^2) / (b^2 - a^2)
lame_hoop  = @(p, b) p .* (a^2 + b^2) ./ (b^2 - a^2);

%% ===== 6. PARAMETRIC THICKNESS SWEEP ====================================
n_t = numel(t_sweep);

b_vec        = zeros(n_t,1);
delta_em_0   = zeros(n_t,1);   % Mode 0 bore closure [mm]
delta_em_1   = zeros(n_t,1);   % Mode 1 bore closure at p_max [mm]
sigma_h_0    = zeros(n_t,1);   % Mode 0 Lame hoop stress [Pa]
sigma_h_1    = zeros(n_t,1);   % Mode 1 Lame hoop stress at p_max [Pa]
tau_vec      = zeros(n_t,1);   % Torsional shear stress [Pa]
sigma_vm_0   = zeros(n_t,1);   % Mode 0 von Mises [Pa]
sigma_vm_1   = zeros(n_t,1);   % Mode 1 von Mises [Pa]
FOS_0        = zeros(n_t,1);
FOS_1        = zeros(n_t,1);
mass_ring    = zeros(n_t,1);   % Ring mass [kg]
C_therm      = zeros(n_t,1);   % Thermal capacitance [J/K]

for it = 1:n_t
    t  = t_sweep(it);
    b  = a + t;
    b_vec(it) = b;

    % Bore closure (Lame)
    delta_em_0(it) = lame_delta(p_Mode0, b) * 1e3;    % [mm]
    delta_em_1(it) = lame_delta(p_max,   b) * 1e3;    % [mm]

    % Hoop stress at bore (Lame)
    sigma_h_0(it)  = lame_hoop(p_Mode0, b);            % [Pa]
    sigma_h_1(it)  = lame_hoop(p_max,   b);            % [Pa]

    % Torsional shear stress at outer radius
    J_p = pi/2 * (b^4 - a^4);
    tau_vec(it) = T_torque * b / J_p;                  % [Pa]

    % Von Mises  sigma_VM = sqrt(sigma_h^2 + 3*tau^2)
    sigma_vm_0(it) = sqrt(sigma_h_0(it)^2 + 3*tau_vec(it)^2);
    sigma_vm_1(it) = sqrt(sigma_h_1(it)^2 + 3*tau_vec(it)^2);

    % Factor of safety
    FOS_0(it) = sigma_yield / sigma_vm_0(it);
    FOS_1(it) = sigma_yield / sigma_vm_1(it);

    % Mass and thermal capacitance
    mass_ring(it) = rho * pi * (b^2 - a^2) * L_axial;
    C_therm(it)   = mass_ring(it) * c_p;
end

% Deformation feasibility
feas_0 = delta_em_0 <= delta_allow * 1e3;   % logical
feas_1 = delta_em_1 <= delta_allow * 1e3;

%% ===== 7. THERMAL ANALYSIS ==============================================
% Bore thermal expansion (outward — increases air-gap)
delta_th_outward = alpha * a * DeltaT_rb * 1e3;   % [mm]

% Thermoelastic stress bounds
sigma_th_free  = 0;                              % free expansion [Pa]
sigma_th_ub    = alpha * E * DeltaT_rb;          % fully constrained [Pa]

%% ===== 8. FATIGUE (Basquin S-N, Suresh 1998) ============================
% Cyclic thermal stress amplitude for dominant 100%/30% wind cycle
sigma_a   = alpha * E * DeltaT_cyclic / 2;      % [Pa]  = 100.2 MPa
N_f       = (sigma_f / sigma_a)^m_basquin;      % cycles to failure
N_cyc_20  = 20000;                              % ~1000 transitions/yr x 20 yr
D_20yr    = N_cyc_20 / N_f;

%% ===== 9. 36-SECTOR HOOP STRESS (at as-designed t = 60 mm) =============
b60 = a + t_designed;
sigma_h_sectors_1 = lame_hoop(p_theta, b60);    % 36x1 [Pa] sinusoidal
sigma_h_sectors_0 = lame_hoop(p_Mode0, b60) .* ones(N_sec,1);  % uniform

%% ===== 10. RESULTS TABLE ================================================
idx_60  = find(abs(t_sweep - 0.060) < 1e-9);
idx_30  = find(abs(t_sweep - 0.030) < 1e-9);
idx_opt1 = find(feas_1, 1, 'first');

fprintf('\n');
fprintf('=======================================================================\n');
fprintf('  IEA 15 MW PMSG — 36-Sector Structural Optimisation\n');
fprintf('  a=5080 mm | g=10 mm | L=2170 mm | Material: SA216 | E=200 GPa\n');
fprintf('  Lame deformation limit: 2.03 mm (Bichan et al. 2024, Table 3)\n');
fprintf('=======================================================================\n');

fprintf('\n MODE 0 (uniform 447 kPa)  vs  MODE 1 (sinusoidal peak 461.7 kPa)\n');
fprintf('%-6s %-8s %-10s %-10s %-11s %-11s %-6s %-6s %-7s\n',...
    't[mm]','b[mm]','d_0[mm]','d_1[mm]','sVM_0[MPa]','sVM_1[MPa]','FOS0','FOS1','m[t]');
fprintf('%s\n', repmat('-',1,77));
for it = 1:n_t
    f0 = '';  if ~feas_0(it), f0=' INFEAS'; end
    f1 = '';  if ~feas_1(it), f1=' INFEAS'; end
    tag = '';
    if it == idx_opt1, tag = ' <-- Mode1 opt'; end
    if abs(t_sweep(it)-0.060)<1e-9 && it~=idx_opt1, tag = ' <-- as-designed'; end
    fprintf('%-6.0f %-8.0f %-10.3f %-10.3f %-11.2f %-11.2f %-6.2f %-6.2f %-7.1f%s%s%s\n',...
        t_sweep(it)*1e3, b_vec(it)*1e3,...
        delta_em_0(it), delta_em_1(it),...
        sigma_vm_0(it)/1e6, sigma_vm_1(it)/1e6,...
        FOS_0(it), FOS_1(it), mass_ring(it)/1e3, f0, f1, tag);
end
fprintf('%s\n', repmat('-',1,77));

fprintf('\n THERMAL ANALYSIS (Chapter 3A Simulink LPTN)\n');
fprintf('  T_rb = %.2f C  |  DeltaT_rb = %.2f K\n', T_rb, DeltaT_rb);
fprintf('  Thermal bore expansion (outward): delta_th = %.3f mm  [RELIEVES bore closure]\n', delta_th_outward);
fprintf('  Thermoelastic stress — free expansion : 0 MPa\n');
fprintf('  Thermoelastic stress — fully constrained : %.1f MPa  (upper bound)\n', sigma_th_ub/1e6);
fprintf('  Note: stator winding T1 = 146.9 C  [IEC Class F limit: 155 C, margin 8.1 C]\n');

fprintf('\n FATIGUE ANALYSIS (Basquin S-N, sigma_f=600 MPa, m=10)\n');
fprintf('  DeltaT_cyclic (100%%/30%% wind cycle) = %g K\n', DeltaT_cyclic);
fprintf('  Cyclic stress amplitude : sigma_a = %.1f MPa\n', sigma_a/1e6);
fprintf('  Cycles to failure       : N_f = %.2e\n', N_f);
fprintf('  20-year damage          : D_20yr = %.2e   (SAFE: D << 1.0)\n', D_20yr);

fprintf('\n KEY RESULTS\n');
fprintf('  Mode 0 minimum feasible t : %g mm  (delta_em = %.3f mm, margin %.1f%%)\n',...
    t_sweep(find(feas_0,1))*1e3, delta_em_0(find(feas_0,1)),...
    (delta_allow*1e3 - delta_em_0(find(feas_0,1)))/delta_allow/10);
fprintf('  Mode 1 minimum feasible t : %g mm  (delta_em = %.3f mm, margin %.1f%%)\n',...
    t_sweep(idx_opt1)*1e3, delta_em_1(idx_opt1),...
    (delta_allow*1e3 - delta_em_1(idx_opt1))/delta_allow/10);
fprintf('  Mass saving vs as-designed: %.1f t (%.0f%% reduction)\n',...
    (mass_ring(idx_60)-mass_ring(idx_opt1))/1e3,...
    (1-mass_ring(idx_opt1)/mass_ring(idx_60))*100);
fprintf('=======================================================================\n\n');

%% ===== 11. FIGURES ======================================================

% Figure 1: Bore closure vs wall thickness
figure('Name','Bore Closure','Color','w','Position',[50 50 900 430]);
hold on; grid on; box on;
plot(t_sweep*1e3, delta_em_0, 'b-o','LineWidth',1.8,'MarkerFaceColor','b',...
    'DisplayName','Mode 0 — uniform 447 kPa');
plot(t_sweep*1e3, delta_em_1, 'r-s','LineWidth',1.8,'MarkerFaceColor','r',...
    'DisplayName','Mode 1 — sinusoidal peak 461.7 kPa');
yline(delta_allow*1e3,'k--','2.03 mm limit (Bichan et al.)',...
    'LabelHorizontalAlignment','right','LineWidth',2);
xline(30,'b:','t_{opt} = 30 mm','LineWidth',1.5);
xlabel('Wall Thickness  t  [mm]','FontSize',11);
ylabel('Bore Closure  \delta_{em}  [mm]','FontSize',11);
legend('Location','northeast','FontSize',10);
title('IEA 15 MW PMSG Rotor — Bore Closure vs Wall Thickness (Lame Model)',...
    'FontSize',12,'FontWeight','bold');
ylim([0 max(delta_em_1)*1.15]);

% Figure 2: Von Mises stress and FOS vs wall thickness
figure('Name','Stress & FOS','Color','w','Position',[100 120 950 420]);
yyaxis left;
hold on; grid on; box on;
plot(t_sweep*1e3, sigma_vm_0/1e6,'b-o','LineWidth',1.8,'MarkerFaceColor','b');
plot(t_sweep*1e3, sigma_vm_1/1e6,'r-s','LineWidth',1.8,'MarkerFaceColor','r');
yline(sigma_yield/1e6,'k--','SA216 yield ~ 250 MPa','LineWidth',1.5);
ylabel('\sigma_{VM}  [MPa]','FontSize',11);
ax = gca; ax.YColor = 'k';
yyaxis right;
plot(t_sweep*1e3, FOS_0,'b--^','LineWidth',1.5,'MarkerFaceColor','b');
plot(t_sweep*1e3, FOS_1,'r--^','LineWidth',1.5,'MarkerFaceColor','r');
yline(3,'m--','FOS = 3','LineWidth',1.2);
ylabel('Factor of Safety','FontSize',11);
ax.YColor = 'k';
xlabel('Wall Thickness  t  [mm]','FontSize',11);
xline(30,'k:','t_{opt} = 30 mm','LineWidth',1.5);
legend({'\sigma_{VM} Mode 0','\sigma_{VM} Mode 1','Yield','FOS Mode 0','FOS Mode 1','FOS=3'},...
    'Location','northeast','FontSize',9);
title('Von Mises Stress and FOS vs Wall Thickness','FontSize',12,'FontWeight','bold');

% Figure 3: 36-sector polar hoop stress (Mode 0 uniform vs Mode 1 sinusoidal, t=60 mm)
figure('Name','36-Sector Polar','Color','w','Position',[200 220 580 550]);
polarplot([theta_rad; theta_rad(1)],[sigma_h_sectors_1; sigma_h_sectors_1(1)]/1e6,...
    'r-','LineWidth',2.5,'DisplayName','Mode 1 sinusoidal');
hold on;
polarplot([theta_rad; theta_rad(1)],[sigma_h_sectors_0; sigma_h_sectors_0(1)]/1e6,...
    'b--','LineWidth',1.5,'DisplayName','Mode 0 uniform');
legend('Location','south','FontSize',10);
title(sprintf('36-Sector Hoop Stress Distribution — t = 60 mm (as-designed)\nMode 1 peak: %.1f MPa  |  Mode 0: %.1f MPa',...
    max(sigma_h_sectors_1)/1e6, sigma_h_sectors_0(1)/1e6),'FontSize',11,'FontWeight','bold');

% Figure 4: Thermal capacitance vs wall thickness
figure('Name','Thermal Capacitance','Color','w','Position',[300 300 750 400]);
yyaxis left;
bar(t_sweep*1e3, mass_ring/1e3, 0.6,'FaceColor',[0.20 0.49 0.77],'EdgeColor','none');
ylabel('Ring Mass  [t]','FontSize',11);
yyaxis right;
plot(t_sweep*1e3, C_therm/1e6,'r-o','LineWidth',1.8,'MarkerFaceColor','r');
ylabel('Thermal Capacitance  C  [MJ/K]','FontSize',11);
xlabel('Wall Thickness  t  [mm]','FontSize',11);
xline(30,'k--','t_{opt} = 30 mm','LineWidth',1.5);
xline(60,'g--','As-designed = 60 mm','LineWidth',1.5);
title('Rotor Ring Mass and Thermal Capacitance vs Wall Thickness',...
    'FontSize',12,'FontWeight','bold');
grid on; box on;

fprintf('Script complete. 4 figures generated.\n');
