function app = runSenpaiApp()
%runSenpaiApp Launch the SENPAI segmentation GUI.

projectFolder = fileparts(mfilename('fullpath'));
addpath(projectFolder);
addpath(fullfile(projectFolder,'SENPAI'));

app = SenpaiSegmentationApp();

if nargout == 0
    clear app
end
end
