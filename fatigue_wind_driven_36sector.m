% =========================================================================
% fatigue_wind_driven_36sector.m
%
% Wind-speed-driven LPTN transient -> rotor back-iron T_rb(t) -> rainflow
% cycle counting (ASTM E1049-85) -> Basquin S-N / Palmgren-Miner fatigue.
%
% Wind input: REAL SCADA data — Penmanshiel Wind Farm, Turbine 15
% (Senvion MM82), 10-minute resolution, Jan-Jul 2021 (180.7 days).
% Source: Cubico Sustainable Investments Ltd. via Zenodo [12], validated
% and provided by Szatkowski & Jaen-Sola, Sustainability 2024, 16, 545.
% Wind speeds are used as-measured; the IEA 15 MW power curve is applied
% separately (the Senvion MM82 turbine curve is not used).
%
% Power curve: simplified cubic IEA 15 MW reference (cut-in 3 m/s,
% rated 10.59 m/s, cut-out 25 m/s). Loss scaling: Q_total(t) =
% Q_total_rated * lambda(t)^2 (simplified I2R-dominated scaling,
% preserving the rated 45/15/10/20/10% loss split).
%
% Fatigue: Basquin S-N (sigma_f=600 MPa, m=10), thermal stress
% sigma = alpha*E*DeltaT for Carbon Steel SA216 (alpha=1.15164e-5/K,
% E=200 GPa). Damage extrapolated to 20 years assuming stationarity
% of the measured wind climate.
%
% Author: O. Ogunsesan, Edinburgh Napier University, MRes 2025/26
% =========================================================================

clear; clc; close all;

%% ===== 1. LOAD PENMANSHIEL SCADA WIND SPEED DATA ========================
csv_path = ['/Users/office/Desktop/Lmd UK/MRES Journey/THESIS/FINAL/'...
    '15042026 THESIS UPDATE/Wind Data Raw + Edited/data files raw/'...
    'Turbine_Data_Penmanshiel_15_2021-01-01_-_2021-07-01_1056.csv'];

fid = fopen(csv_path, 'r');
V_raw = [];
while ~feof(fid)
    line = fgetl(fid);
    if ischar(line) && ~isempty(line) && line(1) ~= '#'
        parts = strsplit(line, ';');
        if length(parts) >= 2
            val = str2double(parts{2});
            V_raw(end+1) = val; %#ok<AGROW>
        end
    end
end
fclose(fid);

% Remove NaN rows (missing/erroneous data flagged by Greenbyte)
V_raw = V_raw(~isnan(V_raw))';
V = V_raw;

dt_wind  = 600;          % 10-minute resolution [s]
N_wind   = length(V);    % 26,016 steps = 180.7 days

fprintf('Penmanshiel SCADA: %d steps (%.1f days), mean=%.2f m/s, max=%.2f m/s\n',...
    N_wind, N_wind*dt_wind/86400, mean(V), max(V));

%% ===== 2. POWER CURVE -> LOAD FRACTION lambda(t) =======================
V_in    = 3.0;     % cut-in [m/s]
V_rated = 10.59;   % rated  [m/s]  (IEA 15 MW reference)
V_out   = 25.0;    % cut-out [m/s]

lambda = zeros(N_wind,1);
for i = 1:N_wind
    if V(i) < V_in || V(i) > V_out
        lambda(i) = 0;
    elseif V(i) <= V_rated
        lambda(i) = (V(i)/V_rated)^3;
    else
        lambda(i) = 1;
    end
end
lambda = min(max(lambda,0),1);

fprintf('Load fraction lambda: mean=%.3f, fraction at rated (lambda=1): %.1f%%\n',...
    mean(lambda), 100*mean(lambda>=0.999));

%% ===== 3. LOSS SPLIT (RATED, IEC 60034-2-1 PROPORTIONS) ================
eta = 0.965; P_rated = 15e6;
Q_total_rated = ((1-eta)/eta) * P_rated;   % ~544 kW
split = [0.45 0.15 0.10 0.20 0.10];        % cu, fe_t, fe_b, mag, mech

%% ===== 4. LPTN TRANSIENT WITH TIME-VARYING Q (FORWARD EULER) ===========
opts = thermal_defaults();
Tamb = 25;
dt   = 5;                          % integration step [s] (< 9.9 s stability limit)
steps_per_wind = dt_wind/dt;       % sub-steps per 10-min wind interval
N_total = N_wind * steps_per_wind;

T = Tamb*ones(8,1);
T_rb_hist = zeros(N_total,1);
t_hist    = (0:N_total-1)'*dt;

R_w_s=opts.R_w_s; R_st_sb=opts.R_st_sb; R_s_h=opts.R_s_h; R_h_amb=opts.R_h_amb;
R_st_ag=opts.R_st_ag; R_ag_pm=opts.R_ag_pm; R_pm_rb=opts.R_pm_rb;
R_rb_h=opts.R_rb_h; R_sh_amb=opts.R_sh_amb;
C_w=opts.C_w; C_st=opts.C_st; C_sb=opts.C_sb; C_h=opts.C_h;
C_ag=opts.C_ag; C_pm=opts.C_pm; C_rb=opts.C_rb; C_sh=opts.C_sh;

idx = 1;
for w = 1:N_wind
    Qtot = Q_total_rated * lambda(w)^2;
    Q_cu  = split(1)*Qtot;
    Q_fet = split(2)*Qtot;
    Q_feb = split(3)*Qtot;
    Q_pm  = split(4)*Qtot;
    Q_mech= split(5)*Qtot;

    for s = 1:steps_per_wind
        F12 = (T(1)-T(2))/R_w_s;
        F23 = (T(2)-T(3))/R_st_sb;
        F34 = (T(3)-T(4))/R_s_h;
        F4a = (T(4)-Tamb)/R_h_amb;
        F25 = (T(2)-T(5))/R_st_ag;
        F56 = (T(5)-T(6))/R_ag_pm;
        F67 = (T(6)-T(7))/R_pm_rb;
        F74 = (T(7)-T(4))/R_rb_h;
        F8a = (T(8)-Tamb)/R_sh_amb;

        dT1 = (Q_cu               - F12         ) / C_w;
        dT2 = (Q_fet + F12        - F23 - F25   ) / C_st;
        dT3 = (Q_feb + F23        - F34         ) / C_sb;
        dT4 = (        F34 + F74  - F4a         ) / C_h;
        dT5 = (        F25        - F56         ) / C_ag;
        dT6 = (Q_pm  + F56        - F67         ) / C_pm;
        dT7 = (        F67        - F74         ) / C_rb;
        dT8 = (Q_mech             - F8a         ) / C_sh;

        T = T + dt*[dT1;dT2;dT3;dT4;dT5;dT6;dT7;dT8];
        T_rb_hist(idx) = T(7);
        idx = idx + 1;
    end
end

fprintf('\nT_rb(t): min=%.2f C, max=%.2f C, mean=%.2f C\n',...
    min(T_rb_hist), max(T_rb_hist), mean(T_rb_hist));

%% ===== 5. RAINFLOW CYCLE COUNTING (ASTM E1049-85) ======================
tp = turning_points(T_rb_hist);
[ranges, counts] = simple_rainflow(tp);

fprintf('Turning points: %d | Rainflow cycles extracted: %.1f\n',...
    length(tp), sum(counts));

%% ===== 6. BASQUIN S-N / PALMGREN-MINER FATIGUE DAMAGE ==================
alpha_se = 1.15164e-5;   % CTE Carbon Steel SA216 [1/K]
E_ss     = 200e9;        % Young's modulus [Pa]
sigma_f  = 600e6;        % Basquin fatigue strength coeff [Pa]
m_basq   = 10;           % Basquin exponent

sigma_a = alpha_se * E_ss * ranges / 2;     % stress amplitude per cycle [Pa]
N_f     = (sigma_f ./ sigma_a) .^ m_basq;   % cycles to failure per amplitude
d       = counts ./ N_f;                    % damage per amplitude bin
D_sim   = sum(d);

T_sim_sec  = N_total*dt;
years_sim  = T_sim_sec/(365.25*86400);
D_20yr     = D_sim * (20/years_sim);

% Equivalent single-cycle-count summary at the dominant amplitude band
[~, i_max] = max(d);
days_actual = T_sim_sec/86400;
fprintf('\n=== FATIGUE RESULTS (Penmanshiel SCADA, %.1f-day window) ===\n', days_actual);
fprintf('Simulated period      : %.2f days (%.4f years)\n', days_actual, years_sim);
fprintf('Total rainflow cycles : %.1f (in %.2f days)\n', sum(counts), days_actual);
fprintf('Dominant cycle range  : DeltaT = %.1f K (sigma_a = %.1f MPa), count = %.1f\n',...
    ranges(i_max), sigma_a(i_max)/1e6, counts(i_max));
fprintf('D_sim (%.2f days)     : %.4e\n', days_actual, D_sim);
fprintf('Extrapolated D_20yr   : %.4e\n', D_20yr);
fprintf('Cycles/year (extrapolated) : %.0f\n', sum(counts)/years_sim);
fprintf('Cycles in 20 years (extrapolated) : %.0f\n', sum(counts)/years_sim*20);

%% ===== 7. CYCLE HISTOGRAM TABLE (for Table 3B.6 update) ================
edges = 0:5:120;
nbins = length(edges)-1;
bincounts = zeros(1,nbins);
for b = 1:nbins
    in_bin = ranges >= edges(b) & ranges < edges(b+1);
    bincounts(b) = sum(counts(in_bin));
end
fprintf('\nCycle amplitude histogram (DeltaT bins, counts per %.1f days):\n', days_actual);
for b = 1:nbins
    if bincounts(b) > 0
        fprintf('  %3d-%3d K : %6.2f cycles\n', edges(b), edges(b+1), bincounts(b));
    end
end

%% ===== 8. FIGURE: T_rb(t) AND WIND SPEED =================================
figure('Name','Wind-Driven T_rb(t)','Color','w','Position',[80 80 1000 600],'Visible','off');

subplot(3,1,1);
plot((0:N_wind-1)*dt_wind/3600, V, 'b-','LineWidth',1.2);
ylabel('Wind speed [m/s]'); grid on;
title(sprintf('Penmanshiel SCADA Wind Speed — Turbine 15, %.0f-day window (Jan–Jul 2021)', days_actual));

subplot(3,1,2);
plot((0:N_wind-1)*dt_wind/3600, lambda, 'g-','LineWidth',1.2);
ylabel('Load fraction \lambda'); grid on;

subplot(3,1,3);
plot(t_hist/3600, T_rb_hist, 'r-','LineWidth',1.2);
xlabel('Time [hours]'); ylabel('T_{rb} [^\circ C]'); grid on;
title(sprintf('Rotor Back-Iron Temperature T_{rb}(t) — range %.1f to %.1f^\\circ C',...
    min(T_rb_hist), max(T_rb_hist)));

print(gcf, 'fatigue_wind_driven_Trb.png', '-dpng', '-r150');

%% ===== 9. TABLE 3B.6 DATA: 20-YEAR EXTRAPOLATED CYCLE SPECTRUM =========
scale_20yr = 20/years_sim;
fprintf('\n=== TABLE 3B.6 DATA (20-year extrapolation, scale x%.1f) ===\n', scale_20yr);
fprintf('%9s %14s %12s %14s %12s\n','DeltaT bin','n_20yr [cyc]','sigma_a[MPa]','N_f [cyc]','d_i (D contrib)');
D_check = 0;
for b = 1:nbins
    if bincounts(b) > 0
        dT_mid = (edges(b)+edges(b+1))/2;
        n_20yr = bincounts(b)*scale_20yr;
        sa = alpha_se*E_ss*dT_mid/2;
        Nf = (sigma_f/sa)^m_basq;
        di = n_20yr/Nf;
        D_check = D_check + di;
        fprintf('%4d-%4d K %14.0f %12.2f %14.3e %12.3e\n', edges(b), edges(b+1), n_20yr, sa/1e6, Nf, di);
    end
end
fprintf('Sum of d_i (cross-check vs D_20yr=%.4e): %.4e\n', D_20yr, D_check);
fprintf('Total cycles/20yr (extrapolated): %.0f\n', sum(bincounts)*scale_20yr);

fprintf('\nScript complete.\n');


%% ========================================================================
%% LOCAL FUNCTIONS
%% ========================================================================
function tp = turning_points(x)
% Extract turning points (local extrema) from a time series, retaining
% endpoints, per ASTM E1049-85 preprocessing.
    d = diff(x);
    idx = 1;
    last_sign = 0;
    for i = 1:length(d)
        if d(i) ~= 0
            s = sign(d(i));
            if last_sign ~= 0 && s ~= last_sign
                idx(end+1) = i; %#ok<AGROW>
            end
            last_sign = s;
        end
    end
    idx(end+1) = length(x);
    tp = x(idx);
end

function [ranges, counts] = simple_rainflow(tp)
% Standard 4-point rainflow cycle counting algorithm (Downing & Socie,
% 1982 / ASTM E1049-85 range-pair method). Returns cycle ranges and their
% counts (1.0 for full cycles, 0.5 for residual half-cycles).
    n = length(tp);
    stack = zeros(n,1);
    si = 0;
    ranges = [];
    counts = [];
    for i = 1:n
        si = si + 1;
        stack(si) = tp(i);
        while si >= 3
            Y = abs(stack(si)   - stack(si-1));
            X = abs(stack(si-1) - stack(si-2));
            if X < Y
                break;
            end
            if si == 3
                ranges(end+1) = X; %#ok<AGROW>
                counts(end+1) = 0.5; %#ok<AGROW>
                stack(1) = stack(2);
                stack(2) = stack(3);
                si = 2;
            else
                ranges(end+1) = X; %#ok<AGROW>
                counts(end+1) = 1.0; %#ok<AGROW>
                stack(si-2) = stack(si);
                si = si - 2;
            end
        end
    end
    for j = 1:si-1
        ranges(end+1) = abs(stack(j+1)-stack(j)); %#ok<AGROW>
        counts(end+1) = 0.5; %#ok<AGROW>
    end
end
