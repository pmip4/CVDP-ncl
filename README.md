# CVDP
The Climate Variability Diagnostics Package (CVDP) developed by NCAR's Climate Analysis Section is an analysis tool that documents the major modes of climate variability in models and observations, including ENSO, Pacific Decadal Oscillation, Atlantic Multi-decadal Oscillation, Northern and Southern Annular Modes, North Atlantic Oscillation, Pacific North and South American teleconnection patterns. Time series, spatial patterns and power spectra are displayed graphically via webpages and saved as NetCDF files for later use. The package also computes climatological fields, standard deviation and trend maps; documentation is provided for all calculations.  The package can be applied to individual model simulations ("style 1") or to “initial condition” Large Ensembles (“style 2”).  Both styles provide quantitative metrics comparing models and observations; style 2 also includes ensemble mean (i.e., forced response) and ensemble spread (i.e., internal variability) diagnostics.  Several detrending options are provided, including linear, quadratic, 30-year high-pass filter and removal of the ensemble mean (in the case of Large Ensembles). The CVDP can be run on any set of model simulations (as long as the files meet CMIP output metadata requirements), allowing inter-model comparisons. Observational data sets and analysis periods are specified by the user. The CVDP Data Repository contains CVDP output for many CESM and CMIP model simulations. Two examples are linked below; many more examples are present on the <a href="https://www.cesm.ucar.edu/working_groups/CVC/cvdp/data-repository.html">CVDP Data Repository</a>. 

<a href="https://webext.cgd.ucar.edu/Multi-Case/CVDP_repository/cmip6.hist_ssp585_quadquad_1900-2100/">CMIP6 Historical/SSP585 Run Intercomparison 1900-2100</a><br>
<a href="https://webext.cgd.ucar.edu/Multi-Case/CVDP_repository/cesm2-lens_quadquad_1850-2100/">CESM2 Large Ensemble Intercomparison 1850-2100</a>

CVDP v6.0.0 combines the capabilities of previous versions of the CVDP with those of the <a href="https://github.com/NCAR/CVDP-LE">CVDP-LE</a>. Due to the merging of the capabilites of these two packages, the CVDP-LE is now deprecated.  

# Multi-model ensemble mode (style 3, UCL addition)
This fork adds a third run style for multi-model ensembles: multiple climate models each performing the same experiment (e.g. the PMIP midHolocene, lig127k or lgm experiments), with each model paired to its own control (e.g. piControl) simulation. All individual-simulation diagnostics and webpages are produced as in style 1. In addition, every 2D lat/lon diagnostic field is regridded to a common 1x1&deg; grid, per-model anomalies (experiment minus control) are formed, and multi-model means, cross-model standard deviations, sign-agreement fractions (for robustness stippling, e.g. at a two-thirds threshold) and per-gridpoint model counts are written to `<experiment group>_minus_<control group>.cvdp_mmm.nc`.

To use it, set `runstyle = 3` and `control_group_name` in driver.ncl, and give each namelist row a 5th column identifying its group (`<group number>-<experiment name>`, as in style 2 but with each group being an experiment rather than a single-model ensemble; group numbers are sequential starting at 1) and a 6th column giving the model name, which is used to pair each experiment simulation with its control:

```
CESM2_midHolocene        | /data/CESM2/midHolocene/        |    1 |  700 | 1-midHolocene | CESM2
IPSL-CM6A-LR_midHolocene | /data/IPSL-CM6A-LR/midHolocene/ | 1850 | 2399 | 1-midHolocene | IPSL-CM6A-LR
MRI-ESM2-0_midHolocene   | /data/MRI-ESM2-0/midHolocene/   | 1851 | 2050 | 1-midHolocene | MRI-ESM2-0
CESM2_piControl          | /data/CESM2/piControl/          |    1 | 1200 | 2-piControl   | CESM2
IPSL-CM6A-LR_piControl   | /data/IPSL-CM6A-LR/piControl/   | 1850 | 3049 | 2-piControl   | IPSL-CM6A-LR
MRI-ESM2-0_piControl     | /data/MRI-ESM2-0/piControl/     | 1850 | 2550 | 2-piControl   | MRI-ESM2-0
```

Design notes, the full list of file changes and a verification checklist are in [docs/runstyle3-design.md](docs/runstyle3-design.md).

Notes on style 3: simulations within a group may span differing numbers of years (unlike style 2, no truncation to a common span is applied); several experiment groups can be analysed against one control group in a single run (one `.cvdp_mmm.nc` file per experiment group); models lacking a control simulation are excluded from the multi-model statistics with a warning; the `rmEM`/`rmGMST_EM` detrending options are not available (members are on different grids). Sea-ice and other native-ocean-grid fields are included via curvilinear regridding, AMOC lat-depth fields via interpolation to a common 1&deg; x 100 m grid, and index/PC timeseries (Ni&ntilde;o3.4, NAO PCs, ...) contribute cross-model statistics of their amplitude (temporal standard deviation) change; power spectra and Hovm&ouml;ller fields are excluded. When `create_graphics = "True"`, 4-panel multi-model mean figures (with sign-agreement stippling) and an HTML index page (`<experiment group>_minus_<control group>.mmm.html`) are also produced. Set `mmm_write_individual = "True"` in driver.ncl to additionally store each model's regridded anomaly field in the output file.

# Getting Started
View the <a href="https://www.cesm.ucar.edu/projects/cvdp/documentation">CVDP documentation page</a> for details on how to run CVDP v6.0.0. 

# Input data
The CVDP can read in the following data types as input:
- CMIP6
- CMIP5
- CMIP3
- CSM, CCSM and CESM
- Observations with file names and data array names matching CMIP conventions.

# Getting help
If the <a href="https://www.cesm.ucar.edu/projects/cvdp/documentation">CVDP documentation page</a> and the <a href="https://www.cesm.ucar.edu/working_groups/CVC/cvdp/">CVDP Website</a> do not answer your query or if you have a bug report or suggestion, it is recommended that you <a href="https://github.com/NCAR/CVDP-ncl/issues">open an issue on Github</a>. 
