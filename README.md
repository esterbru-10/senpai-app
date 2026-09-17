# senpai-app

MATLAB desktop app for running the SENPAI microscopy segmentation workflow on
3-D TIFF image stacks.

This repository packages a graphical interface around the SENPAI MATLAB
functions originally released at
[cauzzo-s5/SENPAI](https://github.com/cauzzo-s5/SENPAI). SENPAI is described in
the Nature Communications paper:

> Cauzzo, S., Bruno, E., Boulet, D. et al. A modular framework for multi-scale
> tissue imaging and neuronal segmentation. Nature Communications 15, 4102
> (2024). https://doi.org/10.1038/s41467-024-48146-y

The app is intended to make the SENPAI workflow easier to run from a single GUI:
load a 3-D microscopy TIFF stack, tune segmentation parameters, run segmentation
and parcellation, inspect results slice-by-slice, create or load soma markers,
export volumes, and compute morphology outputs such as SWC skeletons and
Strahler statistics.

## Features

- Load 3-D `.tif` / `.tiff` microscopy stacks.
- Preview raw data, threshold masks, segmentation overlays, binary
  segmentations, parcellations, and comparison overlays.
- Estimate the SENPAI `K` parameter on a representative crop.
- Estimate and preview a background threshold using several methods.
- Run SENPAI segmentation with progress feedback and cancel support.
- Save every new segmentation in a timestamped run folder.
- Save an `info.txt` file with the segmentation parameters used for each run.
- Load, click-mark, edit, and save soma masks (`somas.mat`).
- Run SENPAI parcellation (`senpai_separator`) in the current segmentation
  output folder.
- Open the SENPAI pruning GUI for marker-based parcellation correction.
- Skeletonize selected neuron labels and export SWC files.
- Compute Strahler-order statistics from the current skeleton.
- Compare two segmentation or parcellation volumes.
- Export segmentation and parcellation outputs as TIFF stacks.

## Repository Layout

```text
senpai-app/
|-- SenpaiSegmentationApp.m       # Main programmatic MATLAB GUI
|-- runSenpaiApp.m                # Launcher
|-- SENPAI/                       # SENPAI MATLAB functions and demo data
|-- README_APP.md                 # Short development notes
|-- STANDALONE_BUILD.md           # Standalone build notes
|-- buildSenpaiStandalone.m       # MATLAB Compiler build entry point
|-- build-macos.sh                # macOS build wrapper
`-- build-windows.ps1             # Windows build wrapper
```

## Requirements

To run from MATLAB source:

- MATLAB, tested during app development with R2025b.
- Image Processing Toolbox.
- Statistics and Machine Learning Toolbox.
- Parallel Computing Toolbox is optional, but useful when enabling parallel
  K-means in the GUI.

The original SENPAI toolbox was written and tested with MATLAB R2022b, Image
Processing Toolbox, and Statistics and Machine Learning Toolbox. See
[`SENPAI/README.md`](SENPAI/README.md) for the upstream notes.

To build standalone installers:

- MATLAB R2025b.
- MATLAB Compiler.
- Platform-specific build machine: build macOS artifacts on macOS and Windows
  artifacts on 64-bit Windows.

See [STANDALONE_BUILD.md](STANDALONE_BUILD.md) for packaging details.

## Quick Start

Clone the app repository and launch it from MATLAB:

```matlab
cd('/path/to/senpai-app')
runSenpaiApp
```

The launcher adds both the app folder and the bundled `SENPAI/` folder to the
MATLAB path.

## Basic Workflow

1. Click **Load TIFF** and select a 3-D microscopy `.tif` or `.tiff` stack.
2. In the **Segmentation** tab, set the SENPAI parameters:
   - `K`, or use **Estimate K**.
   - `Sigma`.
   - slab size.
   - background threshold, or use **Estimate Threshold**.
3. Click **Run Segmentation**.
4. Inspect the result in the viewer using **Raw**, **Overlay**,
   **Segmentation**, or **Threshold** view.
5. In the **Parcellation** tab, load or create a soma mask.
6. Click **Run SENPAI Separator** to create `senpai_separator.mat` in the same
   folder as the current `senpai_final.mat`.
7. Use **Open SENPAI Prune GUI** if additional pruning markers are needed.
8. Use the **Morphometry** tab to export SWC skeletons and Strahler statistics.
9. Use the **Export** tab to write segmentation or parcellation volumes as TIFF
   stacks.

## Inputs

The main input is a 3-D TIFF stack:

- One z-plane per TIFF page.
- 8-bit and 16-bit stacks are supported by the SENPAI routines.

Optional masks:

- `somas.mat`: logical 3-D mask marking soma regions. It can be loaded from a
  file or created in the app with **Mark Soma by Click**.
- `markers.mat`: logical 3-D mask used by the pruning workflow to add
  correction markers for parcellation.

Mask volumes must match the dimensions of the current image, segmentation, or
parcellation.

## Outputs

By default, outputs are written under `senpai_output/` next to the app when run
from MATLAB source. Each new segmentation creates a unique folder named from the
TIFF filename plus date and time, for example:

```text
senpai_output/
`-- sample_stack.tif_20260917_143012/
    |-- senpai_final.mat
    |-- info.txt
    |-- senpai_separator.mat
    |-- somas.mat
    |-- markers.mat
    |-- senpai_skeleton_label_1.mat
    |-- senpai_skeleton_label_1.swc
    `-- strahler_label_1.mat
```

When running as a deployed standalone app, the default output location is the
user-writable `Documents/SENPAI Output` folder. The **Output...** button can be
used to select a different output root.

## Notes on the App Workflow

- **New Analysis** clears the loaded TIFF and all in-memory results. It does not
  delete files already written to disk.
- The slice viewer supports keyboard navigation with the arrow keys and `<` /
  `>` buttons next to the slider.
- Parcellation is saved in the folder of the current segmentation, not in a
  separate run folder.
- The pruning GUI receives only pruning markers; soma masks are not plotted as
  pruning overlays.

## Upstream SENPAI Functions Used

The GUI wraps and coordinates the following SENPAI functions:

- `senpai_seg_core_v4` for topology-informed K-means segmentation.
- `senpai_estimateK` for estimating the K-means class count.
- `senpai_separator` for soma/marker-guided parcellation.
- `senpai_prune` for interactive parcellation correction markers.
- `senpai_skeletonize` for skeleton and SWC extraction.
- `senpai_strahlerord` for Strahler-order morphology statistics.

The app also uses `Findthresholdbackground.m` for background-threshold
estimation.

## Standalone Builds

Standalone installers can be built from MATLAB with MATLAB Compiler:

```matlab
buildSenpaiStandalone
```

Convenience wrappers are also provided:

```sh
./build-macos.sh
```

```powershell
.\build-windows.ps1
```

Build outputs are written under `build/`. See
[STANDALONE_BUILD.md](STANDALONE_BUILD.md) for runtime delivery, code signing,
and platform-specific details.

## Citation

If you use this app or the bundled SENPAI workflow in scientific work, please
cite the original SENPAI article:

```bibtex
@article{Cauzzo2024SENPAI,
  title = {A modular framework for multi-scale tissue imaging and neuronal segmentation},
  author = {Cauzzo, Simone and Bruno, Ester and Boulet, David and others},
  journal = {Nature Communications},
  volume = {15},
  pages = {4102},
  year = {2024},
  doi = {10.1038/s41467-024-48146-y}
}
```

Original code repository:
[https://github.com/cauzzo-s5/SENPAI](https://github.com/cauzzo-s5/SENPAI)

## License

The bundled SENPAI source code is distributed under the GNU General Public
License v3.0, as provided in [`SENPAI/LICENSE`](SENPAI/LICENSE). Because this app
bundles and adapts SENPAI code, distribute `senpai-app` with compatible license
terms and keep the upstream license file with the repository.

## Acknowledgements

This app builds on SENPAI, SEgmentation of Neurons using PArtial derivative
Information, developed for multi-scale neuronal segmentation in 3-D optical
microscopy images.
