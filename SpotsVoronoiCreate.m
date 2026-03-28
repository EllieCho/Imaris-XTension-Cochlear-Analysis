%
%
% ========================================================================
% Author Information
% ========================================================================
% Dr Ellie Cho
% Biological Optical Microscopy Platform (BOMP)
% The University of Melbourne
%
% Contact: ellie.cho@unimelb.edu.au
%          bomp-enquiries@unimelb.edu.au
%
% ========================================================================
% Description
% ========================================================================
% Generates 3D Voronoi tessellation from spots with extrapolation beyond endpoints.
% Creates a labeled channel with spot IDs.
% 
% ========================================================================
% Version
% ========================================================================
% 1.0: Updated March 2026 Tested in Imaris 10.2
%
% ========================================================================
% Installation
% ========================================================================
% Copy this file into the XTensions folder in the Imaris installation directory
%
%  <CustomTools>
%    <Menu>
%      <Submenu name="Spots Functions">
%        <Item name="Create Voronoi Channel" icon="Matlab">
%          <Command>MatlabXT::SpotsVoronoiCreate(%i)</Command>
%        </Item>
%      </Submenu>
%    </Menu>
%    <SurpassTab>
%      <SurpassComponent name="bpSpots">
%        <Item name="Create Voronoi Channel" icon="Matlab">
%          <Command>MatlabXT::SpotsVoronoiCreate(%i)</Command>
%        </Item>
%      </SurpassComponent>
%    </SurpassTab>
%  </CustomTools>
%

function SpotsVoronoiCreate(aImarisApplicationID)

% Connect to Imaris interface
if ~isa(aImarisApplicationID, 'Imaris.IApplicationPrxHelper')
    javaaddpath ImarisLib.jar
    vImarisLib = ImarisLib;
    if ischar(aImarisApplicationID)
        aImarisApplicationID = round(str2double(aImarisApplicationID));
    end
    vImarisApplication = vImarisLib.GetApplication(aImarisApplicationID);
else
    vImarisApplication = aImarisApplicationID;
end

% Validate Surpass scene exists
vSurpassScene = vImarisApplication.GetSurpassScene;
if isequal(vSurpassScene, [])
    msgbox('Please create some objects in the Surpass scene!');
    return;
end

% Get and validate Spots selection
vFactory = vImarisApplication.GetFactory;
vSpots = vFactory.ToSpots(vImarisApplication.GetSurpassSelection);

% Search for spots if not previously selected
if ~vFactory.IsSpots(vSpots)
    for vChildIndex = 1:vSurpassScene.GetNumberOfChildren
        vDataItem = vSurpassScene.GetChild(vChildIndex - 1);
        if vFactory.IsSpots(vDataItem)
            vSpots = vFactory.ToSpots(vDataItem);
            break;
        end
    end
    if isequal(vSpots, [])
        msgbox('Please create some spots first!');
        return;
    end
end


% Get spots data in original Imaris spot index order
positions = double(vSpots.GetPositionsXYZ);
spotIDs   = double(vSpots.GetIds);
numSpots  = size(positions, 1);
 
if numSpots < 2
    msgbox('Need at least 2 spots for Voronoi tessellation!');
    return;
end

% Ask user how to assign channel intensities
intensityChoice = questdlg( ...
    'How should Voronoi cell intensities be assigned?', ...
    'Voronoi Intensity Mode', ...
    'Sequential (1, 2, 3...)', 'Match Imaris Spot ID', 'Sequential (1, 2, 3...)');
 
if isempty(intensityChoice)
    return;
end

% Add undo point
vImarisApplication.DataSetPushUndo('Create Voronoi Channel');
    
  
% Ghost point extrapolated before first spot
p1         = positions(1, :);
p2         = positions(2, :);
dir1       = p1 - p2;
ghostStart = p1 + dir1 / norm(dir1) * norm(dir1);
 
% Ghost point extrapolated after last spot
pN        = positions(end, :);
pN1       = positions(end-1, :);
dirN      = pN - pN1;
ghostEnd  = pN + dirN / norm(dirN) * norm(dirN);
 
% Extended array: ghost start + original spots + ghost end
positionsExtended = [ghostStart; positions; ghostEnd];
numSpotsTotal     = size(positionsExtended, 1);

% Spot ID mapping
if strcmp(intensityChoice, 'Match Imaris Spot ID')
    maxSpotID      = max(spotIDs);
    vSpotIDMapping = [0; spotIDs; maxSpotID + 1];
else
    maxSpotID      = numSpots;
    vSpotIDMapping = [0; (1:numSpots)'; numSpots + 1];
end

% Check whether maxSpotID fits within the current dataset bitdepth
currentType = vImarisApplication.GetDataSet.GetType;
if strcmp(currentType, 'eTypeUInt8')
    bitdepthMax = 255;
elseif strcmp(currentType, 'eTypeUInt16')
    bitdepthMax = 65535;
else
    bitdepthMax = Inf;
end

targetType = currentType; 

if maxSpotID > bitdepthMax
    if isinf(bitdepthMax)
        % Proceed 
    elseif strcmp(currentType, 'eTypeUInt8')
        bitdepthChoice = questdlg( ...
            sprintf(['The maximum intensity value (%d) exceeds the current dataset bit depth (max %d).\n\n' ...
                     'How would you like to proceed?'], maxSpotID, bitdepthMax), ...
            'Bit Depth Warning', ...
            'Upgrade to 16-bit', 'Keep 8-bit (values above 255 will saturate)', 'Upgrade to 16-bit');
        if isempty(bitdepthChoice)
            return;
        end
        if strcmp(bitdepthChoice, 'Upgrade to 16-bit')
            targetType = 'eTypeUInt16';
        else
            fprintf('Warning: intensity values above %d will saturate to %d\n', bitdepthMax, bitdepthMax);
        end
    else
        % uint16 and still exceeding - warn only
        fprintf('Warning: intensity values above %d will saturate to %d\n', bitdepthMax, bitdepthMax);
    end
end

% Initialise new channel
[vDataSet, vMin, vMax, vType] = InitNewChannel(vImarisApplication, targetType);
vChannel = vDataSet.GetSizeC - 1; 
 
vSizeX = vDataSet.GetSizeX;
vSizeY = vDataSet.GetSizeY;
vSizeZ = vDataSet.GetSizeZ;
 
vVoxelSizeX = (vMax(1) - vMin(1)) / vSizeX;
vVoxelSizeY = (vMax(2) - vMin(2)) / vSizeY;
vVoxelSizeZ = (vMax(3) - vMin(3)) / vSizeZ;
 
vProgressDisplay = waitbar(0, 'Creating Voronoi tessellation...'); 
    
% Create Voronoi labeled volume with fixed 10-slice chunking
chunkSize = 10; 

if numSpotsTotal <= 255
    vLabeledVolume = zeros(vSizeX, vSizeY, vSizeZ, 'uint8');
else
    vLabeledVolume = zeros(vSizeX, vSizeY, vSizeZ, 'uint16');
end

    
% Create 2D grid for X,Y coordinates within each slice
[vGridX, vGridY] = meshgrid( ...
    linspace(vMin(1) + vVoxelSizeX/2, vMax(1) - vVoxelSizeX/2, vSizeX), ...
    linspace(vMin(2) + vVoxelSizeY/2, vMax(2) - vVoxelSizeY/2, vSizeY));
 
vGridX = vGridX'; % Transpose to match X,Y order
vGridY = vGridY';
    
% Process slices in chunks
numChunks = ceil(vSizeZ / chunkSize);
    
for chunkIdx = 1:numChunks
 
    startSlice       = (chunkIdx - 1) * chunkSize + 1;
    endSlice         = min(chunkIdx * chunkSize, vSizeZ);
    currentChunkSize = endSlice - startSlice + 1;
 
    % Z coordinates for all slices in this chunk
    zCoords = vMin(3) + vVoxelSizeZ/2 + (startSlice-1:endSlice-1) * vVoxelSizeZ;
 
    % Voxel positions for the entire chunk
    numVoxelsPerSlice   = numel(vGridX);
    chunkVoxelPositions = zeros(numVoxelsPerSlice * currentChunkSize, 3);
 
    for sliceOffset = 1:currentChunkSize
        rowStart = (sliceOffset - 1) * numVoxelsPerSlice + 1;
        rowEnd   = sliceOffset * numVoxelsPerSlice;
        chunkVoxelPositions(rowStart:rowEnd, :) = ...
            [vGridX(:), vGridY(:), repmat(zCoords(sliceOffset), numVoxelsPerSlice, 1)];
    end
 
        
    % Assign each voxel to nearest spot
    numChunkVoxels = size(chunkVoxelPositions, 1);
    minDistances   = inf(numChunkVoxels, 1);
    voxelLabels    = ones(numChunkVoxels, 1);
 
  
    for spotIdx = 1:numSpotsTotal
        spotPos = positionsExtended(spotIdx, :);
        dx = chunkVoxelPositions(:,1) - spotPos(1);
        dy = chunkVoxelPositions(:,2) - spotPos(2);
        dz = chunkVoxelPositions(:,3) - spotPos(3);
        distances = sqrt(dx.^2 + dy.^2 + dz.^2);
 
        closerMask = distances < minDistances;
        minDistances(closerMask) = distances(closerMask);
        voxelLabels(closerMask)  = spotIdx;
    end
    
    % Store results for this chunk
    for sliceOffset = 1:currentChunkSize
        rowStart    = (sliceOffset - 1) * numVoxelsPerSlice + 1;
        rowEnd      = sliceOffset * numVoxelsPerSlice;
        sliceLabels = voxelLabels(rowStart:rowEnd);
        vLabeledVolume(:, :, startSlice + sliceOffset - 1) = reshape(sliceLabels, size(vGridX));
    end
 
    progress = 0.15 + 0.7 * (endSlice / vSizeZ);
    waitbar(progress, vProgressDisplay, ...
        sprintf('Creating Voronoi tessellation... slice %d/%d', endSlice, vSizeZ));
end
       
% Map internal indices back to spot IDs
if strcmp(vType, 'eTypeUInt8')
    vLabeledVolumeOriginalIDs = zeros(vSizeX, vSizeY, vSizeZ, 'uint8');
elseif strcmp(vType, 'eTypeUInt16')
    vLabeledVolumeOriginalIDs = zeros(vSizeX, vSizeY, vSizeZ, 'uint16');
else
    vLabeledVolumeOriginalIDs = zeros(vSizeX, vSizeY, vSizeZ, 'single');
end

for i = 1:numSpotsTotal
    vLabeledVolumeOriginalIDs(vLabeledVolume == i) = vSpotIDMapping(i);
end
vLabeledVolume = vLabeledVolumeOriginalIDs;

% Write data back to Imaris
waitbar(0.9, vProgressDisplay, 'Adding Voronoi channel to dataset...');
 
if strcmp(vType, 'eTypeUInt8')
    for vIndexZ = 1:vSizeZ
        vDataSet.SetDataSliceBytes(vLabeledVolume(:, :, vIndexZ), vIndexZ-1, vChannel, 0);
    end
elseif strcmp(vType, 'eTypeUInt16')
    for vIndexZ = 1:vSizeZ
        vDataSet.SetDataSliceShorts(vLabeledVolume(:, :, vIndexZ), vIndexZ-1, vChannel, 0);
    end
else
    for vIndexZ = 1:vSizeZ
        vDataSet.SetDataSliceFloats(vLabeledVolume(:, :, vIndexZ), vIndexZ-1, vChannel, 0);
    end
end
 
% Set channel properties
if strcmp(intensityChoice, 'Match Imaris Spot ID')
    channelMethodLabel = 'Imaris ID';
else
    channelMethodLabel = 'sequential';
end
vDataSet.SetChannelName(vChannel, sprintf('Voronoi Cells (%s)', channelMethodLabel));

vDataSet.SetChannelRange(vChannel, 0, double(maxSpotID + 1));
vRGBA = 255 + 255*256 + 0*256*256 + 255*256*256*256; % Yellow
vDataSet.SetChannelColorRGBA(vChannel, vRGBA);
vImarisApplication.SetDataSet(vDataSet);
 
close(vProgressDisplay);

end


%% Helper Functions

function [aDataSet, aMin, aMax, aType] = InitNewChannel(aImaris, targetType)
% Initialise a new empty channel in the dataset
 
aDataSet = aImaris.GetDataSet.Clone;
aMin  = [aDataSet.GetExtendMinX, aDataSet.GetExtendMinY, aDataSet.GetExtendMinZ];
aMax  = [aDataSet.GetExtendMaxX, aDataSet.GetExtendMaxY, aDataSet.GetExtendMaxZ];
 
if nargin >= 2 && ~isempty(targetType) && ~strcmp(aDataSet.GetType, targetType)
    if strcmp(targetType, 'eTypeUInt8')
        aDataSet.SetType(Imaris.tType.eTypeUInt8);
    elseif strcmp(targetType, 'eTypeUInt16')
        aDataSet.SetType(Imaris.tType.eTypeUInt16);
    else
        aDataSet.SetType(Imaris.tType.eTypeFloat);
    end
end
 
aDataSet.SetSizeC(aDataSet.GetSizeC + 1);
aType = aDataSet.GetType;
end