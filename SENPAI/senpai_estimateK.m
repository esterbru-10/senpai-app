function Kopt = senpai_estimateK(path_in, im_in, path_out, crop_idxs, varargin)
% senpai_estimateK:
%     produces an estimate for the optimal K parameter for the
%     senpai_seg_core.m function. The estimation is performed by running
%     the segmentation multiple times with different K,
%     until one K satisfies the criteria in the manuscript.
%     When no K in [2 10] satisfies the criteria, 
%     Kopt=10 is provided and a warning is displayed.
%
%     Execute the function in the command window:
%     Syntax:
%
%       senpai_estimateK(path_in, im_in, path_out):
%
%       inputs
%
%       path_in: path for the input file
%
%       im_in: filename for the input file
%
%       path_out: output path for the segmentation tests
%
%       crop_idxs: start and end indexes for a representative crop on which
%           to run the estimation, e.g., [10 200 30 220 1 50] to run the
%           estimation on a crop starting at x=10, y=30 and z=1 and ending 
%           with x=200, y=220 and z=50.

startK = 2;  % minimum K
stopK = 10;  % maximum K

oldFolder = pwd;
cleanupFolder = onCleanup(@() cd(oldFolder));
progressFcn = [];
cancelFcn = [];
if numel(varargin) >= 1
    progressFcn = varargin{1};
end
if numel(varargin) >= 2
    cancelFcn = varargin{2};
end
if nargin < 3
    path_out = oldFolder;
end
if isstring(path_in)
    path_in = char(path_in);
end
if isstring(im_in)
    im_in = char(im_in);
end
if isstring(path_out)
    path_out = char(path_out);
end
inputFile = fullfile(path_in,im_in);
if isempty(regexp(inputFile,'^(/|[A-Za-z]:[\\/])','once'))
    inputFile = fullfile(oldFolder,inputFile);
end
info1 = imfinfo(inputFile);
Nz=numel(info1);
Ny=info1(1).Width;
Nx=info1(1).Height;
bitl=info1(1).BitDepth;
if bitl==16
    tp='single';
elseif bitl==8
    tp='uint8';
else
    error('input image must be 8 or 16 bit')
end

if ~isempty(progressFcn)
    progressFcn(0.02,'Preparing Estimate K crop');
end
if ~isempty(cancelFcn) && cancelFcn()
    error('SENPAI:Cancelled','Operation cancelled by the user.')
end

if nargin < 4 || isempty(crop_idxs)
    crop_idxs = [1 Nx 1 Ny 1 Nz];
end
if isempty(path_out)
    path_out = oldFolder;
elseif isempty(regexp(path_out,'^(/|[A-Za-z]:[\\/])','once'))
    path_out = fullfile(oldFolder,path_out);
end
if ~isfolder(path_out)
    mkdir(path_out);
end
crop_idxs = round(crop_idxs(:).');
if numel(crop_idxs) ~= 6 || any(~isfinite(crop_idxs))
    error('crop_idxs must contain six finite numeric values.')
end

limits = [Nx Ny Nz];
starts = [crop_idxs(1) crop_idxs(3) crop_idxs(5)];
stops = [crop_idxs(2) crop_idxs(4) crop_idxs(6)];
for dim = 1:3
    if starts(dim) > stops(dim)
        tmp = starts(dim);
        starts(dim) = stops(dim);
        stops(dim) = tmp;
    end

    starts(dim) = max(1,starts(dim));
    stops(dim) = min(limits(dim),stops(dim));

    if starts(dim) > limits(dim) || stops(dim) < 1 || starts(dim) > stops(dim)
        starts(dim) = 1;
        stops(dim) = limits(dim);
    end
end
crop_idxs = [starts(1) stops(1) starts(2) stops(2) starts(3) stops(3)];
cropSize = [crop_idxs(2)-crop_idxs(1)+1 crop_idxs(4)-crop_idxs(3)+1 crop_idxs(6)-crop_idxs(5)+1];

cIMc=zeros(cropSize,tp);
for zz=1:size(cIMc,3)
    if ~isempty(cancelFcn) && cancelFcn()
        error('SENPAI:Cancelled','Operation cancelled by the user.')
    end
    cIMc(:,:,zz) = imread(inputFile,crop_idxs(5)+zz-1,...
        'PixelRegion',{[crop_idxs(1) crop_idxs(2)],[crop_idxs(3) crop_idxs(4)]});
end
tmpFile = fullfile(path_out,'tmp_crp.tif');
if isfile(tmpFile)
    delete(tmpFile);
end
tmpSlice = cIMc(:,:,1);
if bitl == 16
    tmpSlice = uint16(tmpSlice);
end
imwrite(tmpSlice,tmpFile,'tif','Compression','none');
for sl=2:size(cIMc,3)
    tmpSlice = cIMc(:,:,sl);
    if bitl == 16
        tmpSlice = uint16(tmpSlice);
    end
    imwrite(tmpSlice,tmpFile,'WriteMode','append','Compression','none');
end

%% SENPAI LOOP
numK = stopK-startK+1;
for ff = startK:stopK
    if ~isempty(cancelFcn) && cancelFcn()
        error('SENPAI:Cancelled','Operation cancelled by the user.')
    end
    folderBase = sprintf('k_for_%d_classes',ff);
    path_out_cl = fullfile(path_out,folderBase);
    suffix = 1;
    while isfolder(path_out_cl)
        path_out_cl = fullfile(path_out,sprintf('%s_%03d',folderBase,suffix));
        suffix = suffix + 1;
    end
    
    segInputPath = path_out;
    if segInputPath(end) ~= filesep
        segInputPath = [segInputPath filesep];
    end
    kIndex = ff-startK+1;
    baseProgress = 0.05+0.85.*((kIndex-1)./numK);
    progressScale = 0.85./numK;
    if ~isempty(progressFcn)
        progressFcn(baseProgress,sprintf('Testing K=%d (%d/%d)',ff,kIndex,numK));
        innerProgressFcn = @(fraction,message) progressFcn( ...
            baseProgress+progressScale.*min(max(double(fraction),0),1), ...
            sprintf('K=%d: %s',ff,message));
    elseif ~isempty(cancelFcn)
        innerProgressFcn = @(~,~) [];
    else
        innerProgressFcn = [];
    end
    senpai_seg_core_v4(segInputPath, 'tmp_crp.tif', path_out_cl, 0, cropSize, 1, 0, ff, ...
        innerProgressFcn,cancelFcn);
    if ~isempty(progressFcn)
        progressFcn(baseProgress+progressScale,sprintf('Analyzing K=%d',ff));
    end
    crop_x_len = cropSize(1);
    crop_y_len = cropSize(2);
    load(fullfile(path_out_cl,sprintf('sl1_1_%d_1_%d.mat',crop_x_len,crop_y_len)), ...
        'TOT_KM1', 'GxxKt', 'GyyKt', 'GzzKt')

    % Analisi distribuzioni
    senpai_KM_lv1 = TOT_KM1;  
    for kk = 2:ff    % Creo matrice contenete sulle righe le derivate e sulle colonne la percentuale di distribuzione positiva
        dist_xx = zeros(1,kk);
        dist_yy = zeros(1,kk);
        dist_zz = zeros(1,kk);
        for tt = 1:kk
            dist_xx(1,tt) = sum(sum(sum(GxxKt(senpai_KM_lv1(:)==tt)>0)))/sum(sum(sum(senpai_KM_lv1(:)==tt,2)));  % Numero delle derivate (per ogni classe) a valore positivo / numero delle derivate della classe 
            dist_yy(1,tt) = sum(sum(sum(GyyKt(senpai_KM_lv1(:)==tt)>0)))/sum(sum(sum(senpai_KM_lv1(:)==tt,3)));
            dist_zz(1,tt) = sum(sum(sum(GzzKt(senpai_KM_lv1(:)==tt)>0)))/sum(sum(sum(senpai_KM_lv1(:)==tt,4)));
        end

        th = 0.75;  % Soglia per capire qunado ci va bene
        dist_tot = [dist_xx; dist_yy; dist_zz];
        save(fullfile(path_out,'dist.mat'),'dist_tot')
        dist_seg = dist_tot > th;
    end

    val_class = sum(sum(dist_seg,1)>0);  % Somma sulle righe (>0 perchè ci va bene che siano anche più di una)
    val_der = sum(sum(dist_seg,2)>0);  % Somma sulle colonne
    if val_class >= 3 && val_der == 3  % Se ci viene 3 in tutte e due vuol dire che abbiamo almeno una distribuzione positiva per ciascuna classe
       Kopt = ff;
       break
    elseif ff == stopK
           Kopt = stopK;
           warning('no K in the range [2 10] satisfied the criteria. Kopt was set to 10.')
    end
end
clear cleanupFolder
