function [threshold, details] = Findthresholdbackground(inputData, method, varargin)
%Findthresholdbackground Estimate a background threshold for SENPAI inputs.
%
%   threshold = Findthresholdbackground(inputData)
%   threshold = Findthresholdbackground(inputData, method)
%   [threshold, details] = Findthresholdbackground(...)
%
%   inputData can be a numeric 2-D/3-D image, a TIFF/MAT file path, or a
%   file name plus a folder path. Supported methods are:
%   Otsu, Mean, Median, Mean + 2 STD, Percentile 90, Percentile 95,
%   Percentile 98.

if nargin < 2 || isempty(method)
    method = 'Otsu';
end

folderPath = '';
if isText(inputData) && isText(method) && isfolder(char(method))
    folderPath = char(method);
    if ~isempty(varargin)
        method = varargin{1};
    else
        method = 'Otsu';
    end
end

volume = loadInputVolume(inputData,folderPath);
if ndims(volume) == 4 && size(volume,4) == 3
    volume = mean(double(volume),4);
end

values = double(volume(:));
values = values(isfinite(values));
if isempty(values)
    error('SENPAI:ThresholdInput','Input volume does not contain finite values.');
end

minValue = min(values);
maxValue = max(values);
methodText = char(string(method));
methodKey = regexprep(lower(methodText),'[^a-z0-9]','');

switch methodKey
    case 'otsu'
        if maxValue <= minValue
            threshold = minValue;
        else
            scaledValues = (values-minValue)./(maxValue-minValue);
            threshold = graythresh(scaledValues).*(maxValue-minValue) + minValue;
        end
    case 'mean'
        threshold = mean(values);
    case 'median'
        threshold = median(values);
    case {'mean2std','meanplus2std'}
        threshold = mean(values) + 2.*std(values);
    case {'percentile90','p90'}
        threshold = percentileValue(values,90);
    case {'percentile95','p95'}
        threshold = percentileValue(values,95);
    case {'percentile98','p98'}
        threshold = percentileValue(values,98);
    otherwise
        error('SENPAI:ThresholdMethod','Unsupported threshold method: %s.',methodText);
end

threshold = double(threshold);
threshold = min(max(threshold,minValue),maxValue);

binCount = 256;
binCenters = linspace(minValue,maxValue,binCount);
if maxValue > minValue
    step = binCenters(2)-binCenters(1);
    edges = [binCenters-step/2, maxValue+step/2];
    histogramValues = histcounts(values,edges,'Normalization','probability');
else
    histogramValues = zeros(1,binCount);
    histogramValues(1) = 1;
end

details = struct();
details.Method = methodText;
details.Threshold = threshold;
details.MinValue = minValue;
details.MaxValue = maxValue;
details.BinCenters = binCenters;
details.Histogram = histogramValues;
details.ForegroundFraction = mean(values > threshold);
details.BackgroundFraction = mean(values <= threshold);
end

function tf = isText(value)
tf = ischar(value) || (isstring(value) && isscalar(value));
end

function volume = loadInputVolume(inputData,folderPath)
if isnumeric(inputData) || islogical(inputData)
    volume = inputData;
    return
end

if ~isText(inputData)
    error('SENPAI:ThresholdInput','Input must be a numeric volume or a file path.');
end

filePath = char(inputData);
if ~isempty(folderPath)
    filePath = fullfile(folderPath,filePath);
end
if ~isfile(filePath)
    error('SENPAI:ThresholdInput','Input file not found: %s.',filePath);
end

[~,~,ext] = fileparts(filePath);
switch lower(ext)
    case {'.tif','.tiff'}
        volume = readTiffVolume(filePath);
    case '.mat'
        volume = readMatVolume(filePath);
    otherwise
        error('SENPAI:ThresholdInput','Unsupported input file type: %s.',ext);
end
end

function volume = readTiffVolume(filePath)
info = imfinfo(filePath);
if isempty(info)
    error('SENPAI:ThresholdInput','TIFF file is empty: %s.',filePath);
end

if info(1).BitDepth <= 8
    volume = zeros(info(1).Height,info(1).Width,numel(info),'uint8');
else
    volume = zeros(info(1).Height,info(1).Width,numel(info),'uint16');
end
for zz = 1:numel(info)
    volume(:,:,zz) = imread(filePath,zz);
end
end

function volume = readMatVolume(filePath)
vars = whos('-file',filePath);
isVolume = arrayfun(@(v) numel(v.size) == 3 && any(strcmp(v.class, ...
    {'logical','uint8','uint16','uint32','int16','int32','single','double'})),vars);
candidates = find(isVolume);
if isempty(candidates)
    error('SENPAI:ThresholdInput','No numeric 3-D volume found in MAT file.');
end

data = load(filePath,vars(candidates(1)).name);
volume = data.(vars(candidates(1)).name);
end

function value = percentileValue(values,percentile)
values = sort(values(:));
idx = max(1,min(numel(values),round(1 + (numel(values)-1).*percentile./100)));
value = values(idx);
end
