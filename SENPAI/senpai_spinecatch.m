function [WS_m, parcel_ws] = senpai_spinecatch(seg,cIM,sz_th,varargin)
    
    % senpai_spinecatch:
    %   takes the result of a k-means clustering performed by
    %   senpai_seg_core and 
    %   defines catchment basins for branches with watershed method. 
    %   Dendritic spines are expected to fall within the catchment basin
    %   of the dentritic branch to which they belong.
    %   
    %   Execute the function in the command window:
    %   Syntax:
    %       WS_m = senpai_spinecatch(seg,cIM,sz_th);
    %
    %   Inputs:
    %       seg: logical matrix. senpai segmentation
    %           (e.g., 'senpai_final' in senpai_final.mat)
    %
    %       cIM: numeric matrix. Image that generated the senpai segmentation
    %           (e.g., senpai_KM = senpai_seg_core(path_in,im_in,varargin)
    %
    %       sz_th: integer representing the lower limit for the size of
    %              clusters of interest. If double it will be rounded to the lower
    %              integer
    %       sz_th (int): lower limit for the size of clusters of interest.
    %                    Default is 500, which was tested on 93x images.
    %
    %
    %   Outputs:
    %       WS_m: matrix of catchment basins as defined by the watershed
    %             function 
    %
    %       parcel_ws: numeric matrix with the parcelation of the final
    %                  Kmeans segmentation after the watershed assignation. Every value of the matrix 
    %                  correspond to a neuron.
    %
 

    % check input arguments
    if nargin<2
        warning('not enough input arguments')
        return
    end

    if nargin<3
        sz_th=500;
    end

    path_out = '';
    progressFcn=[];
    cancelFcn=[];
    if nargin>3
        path_out = varargin{1};
    end
    if nargin>4
        progressFcn = varargin{2};
    end
    if nargin>5
        cancelFcn = varargin{3};
    end

    reportProgress(0.05,'Preparing spinecatch');
    checkCancel();

    % round threshold to lower integer
    sz_th = floor(sz_th);

    % cIM casting (this limits out of memory issues)
    if isa(cIM,'single') || isa(cIM,'double')
        cIM=uint8(cIM./2^8); %costretto per motivi di memoria
    end
    reportProgress(0.15,'Median filter');
    checkCancel();

    % do some preprocessing for subsequent watershed
    towat=max(cIM(:))+1-medfilt3(cIM);
    clear cIM
    reportProgress(0.35,'Branch erosion');
    checkCancel();

    % remove small clusters: the goal is to retain only branches
    % image erosion
    segerod    = imerode(seg,strel('cube',3));
    segerod_bw = bwconncomp(segerod,6);
    bigclus    = find(cellfun(@length,segerod_bw.PixelIdxList)>sz_th);
    reportProgress(0.55,'Selecting large clusters');
    checkCancel();

    % initialize volume
    segerod_red=zeros(size(segerod),'logical');

    % assign cluster
    if ~isempty(bigclus)
        segerod_red(cell2mat(segerod_bw.PixelIdxList(bigclus)'))=1;
    end
    reportProgress(0.65,'Watershed minima');
    checkCancel();

    % clean memory
    clear segerod_bw segerod BW2f bigclus

    % watershed!
    towat_m = imimposemin(towat,segerod_red);
    reportProgress(0.75,'Watershed spinecatch');
    checkCancel();
    WS_m    = watershed(towat_m);
    parcel_ws = WS_m.*uint8(seg);
    reportProgress(0.90,'Saving spinecatch');
    checkCancel();
    
    if isempty(path_out)
        path_out = uigetdir;
        if isequal(path_out,0)
            warning('No output folder selected. Results were not saved.')
            return
        end
    end
    if ~isfolder(path_out)
        mkdir(path_out)
    end
    save(fullfile(path_out,'senpai_spinecatch.mat'), 'parcel_ws', 'WS_m')
    reportProgress(1,'Spinecatch complete');

    disp('DONE!')

    function reportProgress(fraction,message)
        if ~isempty(progressFcn)
            progressFcn(fraction,message);
        end
    end

    function checkCancel()
        if ~isempty(cancelFcn) && cancelFcn()
            error('SENPAI:Cancelled','Operation cancelled by the user.')
        end
    end
end
