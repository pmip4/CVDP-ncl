#!/bin/bash

CVDP_DIR=`pwd`
ESGF_DIR="/data/CMIP/curated_ESGF_replica"
gcm_names=`ls -I README  -I ACCESS-ESM1-5 $ESGF_DIR | sort | uniq`
var_names="pr tas psl ts"
expt_names="piControl abrupt4xCO2 1pctCO2 lgm lgm-cal-adj midHolocene midHolocene-cal-adj lig127k lig127k-cal-adj"

for gcm in $gcm_names
do 
  cd $ESGF_DIR/$gcm
  #expt_names=`ls -d *`
  for expt in $expt_names
  do
    if [ -d $ESGF_DIR/$gcm/$expt ]; then
      chmod 755 $expt #make run directory writable
      mkdir -p $expt/preprocessed
      cd $expt
      for var in $var_names
      do
        ncfiles=$var\_Amon*.nc
        let start_yr=9999
        let end_yr=1
        for ncfile in $ncfiles
        do
          if [ $ncfile == "*.nc" ]; then
            start_yr=1
          else
            yr_str=${ncfile##*_}
            this_start_yr=`echo $yr_str | cut -c-4`
            this_end_yr=`echo ${yr_str##*-} | cut -c-4`
            if [ $this_start_yr -lt $start_yr ] ; then start_yr=$this_start_yr; fi
            if [ $this_end_yr -gt $end_yr ] ; then end_yr=$this_end_yr; fi
          fi
        done
        if [ $start_yr != $end_yr ]; then #not missing files
          let length=$((10#$end_yr))-$((10#$start_yr))+1
          let end_index=12*$length-1
          let start_index=$end_index-599
          ncrcat -O -d time,$start_index,$end_index $ncfiles preprocessed/$var\_Amon_$gcm\_$expt\_preprocessed_final50yrs.nc
          ncl -Q -n filename=\"$ESGF_DIR/$gcm/$expt/preprocessed/$var\_Amon_$gcm\_$expt\_preprocessed_final50yrs.nc\" varname=\"$var\" $CVDP_DIR/anomalise_detrend_ncfile.ncl
        fi
      done
      cd $ESGF_DIR/$gcm
      chmod 555 $expt
    fi
  done
done
