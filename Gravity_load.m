% Gravitational Load
m = 210000;      % mass of generator in kg
g = 9.81;        % gravitational acceleration (m/s^2)
F_g = m * g;     % gravitational force in Newtons

disp(['Gravitational load: ', num2str(F_g/1e6), ' MN']);
%% (Add this to the end of gravity_load.m)
outDir = fullfile(pwd, 'outputs');
if ~exist(outDir,'dir'), mkdir(outDir); end

T = table(F_g, 'VariableNames', {'F_g_N'});
writetable(T, fullfile(outDir, 'gravity_load.csv'));

disp('Saved: outputs/gravity_load.csv');