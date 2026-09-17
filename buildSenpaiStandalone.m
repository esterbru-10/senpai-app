function result = buildSenpaiStandalone(options)
%buildSenpaiStandalone Build and optionally package the SENPAI desktop app.
%
% result = buildSenpaiStandalone
% result = buildSenpaiStandalone(Package=true,RuntimeDelivery="installer")
%
% Run this function with MATLAB R2025b and MATLAB Compiler on the target
% operating system. Windows and macOS artifacts must be built separately.

arguments
    options.Package (1,1) logical = true
    options.RuntimeDelivery (1,1) string {mustBeMember(options.RuntimeDelivery,["web","installer","none"])} = "web"
    options.Clean (1,1) logical = true
end

projectFolder = fileparts(mfilename('fullpath'));
entryPoint = fullfile(projectFolder,'runSenpaiApp.m');
licenseFile = fullfile(projectFolder,'SENPAI','LICENSE');
version = '1.0.0';

if ispc
    platformName = 'windows';
elseif ismac
    platformName = 'macos';
else
    error('SENPAI:UnsupportedBuildPlatform', ...
        'Only Windows and macOS standalone builds are configured.');
end

platformFolder = fullfile(projectFolder,'build',platformName);
applicationFolder = fullfile(platformFolder,'application');
installerFolder = fullfile(platformFolder,'installer');

if options.Clean
    removeBuildFolder(applicationFolder);
    removeBuildFolder(installerFolder);
end
if ~isfolder(platformFolder)
    mkdir(platformFolder);
end

buildOptions = compiler.build.StandaloneApplicationOptions(entryPoint, ...
    'AdditionalFiles',{licenseFile}, ...
    'AutoDetectDataFiles','on', ...
    'ExecutableName','SENPAI', ...
    'ExecutableVersion',[version '.0'], ...
    'OutputDir',applicationFolder, ...
    'SupportPackages','autodetect', ...
    'Verbose','on');

fprintf('Building SENPAI %s application in %s\n',platformName,applicationFolder);
if ispc
    result.Build = compiler.build.standaloneWindowsApplication(buildOptions);
else
    result.Build = compiler.build.standaloneApplication(buildOptions);
    signMacBundle(fullfile(applicationFolder,'SENPAI.app'));
end

result.Platform = platformName;
result.ApplicationFolder = applicationFolder;
result.InstallerFolder = '';

if options.Package
    installerName = sprintf('SENPAI-%s-%s-Installer',version,platformName);
    packageOptions = compiler.package.InstallerOptions(result.Build, ...
        'ApplicationName','SENPAI', ...
        'AuthorName','SENPAI contributors', ...
        'Description','Desktop application for neuronal segmentation and morphometry.', ...
        'InstallationNotes','MATLAB Runtime R2025b is required and is handled by this installer.', ...
        'InstallerName',installerName, ...
        'OutputDir',installerFolder, ...
        'RuntimeDelivery',char(options.RuntimeDelivery), ...
        'Summary','SENPAI neuronal segmentation', ...
        'Version',version, ...
        'Verbose','on');

    fprintf('Packaging SENPAI installer in %s\n',installerFolder);
    compiler.package.installer(result.Build,'Options',packageOptions);
    if ismac
        signMacBundle(fullfile(installerFolder,[installerName '.app']));
    end
    result.Package = true;
    result.InstallerFolder = installerFolder;
end

manifestPath = fullfile(platformFolder,'build-manifest.mat');
save(manifestPath,'result','version');
fprintf('Build manifest saved to %s\n',manifestPath);
end

function signMacBundle(bundlePath)
if ~isfolder(bundlePath)
    error('SENPAI:MissingMacBundle','macOS bundle was not created: %s',bundlePath);
end
quotedPath = ['"' strrep(bundlePath,'"','\"') '"'];
[status,output] = system(['codesign --force --deep --sign - ' quotedPath]);
if status ~= 0
    error('SENPAI:CodeSignFailed','Unable to sign %s:\n%s',bundlePath,output);
end
[status,output] = system(['codesign --verify --deep --strict ' quotedPath]);
if status ~= 0
    error('SENPAI:CodeSignVerificationFailed', ...
        'Signature verification failed for %s:\n%s',bundlePath,output);
end
end

function removeBuildFolder(folderPath)
if isfolder(folderPath)
    rmdir(folderPath,'s');
end
end
