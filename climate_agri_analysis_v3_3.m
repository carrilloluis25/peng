
%% MATLAB Climate–Agriculture Correlation & Trends (v3.3)
% File: climate_agri_analysis_v3_3.m
% Fixes vs v3.2:
%   - Heatmap axis labels replaced with clean, human-friendly labels:
%       {'Average Temperature (°C)', 'Precipitation (mm)', 'Crop Yield (tons/ha)', 'Extreme Weather Events'}
%   - Keeps all prior robustness improvements (regression table, partial corr, outputs next to CSV)
%
% -------------------------------------------------------------------------

%% ------------------------ USER SETTINGS ---------------------------------
filePath = 'C:\Users\Peter\Desktop\ENG220\All\climate_change_impact_on_agriculture_2024.csv';   % <- update to your CSV absolute/relative path
cleanOutliers = false;
useLaTeXLabels = false;   % set true only if you want LaTeX-rendered labels

% -------------------------------------------------------------------------
%% Resolve filePath (allow relative, prefer absolute checks)
altPath  = fullfile('..','climate_change_impact_on_agriculture_2024.csv'); % fallback for nearby location
if ~isfile(filePath)
    if isfile(altPath)
        filePath = altPath;
    else
        mntPath = fullfile(filesep,'mnt','data','climate_change_impact_on_agriculture_2024.csv');
        if isfile(mntPath)
            filePath = mntPath;
        else
            error('CSV not found. Update "filePath" at the top of the script.');
        end
    end
end

%% Create output folders next to the CSV
csvDir = fileparts(filePath);
if strlength(csvDir)==0
    csvDir = pwd;
end
baseOut = fullfile(csvDir, 'climate_analysis_outputs');
outDir  = fullfile(baseOut,'tables');
figDir  = fullfile(baseOut,'figures');

[ok,msg] = mkdir(outDir);  if ~ok, error("Couldn't create outDir (%s): %s", outDir, msg); end
[ok,msg] = mkdir(figDir);  if ~ok, error("Couldn't create figDir (%s): %s", figDir, msg); end
fprintf('Writing tables to:   %s\n', outDir);
fprintf('Writing figures to:  %s\n', figDir);

%% Read CSV (preserve headers)
T = readtable(filePath, 'TextType','string', 'VariableNamingRule','preserve');

%% --------- Robust column detection (case/format tolerant) ---------------
allNames = string(T.Properties.VariableNames);

colMap.Region = resolveName(allNames, ["Region","Geographic Region","Simulated geographic region","Area"]);
colMap.Year   = resolveName(allNames, ["Year","Model Year","Modeled year of data collection"]);
colMap.Temp   = resolveName(allNames, ["Average_Temperature","Average Temperature","Temperature (C)","Avg Temp","Temperature","Average Temperature (°C)"]);
colMap.Precip = resolveName(allNames, ["Precipitation","Annual Rainfall","Rainfall (mm)","Rain","Precip"]);
colMap.Yield  = resolveName(allNames, ["Crop_Yield","Crop Yield","Yield (tons/hectare)","Yield","Yield_tha","Yield_ton_ha"]);
colMap.Events = resolveName(allNames, ["Extreme_Weather_Events","Extreme Weather Events","Extreme Events","Extreme Weather","Events"]);

% Validate that everything was resolved
reqKeys = fieldnames(colMap);
for i = 1:numel(reqKeys)
    if strlength(colMap.(reqKeys{i})) == 0
        errMsg = compose("Could not resolve column for '%s'. Available columns are:\n  - %s", ...
                         reqKeys{i}, strjoin(allNames, "\n  - "));
        error(errMsg);
    end
end

% Normalize types
T.Region = categorical(T.(colMap.Region));

% Year => numeric year if needed
if ~isnumeric(T.(colMap.Year))
    try
        T.(colMap.Year) = year(datetime(T.(colMap.Year)));
    catch
        T.(colMap.Year) = double(string(T.(colMap.Year)));
    end
end

% Ensure numeric for metrics
numVars = [colMap.Temp, colMap.Precip, colMap.Yield, colMap.Events];
for i = 1:numel(numVars)
    if ~isnumeric(T.(numVars{i}))
        T.(numVars{i}) = double(T.(numVars{i}));
    end
end

% Sort, clean
T = sortrows(T, colMap.Year);
T = rmmissing(T, 'DataVariables', numVars);
if cleanOutliers
    mask = false(height(T),1);
    for i = 1:numel(numVars), mask = mask | isoutlier(T.(numVars{i})); end
    T(mask,:) = [];
end

%% ------------------------- Summaries & Correlations ---------------------
% Overall summary
overallSummary = table();
for i = 1:numel(numVars)
    v = T.(numVars{i});
    s = [mean(v); std(v); min(v); median(v); max(v)];
    overallSummary.(matlab.lang.makeValidName(numVars{i})) = s;
end
overallSummary = addvars(overallSummary, {'mean','std','min','median','max'}', 'Before',1, 'NewVariableNames','Stat');
writetable(overallSummary, fullfile(outDir,'overall_summary.csv'));

% Per-region summary
S = groupsummary(T, 'Region', {'mean','std','min','median','max'}, numVars);
S.Properties.VariableNames = matlab.lang.makeValidName(S.Properties.VariableNames);
writetable(S, fullfile(outDir,'per_region_summary.csv'));

% Correlations
X = T{:, numVars};
R_pearson  = corr(X, 'Rows','pairwise', 'Type','Pearson');
R_spearman = corr(X, 'Rows','pairwise', 'Type','Spearman');

%% ------------------------------- PLOTS ----------------------------------
close all
% Human-friendly names for axis display (order matches numVars)
labelsHeat = {'Average Temperature (°C)', 'Precipitation (mm)', 'Crop Yield (tons/ha)', 'Extreme Weather Events'};

% Axis labels for other plots
if useLaTeXLabels
    yLabel = 'Crop Yield (tons/ha)';
    xLabelTemp = 'Average Temperature ($^\circ$C)';
    xLabelPrec = 'Precipitation (mm)';
    xLabelEvent= 'Extreme Weather Events (count)';
    labelInterpreter = 'latex';
else
    yLabel = 'Crop Yield (tons/ha)';
    xLabelTemp = 'Average Temperature (°C)';
    xLabelPrec = 'Precipitation (mm)';
    xLabelEvent= 'Extreme Weather Events (count)';
    labelInterpreter = 'none';
end

% Heatmaps with fixed axis display labels
tl = tiledlayout(1,2, 'TileSpacing','compact','Padding','compact');

nexttile
h1 = heatmap(labelsHeat, labelsHeat, R_pearson, 'Colormap',parula, 'ColorLimits',[-1 1]);
title('Pearson Correlation'); h1.CellLabelFormat = '%.2f';
try, xlabel(h1,'Variables'); ylabel(h1,'Variables'); end

nexttile
h2 = heatmap(labelsHeat, labelsHeat, R_spearman, 'Colormap',parula, 'ColorLimits',[-1 1]);
title('Spearman Correlation'); h2.CellLabelFormat = '%.2f';
try, xlabel(h2,'Variables'); ylabel(h2,'Variables'); end

set(gcf,'Position',[100 100 1200 470])
exportgraphics(gcf, fullfile(figDir,'corr_heatmaps.png'), 'Resolution', 200);

% Pairwise scatter matrix
varNamesNice = labelsHeat; % reuse pretty labels for legends
try
    figure('Position',[100 100 900 900])
    [h,ax,bigax] = gplotmatrix(X, [], T.Region, [], [], [], 'grpbars', 'variable', varNamesNice, varNamesNice);
    title(bigax, 'Pairwise Scatter by Region')
    exportgraphics(gcf, fullfile(figDir,'pairwise_scatter_by_region.png'), 'Resolution', 200);
catch
    figure('Position',[100 100 900 900])
    plotmatrix(X); set(gca,'XTick',[],'YTick',[])
    sgtitle('Pairwise Scatter (ungrouped)')
    exportgraphics(gcf, fullfile(figDir,'pairwise_scatter.png'), 'Resolution', 200);
end

% 1) Yield vs Temperature
scatter_with_fit(T, colMap.Temp, colMap.Yield, 'Region', fullfile(figDir,'yield_vs_temperature.png'), xLabelTemp, yLabel, labelInterpreter);
% 2) Yield vs Precipitation
scatter_with_fit(T, colMap.Precip, colMap.Yield, 'Region', fullfile(figDir,'yield_vs_precipitation.png'), xLabelPrec, yLabel, labelInterpreter);
% 3) Yield vs Extreme Weather Events
scatter_with_fit(T, colMap.Events, colMap.Yield, 'Region', fullfile(figDir,'yield_vs_extreme_events.png'), xLabelEvent, yLabel, labelInterpreter);

% 4) 3D view: Temp–Precip–Yield with bubble size ~ Events
figure('Position',[100 100 900 700]); hold on; grid on; box on
cats = categories(T.Region); cmap = lines(max(3,numel(cats)));
for i = 1:numel(cats)
    idx = T.Region == cats{i};
    sz = 8 + 2*normalize(T.(colMap.Events)(idx),'range',[0 20]);
    scatter3(T.(colMap.Temp)(idx), T.(colMap.Precip)(idx), T.(colMap.Yield)(idx), sz, 'MarkerEdgeColor',cmap(i,:), 'MarkerFaceColor','none', 'DisplayName', char(cats{i}));
end
xlabel(xLabelTemp, 'Interpreter',labelInterpreter); ylabel(xLabelPrec, 'Interpreter',labelInterpreter); zlabel(yLabel, 'Interpreter',labelInterpreter);
title('3D: Yield vs Temp & Precip (bubble ~ Extreme Events)'); legend('Location','bestoutside'); view(-25,18);
exportgraphics(gcf, fullfile(figDir,'3d_yield_temp_precip_events.png'), 'Resolution', 200);

% 5) Time trends by region
figure('Position',[80 80 1100 900]); tlo = tiledlayout(2,2, 'TileSpacing','compact','Padding','compact');
nexttile; hold on; grid on; box on
for i = 1:numel(cats), idx = T.Region == cats{i}; plot(T.(colMap.Year)(idx), T.(colMap.Temp)(idx), '-', 'DisplayName', char(cats{i})); end
xlabel('Year'); ylabel(xLabelTemp, 'Interpreter',labelInterpreter); title('Temperature over Time'); legend('Location','bestoutside');
nexttile; hold on; grid on; box on
for i = 1:numel(cats), idx = T.Region == cats{i}; plot(T.(colMap.Year)(idx), T.(colMap.Precip)(idx), '-', 'DisplayName', char(cats{i})); end
xlabel('Year'); ylabel(xLabelPrec, 'Interpreter',labelInterpreter); title('Precipitation over Time');
nexttile; hold on; grid on; box on
for i = 1:numel(cats), idx = T.Region == cats{i}; plot(T.(colMap.Year)(idx), T.(colMap.Events)(idx), '-', 'DisplayName', char(cats{i})); end
xlabel('Year'); ylabel(xLabelEvent, 'Interpreter',labelInterpreter); title('Extreme Events over Time');
nexttile; hold on; grid on; box on
for i = 1:numel(cats), idx = T.Region == cats{i}; plot(T.(colMap.Year)(idx), T.(colMap.Yield)(idx), '-', 'DisplayName', char(cats{i})); end
xlabel('Year'); ylabel(yLabel, 'Interpreter',labelInterpreter); title('Crop Yield over Time');
sgtitle('Climate & Yield Time Series by Region'); exportgraphics(gcf, fullfile(figDir,'time_trends_by_region.png'), 'Resolution', 200);

%% 6) Multiple regression: Yield ~ Temp + Precip + Events (+ Region fixed effects)
coefTablePath = fullfile(outDir,'regression_coefficients.csv');
try
    TsMdl = table(T.(colMap.Yield), T.(colMap.Temp), T.(colMap.Precip), T.(colMap.Events), T.Region, ...
                  'VariableNames', {'Y','Temp','Precip','Events','Region'});
    TsMdl.Temp   = zscore(TsMdl.Temp);
    TsMdl.Precip = zscore(TsMdl.Precip);
    TsMdl.Events = zscore(TsMdl.Events);
    TsMdl.Y      = zscore(TsMdl.Y);

    mdl = fitlm(TsMdl, 'Y ~ Temp + Precip + Events + Region');
    coefTbl = mdl.Coefficients; writetable(coefTbl, coefTablePath);

    have = ismember(coefTbl.Properties.RowNames, {'Temp','Precip','Events'});
    betaNames = coefTbl.Properties.RowNames(have);
    betaVals  = coefTbl.Estimate(have);
    figure('Position',[120 120 700 520]); bar(categorical(betaNames), betaVals)
    grid on; box on; ylabel('Standardized Coefficient (beta)'); title('Relative Importance for Yield (Std. Predictors)');
    exportgraphics(gcf, fullfile(figDir, 'regression_standardized_betas.png'), 'Resolution', 200);
catch ME
    warning('fitlm() failed (%s). Falling back to regress() without Region fixed effects.', ME.message);
    y = zscore(T.(colMap.Yield));
    Xr = [zscore(T.(colMap.Temp)), zscore(T.(colMap.Precip)), zscore(T.(colMap.Events))];
    good = all(isfinite([y, Xr]),2);
    y = y(good); Xr = Xr(good,:);
    Xr = [ones(size(Xr,1),1) Xr]; b = regress(y, Xr);
    coefTbl = array2table(b', 'VariableNames', {'Intercept','Temp','Precip','Events'}); writetable(coefTbl, coefTablePath);
    figure('Position',[120 120 700 520]); bar(categorical({'Temp','Precip','Events'}), b(2:4))
    grid on; box on; ylabel('Standardized Coefficient (beta)'); title('Relative Importance for Yield (Std. Predictors, no fixed effects)');
    exportgraphics(gcf, fullfile(figDir, 'regression_standardized_betas.png'), 'Resolution', 200);
end

%% 7) Partial correlations with Yield
labels = string([colMap.Temp, colMap.Precip, colMap.Events]);  % string array
pcVals = NaN(1, numel(labels));
for i = 1:numel(labels)
    pred = labels(i);
    others = setdiff(labels, pred, 'stable');
    try
        Xcontrol = [T.(char(others(1))), T.(char(others(2)))];
        pcVals(i) = partialcorr(T.(char(pred)), T.(char(colMap.Yield)), Xcontrol, 'Rows','pairwise');
    catch
        pcVals(i) = NaN;
    end
end
pcTbl = table(cellstr(labels)', pcVals', 'VariableNames', {'Predictor','PartialCorrWithYield'});
writetable(pcTbl, fullfile(outDir, 'partial_correlations_with_yield.csv'));

figure('Position',[140 140 700 520]); bar(categorical(cellstr(labels)), pcVals); grid on; box on
ylabel('Partial Corr. with Yield'); title('How each driver relates to Yield controlling for the others');
exportgraphics(gcf, fullfile(figDir,'partial_corr_with_yield.png'), 'Resolution', 200);

disp('All done.');

%% ---------------------- LOCAL FUNCTIONS (at end) ------------------------
function out = resolveName(allNames, candidates)
    out = "";
    candidates = string(candidates);
    canonAll = canonicalize(allNames);
    % exact canonical
    for c = candidates(:)'
        canonC = canonicalize(c);
        hit = (canonAll == canonC);
        if any(hit), out = allNames(find(hit,1)); return; end
    end
    % contains
    for c = candidates(:)'
        canonC = canonicalize(c);
        hit = contains(canonAll, canonC) | contains(canonC, canonAll);
        if any(hit)
            matches = allNames(hit);
            [~,ix] = min(strlength(matches));
            out = matches(ix); return;
        end
    end
end

function s = canonicalize(s)
    s = regexprep(lower(string(s)), '[^a-z0-9]', '');
end

function scatter_with_fit(T, xName, yName, colorByCat, figPath, xLabel, yLabel, labelInterpreter)
    figure('Position',[80 80 880 700]); hold on; grid on; box on
    if ~iscategorical(T.(colorByCat)), T.(colorByCat) = categorical(T.(colorByCat)); end
    cats = categories(T.(colorByCat)); cmap = lines(max(3,numel(cats)));
    for i = 1:numel(cats)
        idx = T.(colorByCat) == cats{i};
        scatter(T.(xName)(idx), T.(yName)(idx), 36, 'MarkerEdgeColor', cmap(i,:), 'MarkerFaceColor','none', 'DisplayName', char(cats{i}));
    end
    x = T.(xName); y = T.(yName); good = isfinite(x) & isfinite(y); x = x(good); y = y(good);
    if numel(x) > 1
        p = polyfit(x, y, 1); xx = linspace(min(x), max(x), 200); yy = polyval(p, xx);
        plot(xx, yy, '-', 'LineWidth', 2, 'DisplayName', sprintf('Fit: y = %.3g x + %.3g', p(1), p(2)));
        yhat = polyval(p, x); SSres = sum((y - yhat).^2); SStot = sum((y - mean(y)).^2); Rsq = 1 - SSres/SStot;
        txt = sprintf('Slope = %.3g\nR^2 = %.3f', p(1), Rsq);
        xPos = min(x) + 0.05*(max(x)-min(x)); yPos = max(y) - 0.1*(max(y)-min(y));
        text(xPos, yPos, txt, 'FontSize', 11, 'BackgroundColor',[1 1 1 0.6],'EdgeColor',[0.7 0.7 0.7]);
    end
    xlabel(xLabel, 'Interpreter',labelInterpreter); ylabel(yLabel, 'Interpreter',labelInterpreter);
    legend('Location','bestoutside'); title(sprintf('%s vs %s (colored by %s)', strrep(yName,'_','\_'), strrep(xName,'_','\_'), colorByCat));
    exportgraphics(gcf, figPath, 'Resolution', 200);
end
