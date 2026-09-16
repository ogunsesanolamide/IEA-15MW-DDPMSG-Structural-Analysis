%% combine_loads.m
% Purpose: Collect outputs from individual load scripts into one summary (robust version)

clear; clc;

outDir = fullfile(pwd,'outputs');
if ~exist(outDir,'dir')
    error('The folder "%s" does not exist. Run the individual load scripts first.', outDir);
end

% Helper to read a file with clear error if missing
readOrError = @(fname) ( ...
    exist(fullfile(outDir,fname),'file') == 2 ...
    || error('Missing file: %s. Please run the corresponding script first.', fullfile(outDir,fname)) );

% Ensure each required CSV exists
readOrError('gravity_load.csv');        % from gravity_load.m  -> column: F_g_N
readOrError('centrifugal_load.csv');    % from centrifugal_load.m -> column: F_c_N
readOrError('torque_shear.csv');        % from torque_shear.m -> column: T_rated_Nm
readOrError('em_pressure.csv');         % from em_pressure.m -> column: p_em_Pa

% Read the tables
G  = readtable(fullfile(outDir,'gravity_load.csv'));
C  = readtable(fullfile(outDir,'centrifugal_load.csv'));
TQ = readtable(fullfile(outDir,'torque_shear.csv'));
EM = readtable(fullfile(outDir,'em_pressure.csv'));

% Defensive checks for expected variable names
assert(any(strcmpi(G.Properties.VariableNames,'F_g_N')),       'gravity_load.csv must contain F_g_N');
assert(any(strcmpi(C.Properties.VariableNames,'F_c_N')),       'centrifugal_load.csv must contain F_c_N');
assert(any(strcmpi(TQ.Properties.VariableNames,'T_rated_Nm')), 'torque_shear.csv must contain T_rated_Nm');
assert(any(strcmpi(EM.Properties.VariableNames,'p_em_Pa')),    'em_pressure.csv must contain p_em_Pa');

% Build the summary
Gravity_MN       = G.F_g_N(1)/1e6;
Centrifugal_MN   = C.F_c_N(1)/1e6;
Torque_MN_m      = TQ.T_rated_Nm(1)/1e6;
EM_Pressure_MPa  = EM.p_em_Pa(1)/1e6;

Summary = table(Gravity_MN, Centrifugal_MN, Torque_MN_m, EM_Pressure_MPa);

% Display & save
disp('--- Structural Load Summary ---');
disp(Summary);

writetable(Summary, fullfile(outDir,'structural_loads_summary.csv'));
disp('Saved: outputs/structural_loads_summary.csv');

%% ─── Thermal expansion summary (if available) ───────────────────────
thExpFile = fullfile(outDir, 'thermal_expansion.csv');
gapFile   = fullfile(outDir, 'airgap_closure.csv');

if exist(thExpFile,'file') == 2
    fprintf('\n--- Thermal Expansion Summary ---\n');
    TE = readtable(thExpFile);
    disp(TE(:, {'Component','Material','Temp_C','DeltaT_K','DeltaR_mm','Stress_MPa'}));
end

if exist(gapFile,'file') == 2
    fprintf('--- Air-Gap Closure ---\n');
    AG = readtable(gapFile);
    disp(AG);
end
