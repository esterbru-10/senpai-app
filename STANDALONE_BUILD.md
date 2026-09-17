# SENPAI standalone builds

The build is intentionally performed on the target operating system:

- build the macOS application on macOS;
- build the Windows application on 64-bit Windows.

Both builders require MATLAB R2025b with MATLAB Compiler, Image Processing
Toolbox, Statistics and Machine Learning Toolbox, and Parallel Computing
Toolbox. End users need no MATLAB license.

## macOS

Run from Terminal:

```sh
./build-macos.sh
```

Artifacts are written to `build/macos/`. The installer uses RuntimeDelivery
`web`, so it downloads the free MATLAB Runtime R2025b when needed.
The build script applies and verifies an ad-hoc code signature. Public
distribution without Gatekeeper warnings additionally requires an Apple
Developer ID certificate and Apple notarization, which are not available in
this project.

## Windows

On a 64-bit Windows build machine, install the build products if necessary:

```powershell
.\install-windows-build-tools.ps1
```

This step needs a MATLAB license that includes MATLAB Compiler and displays a
Windows elevation prompt. If the products are already installed, skip it.
Then run:

```powershell
.\build-windows.ps1
```

Artifacts are written to `build/windows/`. The script uses
`compiler.build.standaloneWindowsApplication`, which creates a GUI application
without opening a command shell.

If MATLAB is installed elsewhere:

```powershell
.\build-windows.ps1 -MatlabPath "D:\MATLAB\R2025b\bin\matlab.exe"
```

To create an offline installer containing MATLAB Runtime (much larger), pass
`-RuntimeDelivery installer` on Windows or call
`buildSenpaiStandalone(Package=true,RuntimeDelivery="installer")` in MATLAB.

## Output location at runtime

In MATLAB, results continue to use the local `senpai_output` project folder.
In a deployed application, the default is the writable user folder
`Documents/SENPAI Output`. The toolbar can select a different output folder.
