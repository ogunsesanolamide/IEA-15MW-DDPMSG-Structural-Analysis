%% em_pressure.m
% Purpose: Compute electromagnetic radial pressure (Maxwell stress) in air-gap

clear; clc;

%% Inputs
B   = 1.0;           % Tesla, representative peak air-gap flux density
mu0 = 4*pi*1e-7;     % H/m, permeability of free space

%% Calculation
p_em = (B^2)/(2*mu0);   % Pa = N/m^2

%% Display results
fprintf('--- Electromagnetic Radial Pressure ---\n');
fprintf('B (T):                 %.3f\n', B);
fprintf('p_em (Pa):             %.0f\n', p_em);
fprintf('p_em (kPa):            %.1f\n', p_em/1e3);
fprintf('p_em (MPa):            %.3f\n\n', p_em/1e6);

%% Optional: save CSV
outDir = fullfile(pwd, 'outputs'); 
if ~exist(outDir,'dir'), mkdir(outDir); end
T = table(B, mu0, p_em, 'VariableNames', {'B_T','mu0_H_per_m','p_em_Pa'});
writetable(T, fullfile(outDir, 'em_pressure.csv'));
disp('Saved: outputs/em_pressure.csv');