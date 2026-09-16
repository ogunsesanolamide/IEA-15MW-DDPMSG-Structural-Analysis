%% torque_shear.m
% Purpose: Report rated torque; optionally estimate nominal shear on a ring
% Units: SI

clear; clc;

%% Inputs
P_rated = 15e6;      % W, rated electrical power
rpm     = 7.56;      % rev/min
omega   = 2*pi*(rpm/60);  % rad/s

% Optional ring parameters for nominal shear estimate (very rough)
r_eff   = 5.0;       % m, effective radius of torque path
t       = 0.10;      % m, assumed thickness of torque-carrying ring (e.g., back-iron+web)
b       = 1.0;       % m, assumed axial width engaged in torque (choose to suit your geometry)

%% Calculations
T_rated = P_rated / omega;   % N·m

% OPTIONAL: nominal shear stress (tau = T / (A * r)) for a thin ring
A_ring  = t * b;             % m^2
tau_nom = T_rated / (A_ring * r_eff);   % Pa (very rough, for scoping only)

%% Display
fprintf('--- Torque & Nominal Shear ---\n');
fprintf('Power (MW):              %.3f\n', P_rated/1e6);
fprintf('Speed (rpm):             %.2f\n', rpm);
fprintf('Angular speed (rad/s):   %.3f\n', omega);
fprintf('Rated torque (MN·m):     %.3f\n', T_rated/1e6);
fprintf('\n(OPTIONAL rough shear estimate on a ring)\n');
fprintf('Radius r (m):            %.2f\n', r_eff);
fprintf('Thickness t (m):         %.3f\n', t);
fprintf('Width b (m):             %.3f\n', b);
fprintf('Nominal shear (MPa):     %.2f\n\n', tau_nom/1e6);

%% Optional: save CSV
outDir = fullfile(pwd, 'outputs'); 
if ~exist(outDir,'dir'), mkdir(outDir); end
T = table(P_rated, rpm, omega, T_rated, r_eff, t, b, tau_nom, ...
    'VariableNames', {'P_rated_W','rpm','omega_rad_s','T_rated_Nm','r_eff_m','t_m','b_m','tau_nom_Pa'});
writetable(T, fullfile(outDir, 'torque_shear.csv'));
disp('Saved: outputs/torque_shear.csv');