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
% Creates separate surfaces for each intensity value in a labeled channel.
% Each unique intensity becomes its own surface object
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
%    <CustomTools>
%      <Menu>
%       <Submenu name="Surfaces Functions">
%        <Item name="Create Surfaces from Labeled Map" icon="Matlab">
%          <Command>MatlabXT::CreateSurfacesFromLabeledMap(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpSurfaces">
%          <Item name="Create Surfaces from Labeled Map" icon="Matlab">
%            <Command>MatlabXT::CreateSurfacesFromLabeledMap(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>

function CreateSurfacesFromLabeledMap(aImarisApplicationID)

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
    msgbox('Please create a Surpass scene first!');
    return;
end

% Add undo point
vImarisApplication.DataSetPushUndo('Create Surfaces from Labeled Map');

% Get dataset parameters
vDataSet = vImarisApplication.GetDataSet;
if isequal(vDataSet, [])
    msgbox('Please load a dataset first!');
    return;
end

aSizeC = vDataSet.GetSizeC;
aSizeX = vDataSet.GetSizeX;
aSizeY = vDataSet.GetSizeY;
aSizeZ = vDataSet.GetSizeZ;

% Compute voxel spacing for default smoothing factor (2x XY voxel size)
aExtendMinX = vDataSet.GetExtendMinX;
aExtendMaxX = vDataSet.GetExtendMaxX;
aExtendMinY = vDataSet.GetExtendMinY;
aExtendMaxY = vDataSet.GetExtendMaxY;
vXvoxelSpacing = (aExtendMaxX - aExtendMinX) / aSizeX;
vYvoxelSpacing = (aExtendMaxY - aExtendMinY) / aSizeY;
vDefaultSmoothingFactor = mean([vXvoxelSpacing, vYvoxelSpacing]) * 2;

% Create channel selection list
vChannelNames = cell(aSizeC, 1);
for i = 1:aSizeC
    vChannelNames{i} = char(vDataSet.GetChannelName(i-1));
end

% Let user select the labeled channel
[vChannelIndex, vOk] = listdlg('ListString', vChannelNames, ...
    'SelectionMode', 'single', ...
    'ListSize', [300 150], ...
    'Name', 'Select Labeled Channel', ...
    'PromptString', 'Select the channel containing labeled objects:');

if vOk < 1
    return;
end

vLabelChannel = vChannelIndex - 1; 

% Get user parameters
prompt = {'Minimum object size (voxels, 0 for all):'};
dlgtitle = 'Surface Creation Parameters';
dims = [1 50];
definput = {'10'};
answer = inputdlg(prompt, dlgtitle, dims, definput);
 
if isempty(answer)
    return;
end

minObjectSize = str2double(answer{1});

% Ask user for smoothing preference
vAnswer = questdlg('How should surfaces be generated?', ...
    'Surface Smoothing', ...
    'No Smoothing', 'Smoothing', 'No Smoothing');
if isempty(vAnswer) || isequal(vAnswer, 'Cancel')
    return;
end
 
vApplySmoothing = isequal(vAnswer, 'Smoothing');

if vApplySmoothing
    vSmoothingFactorStr = num2str(vDefaultSmoothingFactor, '%.4f');
    vSmoothAnswer = inputdlg( ...
        'Smoothing factor (default = 2x mean XY voxel spacing):', ...
        'Smoothing Factor', 1, {vSmoothingFactorStr});
    if isempty(vSmoothAnswer)
        return;
    end
    vSmoothingFactor = str2double(vSmoothAnswer{1});
else
    vSmoothingFactor = 0;
end

% Create a folder for the new surfaces
vFactory = vImarisApplication.GetFactory;
vSurfacesFolder = vFactory.CreateDataContainer;
if vApplySmoothing
    vSurfacesFolder.SetName(sprintf('Labeled Surfaces (Smoothing %.4f)', vSmoothingFactor));
else
    vSurfacesFolder.SetName('Labeled Surfaces (NoSmoothing)');
end


ip = vImarisApplication.GetImageProcessing;
vWaitBar = waitbar(0, 'Analysing labeled map...');
totalSurfacesCreated = 0;
    
% Read the labeled channel data, use appropriate method based on data type
if strcmp(vDataSet.GetType, 'eTypeUInt8')
    vLabelData = zeros(aSizeX, aSizeY, aSizeZ, 'uint8');
    for z = 0:aSizeZ-1
        vLabelData(:,:,z+1) = vDataSet.GetDataSliceBytes(z, vLabelChannel, 0);
    end
elseif strcmp(vDataSet.GetType, 'eTypeUInt16')
    vLabelData = zeros(aSizeX, aSizeY, aSizeZ, 'uint16');
    for z = 0:aSizeZ-1
        vLabelData(:,:,z+1) = vDataSet.GetDataSliceShorts(z, vLabelChannel, 0);
    end
else
    vLabelData = zeros(aSizeX, aSizeY, aSizeZ, 'single');
    for z = 0:aSizeZ-1
        vLabelData(:,:,z+1) = vDataSet.GetDataSliceFloats(z, vLabelChannel, 0);
    end
end
    
% Find unique intensity values (excluding 0 which is background)
uniqueLabels = unique(vLabelData(:));
uniqueLabels = uniqueLabels(uniqueLabels > 0);
    
% Create temporary dataset for surface creation
vTempDataSet = vDataSet.Clone;
vTempDataSet.SetSizeC(1);
 
% Process each label
for labelIdx = 1:length(uniqueLabels)
    currentLabel = uniqueLabels(labelIdx);
 
    % Create binary mask for this label
    vBinaryMask = (vLabelData == currentLabel);
 
    % Check object size
    if sum(vBinaryMask(:)) < minObjectSize
        continue;
    end
 
    % Write binary mask to temporary dataset
    vBinaryMaskUInt8 = uint8(vBinaryMask);
    for z = 0:aSizeZ-1
        vTempDataSet.SetDataSliceBytes(vBinaryMaskUInt8(:,:,z+1), z, 0, 0);
    end
 
    % Create surface using user-selected smoothing factor
    vSurface = ip.DetectSurfaces(vTempDataSet, [], 0, vSmoothingFactor, 0, true, 50, '');
 
    if ~isequal(vSurface, [])
        vSurface.SetName(sprintf('Label_%d', currentLabel));
        vSurfacesFolder.AddChild(vSurface, -1);
        totalSurfacesCreated = totalSurfacesCreated + 1;
    end
 
    waitbar(labelIdx / length(uniqueLabels), vWaitBar, ...
        sprintf('Creating surfaces... Label %d/%d', labelIdx, length(uniqueLabels)));
end
 
close(vWaitBar);

% Add folder to scene
if totalSurfacesCreated > 0
    vSurpassScene.AddChild(vSurfacesFolder, -1);
    fprintf('Surface creation complete.\n');
    if vApplySmoothing
        fprintf('Created %d smoothed surfaces (smoothing factor: %.4f) from labeled map\n', totalSurfacesCreated, vSmoothingFactor);
    else
        fprintf('Created %d non-smoothed surfaces from labeled map\n', totalSurfacesCreated);
    end
    fprintf('Channel: %s\n', vChannelNames{vChannelIndex});
else
    msgbox('No surfaces were created. Check your minimum object size threshold.');
end
 
end