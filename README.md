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
