% Centrifugal Load
m_rotor = 120000;      % rotor mass in kg
r = 5;                 % effective radius in meters
rpm = 7.56;            % rated rotational speed
omega = 2*pi*(rpm/60); % angular speed in rad/s

F_c = m_rotor * r * omega^2;

disp(['Centrifugal load: ', num2str(F_c/1e6), ' MN']);
%% Save CSV (add this at the end of centrifugal_load.m)
outDir = fullfile(pwd, 'outputs');
if ~exist(outDir,'dir'), mkdir(outDir); end

T = table(F_c, 'VariableNames', {'F_c_N'});
writetable(T, fullfile(outDir, 'centrifugal_load.csv'));
disp('Saved: outputs/centrifugal_load.csv');