function parcel_final=senpai_separator(senpai_seg,cIM,somas,varargin)
    % senpai_separator:
    %   takes the result of a k-means clustering performed by
    %   senpai_seg_core and produces separated segmentations of single 
    %   neurons. The program is intended to be used when the segmentation 
    %   produced on low-magnification images fails to correctly separate 
    %   neurons.
    %
    %   Execute the function in the command window:
    %   Syntax:
    %       parcel_final = senpai_neurogrow;
    %       parcel_final = senpai_neurogrow(senpai_KM_lv1,cIM,somas)
    %
    %   Inputs:
    %       senpai_seg: logical matrix with the final segmentation produced by senpai_seg_core.m.
    %
    %       cIM:   numeric matrix. Image that generated the senpai_KM_lv1 segmentation
    %              (e.g., senpai_KM_lv1 = senpai_seg_core(path_in,im_in,varargin)
    %
    %       somas:  logical matrix encoding a gross binary segmentation of the somas in the image
    %
    %   Output:
    %       parcel_final: numeric matrix with the parcelation of the final
    %                     Kmeans segmentation. Every value of the matrix correspond to a
    %                     neuron.
    progressFcn=[];
    cancelFcn=[];
    if nargin>3
        progressFcn=varargin{1};
    end
    if nargin>4
        cancelFcn=varargin{2};
    end

    %take the negative of the image filtered with a median filter
    disp('Separating neurons...')
    reportProgress(0.05,'Preparing parcellation');
    checkCancel();
    senpai_seg=logical(senpai_seg);
    db=max(cIM(:));
    cIM_inv=db-medfilt3(cIM);
    cIM_inv(~senpai_seg)=db;
    clear cIM
    reportProgress(0.25,'Imposing soma minima');
    checkCancel();
    %impose minima in the mask of somas
    cIM_inv=imimposemin(cIM_inv,somas);
    %watershed transform
    reportProgress(0.40,'Watershed parcellation');
    checkCancel();
    ww=uint16(watershed(cIM_inv)); %must be uint16
    %provide final parcellation
    parcel_final=ww.*uint16(senpai_seg);
    neuLst=1:max(ww(:));
    save senpai_separator.mat ww
    clear ww senpai_seg
    %remove non-connected pieces
    disp('Pruning non-connected branches...')
    totalLabels=numel(neuLst);
    for idx=1:totalLabels
        checkCancel();
        vv=neuLst(idx);
        bb=bwconncomp(parcel_final==vv,6);
        if bb.NumObjects==0
            continue
        end
        [~, ii]=max(cellfun(@length, bb.PixelIdxList));
        clusLst=1:bb.NumObjects;
        parcel_final(cell2mat(bb.PixelIdxList(clusLst(clusLst~=ii))'))=0;
        reportProgress(0.50+0.45*(idx/max(totalLabels,1)), ...
            sprintf('Pruning label %d/%d',idx,totalLabels));
    end
    save senpai_separator.mat parcel_final -append
    reportProgress(1,'Parcellation complete');
    disp('Done!')

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
