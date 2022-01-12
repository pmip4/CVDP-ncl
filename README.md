# CVDP-ncl
This repository provides the palaeoclimate variant of the Climate Variability Diagnostics Package (CVDP). 

This was developed by NCAR's Climate Analysis Section and is an analysis tool that documents the major modes of climate variability in models and observations. Variations to it have been made by Chris Brierley. These consist of:

- Addition of a `database_scripts` directory containing some scripts to curate ESGF replicas and to then create namelists from them
- Changes in the ENSO compositing
- Altering the computation period of the mean and standard deviations to only consider the custom climatological period (if set)
- New processing scripts for the
  *  Atlantic Meridional Mode
  *  Atlantic Nino Mode (ATL3)
  *  Global Monsoon Domain
  *  IPCC AR5 regional averages
- Expansion of the IOD mode to provide greater regression patterns
- Alterations in the webpage to accomodate these changes

# CVDP (Original Documentation)
The Climate Variability Diagnostics Package (CVDP) developed by NCAR's Climate Analysis Section is an analysis tool that documents the major modes of climate variability in models and observations, including ENSO, Pacific Decadal Oscillation, Atlantic Multi-decadal Oscillation, Northern and Southern Annular Modes, North Atlantic Oscillation, Pacific North and South American teleconnection patterns. Time series, spatial patterns and power spectra are displayed graphically via webpages and saved as NetCDF files for later use. The package also computes climatological fields, standard deviation and trend maps; documentation is provided for all calculations.  The CVDP can be run on any set of model simulations (as long as the files meet CMIP5 or CMIP6 output metadata requirements), allowing inter-model comparisons. Observational data sets and analysis periods are specified by the user. The CVDP Data Repository contains CVDP output for most CMIP3 and CMIP5 model simulations. Two examples are linked below; many more examples are present on the <a href="https://www.cesm.ucar.edu/working_groups/CVC/cvdp/data-repository.html">CVDP Data Repository</a>. 

<a href="http://webext.cgd.ucar.edu/Multi-Case/CVDP_repository/cmip6.hist_ssp585/">CMIP6 Historical/SSP585 Run Intercomparison 1900-2100</a><br>
<a href="http://webext.cgd.ucar.edu/Multi-Case/CVDP_repository/cesm1.lens_1920-2018/">CESM1 Large Ensemble Intercomparison 1920-2018</a>

The CVDP is the predecessor to the <a href="https://github.com/NCAR/CVDP-LE">CVDP-LE</a>, a similar tool that explores internal and forced contributions to climate variability and change in coupled model “initial-condition” Large Ensembles and observations. Note that while many of the individual simulation metrics are similar between the CVDP and CVDP-LE, the CVDP-LE has more of a focus on ensemble metrics. For example, the CVDP-LE calculates the ensemble-mean (i.e., forced response) and ensemble-spread (i.e., internal variability) of each model, as well as quantitative metrics comparing the models to observations. 

# Getting Started
View the <a href="https://github.com/NCAR/CVDP-ncl/blob/master/CVDP_readme.pdf">readme file</a> for details on how to run the CVDP. 

# Input data
The CVDP can read in the following data types as input:
- CMIP6
- CMIP5
- CMIP3
- CSM, CCSM and CESM
- Observations with file names and data array names matching CMIP conventions.

# Getting help
If the <a href="https://github.com/NCAR/CVDP-ncl/blob/master/CVDP_readme.pdf">readme file</a> and the <a href="https://www.cesm.ucar.edu/working_groups/CVC/cvdp/">CVDP Website</a> do not answer your query or if you have a bug report or suggestion, it is recommended that you <a href="https://github.com/NCAR/CVDP-ncl/issues">open an issue on Github</a>. 
