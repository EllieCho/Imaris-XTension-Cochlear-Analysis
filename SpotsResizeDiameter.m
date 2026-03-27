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
% Resizes all spots in a spots object to a user-defined diameter
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
%       <Submenu name="Spots Functions">
%        <Item name="Resize Spots to Diameter" icon="Matlab">
%          <Command>MatlabXT::SpotsResizeDiameter(%i)</Command>
%        </Item>
%       </Submenu>
%      </Menu>
%      <SurpassTab>
%        <SurpassComponent name="bpSpots">
%          <Item name="Resize Spots to Diameter" icon="Matlab">
%            <Command>MatlabXT::SpotsResizeDiameter(%i)</Command>
%          </Item>
%        </SurpassComponent>
%      </SurpassTab>
%    </CustomTools>

function SpotsResizeDiameter(aImarisApplicationID)

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

% Add undo point
vImarisApplication.DataSetPushUndo('Resize Spots to Diameter');

% Get user parameters
prompt = {'New spot diameter (micrometres, 0 to skip):'};
dlgtitle = 'Resize Spots Parameters';
dims = [1 50];
definput = {'2000'};
answer = inputdlg(prompt, dlgtitle, dims, definput);

if isempty(answer)
    return;
end

newDiameter = str2double(answer{1});

if newDiameter <= 0
    msgbox('Diameter must be greater than 0!');
    return;
end

newRadius = newDiameter / 2;

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
vPositions = vSpots.GetPositionsXYZ;
vTimeIndices = vSpots.GetIndicesT;

numSpots = size(vPositions, 1);
newRadii = ones(numSpots, 1) * newRadius;

if numSpots < 1
    msgbox('No spots found!');
    return;
end


% Create new spots object
fprintf('Creating new spots object...\n');

vNewSpots = vFactory.CreateSpots;
vNewSpots.SetName(sprintf('%s_Resized_D%.1fum', char(vSpots.GetName), newDiameter));

% Apply new radii and write to Imaris
vNewSpots.Set(vPositions, vTimeIndices, newRadii);

% Copy colour from original spots
vOriginalColor = vSpots.GetColorRGBA;
vNewSpots.SetColorRGBA(vOriginalColor);

% Add to scene
vSurpassScene.AddChild(vNewSpots, -1);

end