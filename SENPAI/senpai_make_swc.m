% Assume 'V' is your 3D binary image (1s for neuron, 0s elsewhere)

% 1. Extract the 1-pixel wide skeleton
skel = bwskel(V, 'MinBranchLength', 3); % Prune branches shorter than 5 pixels

% 2. Get voxel coordinates of the skeleton
[z, y, x] = ind2sub(size(skel), find(skel));
nodes = [x, y, z]; % [X, Y, Z] 

% 3. Build a graph representation of the skeleton
numNodes = size(nodes, 1);
adjMatrix = false(numNodes, numNodes);

% Calculate distances to find immediate neighbors (6- or 26-connectivity)
for i = 1:numNodes
    distances = sum((nodes - nodes(i,:)).^2, 2);
    % Find neighboring voxels within a squared distance of 3 (connects adjacent diagonals)
    neighborIdx = find(distances > 0 & distances <= 3); 
    adjMatrix(i, neighborIdx) = true;
end

% Create graph and compute Minimum Spanning Tree
G = graph(adjMatrix);
T = minspantree(G); 

% 4. Convert Graph to SWC format [X, Y, Z, Radius, Parent_ID]
% (Assuming 1 for soma root for this example; update logic to find your actual soma)
rootNode = 1; 
[~, preds] = shortestpath(T, rootNode);
preds(isnan(preds)) = -1; % Root [0,0,0] has parent -1

swcData = zeros(numNodes, 7);
swcData(:,1) = 1:numNodes;          % Node ID
swcData(:,2) = 2;                   % Node Type (2 = Axon, 3 = Dendrite, etc.)
swcData(:,3) = nodes(:,1);          % X
swcData(:,4) = nodes(:,2);          % Y
swcData(:,5) = nodes(:,3);          % Z
swcData(:,6) = 1;                   % Radius (placeholder, can be calculated via bwdist)
swcData(:,7) = preds';              % Parent ID

% 5. Write to .swc text file
fileID = fopen('neuron_skeleton.swc', 'w');
fprintf(fileID, '# Generated from binary skeleton in MATLAB\n');
fprintf(fileID, '# id type x y z r parent\n');
for i = 1:numNodes
    fprintf(fileID, '%d %d %f %f %f %f %d\n', swcData(i,:));
end
fclose(fileID);
