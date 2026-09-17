function [t,swc]=senpai_skeletonize(cIM,neuron,somas)
    % senpai_skeletonize:
    %     produces a matlab tree structure and an swc-formatted matrix for
    %     the skeleton of a binary segmentation
    %
    %     Execute the function in the command window:
    %     Syntax:
    %
    %       [t,pred,swc,xn,yn,zn]=senpai_skeletonize(cIM,neuron,somas):
    %
    %       inputs
    %
    %       cIM = original image stack on which the segmetation has been
    %       produced
    %       neuron = binary segmentation of a single neuron
    %       somas = binary mask of one (or multiple) somas
    %
    %       outputs
    %       
    %       t = minimum spanning tree (matlab structure) of the neuron
    %       swc = swc-like matrix encoding the skeleton
    %

somas=somas>0;
if ~any(somas(:))
    error('senpai_skeletonize:EmptySoma','The soma mask does not contain any voxels.')
end

%include soma mask in the segmentation
originalNeuron=neuron>0;
neuronAndSomas=originalNeuron | somas;
% Keep a connected component containing both the selected neuron and a
% soma. Choosing the largest component unconditionally could select an
% unrelated soma and produce a degenerate one-node skeleton.
neusel=bwconncomp(neuronAndSomas,26);
containsNeuron=cellfun(@(idx) any(originalNeuron(idx)),neusel.PixelIdxList);
containsSoma=cellfun(@(idx) any(somas(idx)),neusel.PixelIdxList);
validComponents=find(containsNeuron & containsSoma);
if isempty(validComponents)
    error('senpai_skeletonize:SomaNotConnected', ...
        'The selected neuron is not connected to the soma mask.')
end
[~,largestValidComponent]=max(cellfun(@numel,neusel.PixelIdxList(validComponents)));
neuselN=validComponents(largestValidComponent);
neuron=false(size(neuronAndSomas));
neuron(neusel.PixelIdxList{neuselN})=1;
%fill holes
neuron=imfill(neuron==1,'holes');
somas=somas.*neuron;
if ~any(somas(:))
    error('senpai_skeletonize:SomaNotConnected', ...
        'The selected neuron is not connected to any voxel in the soma mask.')
end
%distance transform
bwd=bwdist(~neuron);
%start from simple matlab skeletonization
sk=bwskel(neuron,'MinBranchLength', 3);
%clean skeleton in soma
%sk(somas==1)=0;
% points = indeces of voxels in the skeleton
points=find(sk);
if isempty(points)
    error('senpai_skeletonize:EmptySkeleton','The selected neuron produced an empty skeleton.')
end
% xn yn zn: coordinates of the voxels in the skeleton
[xn, yn, zn]=ind2sub(size(neuron),points);

%this loop converts the matlab skeleton to a graph structure
done=zeros(1,length(points));
ni=[]; %edge origin
ne=[]; %edge end
s=[]; %weight
count=1;
while sum(done)<length(points) % fin che non li ho visti tutti
    nodesLeft=length(points)-sum(done);
    if mod(nodesLeft,100)==0 || nodesLeft<=10 || nodesLeft==length(points)
        fprintf('building skeleton: %g nodes left...\n',nodesLeft);
    end
    % define seed
    seedpoint=find(~done,1);
    seed=[xn(seedpoint) yn(seedpoint) zn(seedpoint)];
    % find neighbor
    nextmatch=find(sum(([xn yn zn]-seed).^2,2)<=3);
    nextmatch(nextmatch==seedpoint)=[];
    nextmatch(ismember(nextmatch,find(done)))=[];
    % define connection
    for vv=1:length(nextmatch)
        coupl=sort([seedpoint nextmatch(vv)]);
        ni(count)=coupl(1);
        ne(count)=coupl(2);
        s(count)=double(cIM(points(nextmatch(vv))));
        count=count+1;
    end
    done(seedpoint)=1;
end
% Build the graph directly from the edge lists. Using sparse here silently
% discards zero-weight edges (common inside a soma when cIM is zero), which
% can split an otherwise connected skeleton into several components.
graphtree=graph(ni,ne,s,length(points));

%convert graph to tree: check for cycles and remove them
G_ac=graphtree;
[~,edgecycles] = allcycles(G_ac,'MaxNumCycles',1);
while ~isempty(edgecycles)
    %length(edgecycles)
    cc=1;
    edgetmp=edgecycles{cc};
    % cost function for cycle cut: width+intensity
    widthCost=min(bwd(points(G_ac.Edges.EndNodes(:,2))),bwd(points(G_ac.Edges.EndNodes(:,1))));
    intensityCost=double(min(cIM(points(G_ac.Edges.EndNodes(:,2))),cIM(points(G_ac.Edges.EndNodes(:,1)))))./255;
    intdiff=widthCost+intensityCost;
    [~, mididx]=min(intdiff(edgetmp));
    G_ac=rmedge(G_ac,edgetmp(mididx));
    [~,edgecycles] = allcycles(G_ac,'MaxNumCycles',1);
end

% Define an explicit soma-root node. If multiple soma components are
% present, use the centroid of the largest one that belongs to this neuron.
somaStats=regionprops3(somas==1,'Volume','Centroid');
[~,largestSoma]=max(somaStats.Volume);
somaCentroid=round(somaStats.Centroid(largestSoma,:));
somaNode=[somaCentroid(2) somaCentroid(1) somaCentroid(3)];
xn=[xn;somaNode(1)];yn=[yn;somaNode(2)];zn=[zn;somaNode(3)];
points=[points;sub2ind(size(neuron),somaNode(1),somaNode(2),somaNode(3))];
G_ac=addnode(G_ac,1);
root_cand=length(xn);

% Remove the internal soma skeleton, then connect every remaining
% dendritic component to the explicit soma root. This also covers the case
% in which no soma-boundary edge was found; previously root_cand then
% exceeded numnodes(G_ac), producing MATLAB:graphfun:graph:InvalidNodeID.
xyzn=sub2ind(size(cIM),xn,yn,zn);
insideSoma=somas(xyzn);
internalSomaEdges=insideSoma(G_ac.Edges.EndNodes(:,1)) & ...
    insideSoma(G_ac.Edges.EndNodes(:,2));
G_ac_new=rmedge(G_ac,find(internalSomaEdges));
componentIds=conncomp(G_ac_new);
rootComponent=componentIds(root_cand);
for component=unique(componentIds)
    if component==rootComponent
        continue
    end
    componentNodes=find(componentIds==component);
    dendriteNodes=componentNodes(~insideSoma(componentNodes));
    if isempty(dendriteNodes)
        continue
    end
    offsets=[xn(dendriteNodes)-somaNode(1), ...
        yn(dendriteNodes)-somaNode(2),zn(dendriteNodes)-somaNode(3)];
    [~,nearestIndex]=min(sum(offsets.^2,2));
    dendriteRoot=dendriteNodes(nearestIndex);
    rootWeight=double(cIM(xyzn(dendriteRoot)));
    G_ac_new=addedge(G_ac_new,root_cand,dendriteRoot,rootWeight);
end

[t, pred]=minspantree(G_ac_new,'Type','tree','Root',root_cand);
tmpr=zeros(size(pred));tmpr(root_cand)=1;
t=rmnode(t,find(isnan(pred)));
tmpr(isnan(pred))=[];
root_cand=find(tmpr);
xn(isnan(pred))=[];
yn(isnan(pred))=[];
zn(isnan(pred))=[];
points(isnan(pred))=[];
[t, pred]=minspantree(t,'Type','tree','Root',root_cand);
%define leaf and bifurcation nodes
% nodi che appaiono 1 volta nella lista degli edge sono leaf, 3 volte sono
% biforcazioni. 2 volte è normale
[gc,gr]=groupcounts(t.Edges.EndNodes(:));
bifurc=gr(gc>2);
leaves=gr(gc==1);
leaves(leaves==root_cand)=[];

%build swc-like matrix
pred(pred==0)=-1;
swc=zeros(length(pred),7);
swc(:,1)=1:length(pred);
swc(:,2)=0;
swc(pred==0,2)=-1;
swc(leaves,2)=6;swc(bifurc,2)=5;
swc(:,3)=yn;
swc(:,4)=xn;
swc(:,5)=zn;
swc(:,6)=bwd(points);
swc(:,7)=pred;

% to produce a .swc file use:

% writematrix(swc,'neuron_skel.txt','Delimiter',' ');
% movefile neuron_skel.txt neuron_skel.swc

end
