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
% Generates a new channel where the intensity is set to
% create a cylindrical shape for each spot based on a given diameter and thickness. 
% 
% The cylinder axis is oriented perpendicular to the local spot direction,
% calculated using the original Imaris spot index order.
%
% Cylinder diameter and thickness can be identical for all spots,
% or specified per spot via a CSV file
%  - CSV format: 
%       column 1 = Imaris Spot ID 
%       column 2 = cylinder diameter (um)
%       column 3 = thickness (um)
%       one row per spot
% 
% ========================================================================
% Version
% ========================================================================
% 1.0: Updated March 2026. Tested in Imaris 10.2
%
% ========================================================================
% Installation
% ========================================================================
% Copy this file into the XTensions folder in the Imaris installation directory
%
%    <CustomTools>
%      <Menu>
%       <Submenu name="Spots Functions">
%        <Item name="Create Cylinders from Spots" icon="Matlab">
%          <Command>MatlabXT::SpotsToCylinder(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpSpots">
%          <Item name="Create Cylinders from Spots" icon="Matlab">
%            <Command>MatlabXT::SpotsToCylinder(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>


function SpotsToCylinder(aImarisApplicationID)

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

% Check for surpass scene
vSurpassScene = vImarisApplication.GetSurpassScene;
if isequal(vSurpassScene, [])
    msgbox('Please create some Spots in the Surpass scene!');
    return;
end

% Get the spots object
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
        msgbox('Please create some spots!');
        return;
    end
end

% Get spots data
positions = double(vSpots.GetPositionsXYZ);
spotIDs   = double(vSpots.GetIds);
numSpots  = size(positions, 1);

if numSpots < 2
    msgbox('Need at least 2 spots to create cylinders!');
    return;
end

% Ask user whether cylinder parameters are uniform or per-spot
uniformChoice = questdlg( ...
    'Are the cylinder diameter and thickness identical for all spots?', ...
    'Cylinder Parameters', ...
    'Identical for all', 'Various (load CSV)', 'Identical for all');

if isempty(uniformChoice)
    return; 
end

if strcmp(uniformChoice, 'Identical for all')

    answer = inputdlg( ...
        {'Cylinder diameter (um):', 'Cylinder thickness (um):'}, ...
        'Cylinder Parameters', 1, {'500', '300'});

    if isempty(answer)
        return; 
    end

    cylinderDiameter  = str2double(answer{1});
    cylinderThickness = str2double(answer{2});

    if isnan(cylinderDiameter) || isnan(cylinderThickness) || ...
            cylinderDiameter <= 0 || cylinderThickness <= 0
        msgbox('Please enter valid positive values for diameter and thickness.');
        return;
    end

    cylinderDiameters   = repmat(cylinderDiameter,  numSpots, 1);
    cylinderThicknesses = repmat(cylinderThickness, numSpots, 1);
    channelParamLabel   = sprintf('D=%.0fum T=%.0fum', cylinderDiameter, cylinderThickness);

else
    
    [csvFile, csvPath] = uigetfile('*.csv', 'Select CSV file with cylinder parameters');
    if isequal(csvFile, 0)
        return;
    end
 
    csvData = readmatrix(fullfile(csvPath, csvFile));
 
    if size(csvData, 2) < 3
        msgbox('CSV must have 3 columns: Spot ID (column 1), Diameter in um (column 2), Thickness in um (column 3).');
        return;
    end 
    
    csvSpotIDs = csvData(:, 1);
 
    if length(unique(csvSpotIDs)) < length(csvSpotIDs)
        msgbox('CSV contains duplicate Spot IDs. Each spot must appear only once.');
        return;
    end
 
    cylinderDiameters   = NaN(numSpots, 1);
    cylinderThicknesses = NaN(numSpots, 1);
    
    % Match each CSV row to the corresponding spot by Imaris ID
    for k = 1:size(csvData, 1)
        idx = find(spotIDs == csvSpotIDs(k), 1);
        if isempty(idx)
            msgbox(sprintf('CSV Spot ID %d does not match any spot in the current Spots object.\nPlease check the CSV file.', ...
                csvSpotIDs(k)));
            return;
        end
        cylinderDiameters(idx)   = csvData(k, 2);
        cylinderThicknesses(idx) = csvData(k, 3);
    end
 
    channelParamLabel = 'per csv';
     
end

% Ask user how to assign cylinder intensities
intensityChoice = questdlg( ...
    'How should cylinder intensities be assigned?', ...
    'Cylinder Intensity Mode', ...
    'Sequential (1, 2, 3...)', 'Match Imaris Spot ID (+1)', 'Sequential (1, 2, 3...)');
 
if isempty(intensityChoice)
    return;
end
 
% Build per-spot intensity values
if strcmp(intensityChoice, 'Match Imaris Spot ID (+1)')
    intensityValues = spotIDs + 1;
    maxIntensity    = max(intensityValues);
    intensityLabel  = 'Imaris ID+1';
else
    intensityValues = (1:numSpots)';
    maxIntensity    = numSpots;
    intensityLabel  = 'sequential';
end
 
% Check bitdepth is sufficient for maximum intensity value
currentType = vImarisApplication.GetDataSet.GetType;
if strcmp(currentType, 'eTypeUInt8')
    bitdepthMax = 255;
elseif strcmp(currentType, 'eTypeUInt16')
    bitdepthMax = 65535;
else
    bitdepthMax = Inf;
end
 
targetType = currentType;
 
if maxIntensity > bitdepthMax
    if strcmp(currentType, 'eTypeUInt8')
        bitdepthChoice = questdlg( ...
            sprintf(['The maximum intensity value (%d) exceeds the current dataset bit depth (max %d).\n\n' ...
                     'How would you like to proceed?'], maxIntensity, bitdepthMax), ...
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
        fprintf('Warning: intensity values above %d will saturate to %d\n', bitdepthMax, bitdepthMax);
    end
end
 

% Add undo point
vImarisApplication.DataSetPushUndo('Create Cylinders from Spots');
 
% Initialise new channel
[vDataSet, vData, vMin, vMax, vType] = InitNewChannel(vImarisApplication, targetType);
vChannel = vDataSet.GetSizeC - 1;
 
% Get voxel sizes
voxelSizeX   = (vMax(1) - vMin(1)) / vDataSet.GetSizeX;
voxelSizeY   = (vMax(2) - vMin(2)) / vDataSet.GetSizeY;
voxelSizeZ   = (vMax(3) - vMin(3)) / vDataSet.GetSizeZ;
minVoxelSize = min([voxelSizeX, voxelSizeY, voxelSizeZ]);
 
% Optimal plane spacing for smooth cylinder fill
optimalPlaneSpacing = minVoxelSize;
 
vWaitBar = waitbar(0, 'Creating Cylinders from Spots');
totalPlanesCreated = 0;

% Ghost point extrapolated before spot ID 0 (first in time group)
p1         = positions(1, :);
p2         = positions(2, :);
dir1       = p1 - p2;
ghostStart = p1 + dir1 / norm(dir1) * norm(dir1);

% Ghost point extrapolated after the last spot
pN        = positions(end, :);
pN1       = positions(end-1, :);
dirN      = pN - pN1;
ghostEnd  = pN + dirN / norm(dirN) * norm(dirN);

% Extended array
positionsExtended = [ghostStart; positions; ghostEnd];


% Process each spot in Imaris spot ID order
for spotIdx = 1:numSpots
 
    % Corresponding row in the extended array
    extIdx     = spotIdx + 1;
    centerSpot = positionsExtended(extIdx, :);
 
    % Skip if no CSV entry was provided for this spot
    if isnan(cylinderDiameters(spotIdx))
        fprintf('  Spot ID %d: no CSV entry, skipped\n', spotIDs(spotIdx));
        continue;
    end
 
    % Cylinder parameters for this spot
    planeDiameter     = cylinderDiameters(spotIdx);
    thisThickness     = cylinderThicknesses(spotIdx);
    extensionDistance = thisThickness / 2;
 
    % Local direction from sequential neighbours in the extended array
    vectorDir = calculateLocalDirection(positionsExtended, extIdx);
 
    if norm(vectorDir) < 1e-6
        fprintf('  Spot ID %d: direction vector near zero, skipped\n', spotIDs(spotIdx));
        continue;
    end
 
    vectorDir = vectorDir / norm(vectorDir);
 
    % Plane thickness for smooth overlap within the cylinder
    planeThickness = minVoxelSize * 2;
    halfThickness  = planeThickness / 2;
 
    % Adjust extension so outer plane edges align with requested thickness
    effectiveExtension   = extensionDistance - halfThickness;
    totalExtensionLength = 2 * effectiveExtension;
 
    point1    = centerSpot - vectorDir * effectiveExtension;
    point2    = centerSpot + vectorDir * effectiveExtension;
    numPlanes = max(1, round(totalExtensionLength / optimalPlaneSpacing));
 
    % Draw interpolated planes along the cylinder axis
    for planeIdx = 0:numPlanes
        t             = planeIdx / numPlanes;
        planePosition = point1 * (1 - t) + point2 * t;
 
        vData = DrawPlaneWithIntensity(vData, planePosition, vectorDir, ...
            planeDiameter, planeThickness, vMin, vMax, vType, intensityValues(spotIdx));
 
        totalPlanesCreated = totalPlanesCreated + 1;
    end
    
    if mod(spotIdx, 5) == 0
        waitbar(spotIdx / numSpots, vWaitBar);
    end
end
 
close(vWaitBar);
 
% Write data back to Imaris
if strcmp(vDataSet.GetType, 'eTypeUInt8')
    for vIndexZ = 1:size(vData, 3)
        vDataSet.SetDataSliceBytes(vData(:, :, vIndexZ), vIndexZ-1, vChannel, 0);
    end
elseif strcmp(vDataSet.GetType, 'eTypeUInt16')
    for vIndexZ = 1:size(vData, 3)
        vDataSet.SetDataSliceShorts(vData(:, :, vIndexZ), vIndexZ-1, vChannel, 0);
    end
else
    for vIndexZ = 1:size(vData, 3)
        vDataSet.SetDataSliceFloats(vData(:, :, vIndexZ), vIndexZ-1, vChannel, 0);
    end
end
 
% Set channel properties
vRGBA = 255 + 255*256 + 0*256*256 + 255*256*256*256; % Yellow
vDataSet.SetChannelName(vChannel, sprintf('Spot Cylinders (%s, %s)', channelParamLabel, intensityLabel));
vDataSet.SetChannelColorRGBA(vChannel, vRGBA);
vDataSet.SetChannelRange(vChannel, 0, double(maxIntensity));
vImarisApplication.SetDataSet(vDataSet);
 
fprintf('\n=== Spot Cylinders Creation Complete ===\n');
fprintf('Total cylinders      : %d\n', numSpots);
fprintf('Total planes created : %d\n\n', totalPlanesCreated);
 
end
 

function vectorDir = calculateLocalDirection(positions, spotIdx)
 
numRows = size(positions, 1);
 
prevIdx = max(spotIdx - 1, 1);
nextIdx = min(spotIdx + 1, numRows);
 
if prevIdx == nextIdx
    vectorDir = [0, 0, 0];
    return;
end
 
vectorDir = positions(nextIdx, :) - positions(prevIdx, :);
 
if norm(vectorDir) > 1e-6
    vectorDir = vectorDir / norm(vectorDir);
else
    vectorDir = [0, 0, 0];
end
end
 
function aData = DrawPlaneWithIntensity(aData, aCenter, aNormal, aDiameter, aThickness, aMin, aMax, aType, intensityValue)
 
vSize = [size(aData, 1), size(aData, 2), size(aData, 3)];
 
voxelSizeX = (aMax(1) - aMin(1)) / vSize(1);
voxelSizeY = (aMax(2) - aMin(2)) / vSize(2);
voxelSizeZ = (aMax(3) - aMin(3)) / vSize(3);
 
aCenterVoxel = [(aCenter(1) - aMin(1)) / voxelSizeX + 0.5, ...
                (aCenter(2) - aMin(2)) / voxelSizeY + 0.5, ...
                (aCenter(3) - aMin(3)) / voxelSizeZ + 0.5];
 
if any(aCenterVoxel < -aDiameter/(2*min([voxelSizeX, voxelSizeY, voxelSizeZ]))) || ...
   any(aCenterVoxel > vSize + aDiameter/(2*min([voxelSizeX, voxelSizeY, voxelSizeZ])))
    return;
end
 
radiusVoxelX = (aDiameter / 2) / voxelSizeX;
radiusVoxelY = (aDiameter / 2) / voxelSizeY;
radiusVoxelZ = (aDiameter / 2) / voxelSizeZ;
 
thicknessVoxelX = aThickness / voxelSizeX;
thicknessVoxelY = aThickness / voxelSizeY;
thicknessVoxelZ = aThickness / voxelSizeZ;
 
absNormal        = abs(aNormal);
effectiveRadiusX = radiusVoxelX * sqrt(1 - absNormal(1)^2) + thicknessVoxelX * absNormal(1);
effectiveRadiusY = radiusVoxelY * sqrt(1 - absNormal(2)^2) + thicknessVoxelY * absNormal(2);
effectiveRadiusZ = radiusVoxelZ * sqrt(1 - absNormal(3)^2) + thicknessVoxelZ * absNormal(3);
 
vPosMin = round(max([aCenterVoxel(1) - effectiveRadiusX, ...
                     aCenterVoxel(2) - effectiveRadiusY, ...
                     aCenterVoxel(3) - effectiveRadiusZ], [1, 1, 1]));
vPosMax = round(min([aCenterVoxel(1) + effectiveRadiusX, ...
                     aCenterVoxel(2) + effectiveRadiusY, ...
                     aCenterVoxel(3) + effectiveRadiusZ], vSize));
 
vPosX = vPosMin(1):vPosMax(1);
vPosY = vPosMin(2):vPosMax(2);
vPosZ = vPosMin(3):vPosMax(3);
 
if isempty(vPosX) || isempty(vPosY) || isempty(vPosZ)
    return;
end
 
halfDiameterSquared = (aDiameter / 2)^2;
halfThickness       = aThickness / 2;
 
[vX, vY, vZ] = ndgrid(vPosX, vPosY, vPosZ);
 
vx_world = (vX - aCenterVoxel(1)) * voxelSizeX;
vy_world = (vY - aCenterVoxel(2)) * voxelSizeY;
vz_world = (vZ - aCenterVoxel(3)) * voxelSizeZ;
 
dotProduct    = vx_world * aNormal(1) + vy_world * aNormal(2) + vz_world * aNormal(3);
planeDistance = abs(dotProduct);
 
thicknessCheck = planeDistance <= halfThickness;
 
if any(thicknessCheck(:))
    projX = vx_world - dotProduct * aNormal(1);
    projY = vy_world - dotProduct * aNormal(2);
    projZ = vz_world - dotProduct * aNormal(3);
 
    radialDistanceSquared = projX.^2 + projY.^2 + projZ.^2;
    vInside = thicknessCheck & (radialDistanceSquared <= halfDiameterSquared);
 
    if any(vInside(:))
        vCube = aData(vPosX, vPosY, vPosZ);
        vCube(vInside) = max(vCube(vInside), FixType(intensityValue, aType));
        aData(vPosX, vPosY, vPosZ) = vCube;
    end
end
end

function aData = FixType(aData, aType)
% Cast data to the correct Imaris data type
 
if strcmp(aType, 'eTypeUInt8')
    aData = uint8(aData);
elseif strcmp(aType, 'eTypeUInt16')
    aData = uint16(aData);
else
    aData = single(aData);
end
end
 
function [aDataSet, aData, aMin, aMax, aType] = InitNewChannel(aImaris, targetType)
% Initialise a new empty channel in the dataset
 
aDataSet = aImaris.GetDataSet.Clone;
aMin  = [aDataSet.GetExtendMinX, aDataSet.GetExtendMinY, aDataSet.GetExtendMinZ];
aMax  = [aDataSet.GetExtendMaxX, aDataSet.GetExtendMaxY, aDataSet.GetExtendMaxZ];
vSize = [aDataSet.GetSizeX, aDataSet.GetSizeY, aDataSet.GetSizeZ];
 
if nargin >= 2 && ~isempty(targetType) && ~strcmp(aDataSet.GetType, targetType)
    if strcmp(targetType, 'eTypeUInt8')
        aDataSet.SetType(Imaris.tType.eTypeUInt8);
    elseif strcmp(targetType, 'eTypeUInt16')
        aDataSet.SetType(Imaris.tType.eTypeUInt16);
    else
        aDataSet.SetType(Imaris.tType.eTypeFloat);
    end
end
 
if strcmp(aDataSet.GetType, 'eTypeUInt8')
    aData = zeros(vSize, 'uint8');
elseif strcmp(aDataSet.GetType, 'eTypeUInt16')
    aData = zeros(vSize, 'uint16');
else
    aData = zeros(vSize, 'single');
end
 
aDataSet.SetSizeC(aDataSet.GetSizeC + 1);
aType = aDataSet.GetType;
end
