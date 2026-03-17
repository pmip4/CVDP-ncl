#!/bin/bash

expt_names="piControl abrupt4xCO2 1pctCO2 historical lgm midHolocene lig127k lgm-cal-adj midHolocene-cal-adj lig127k-cal-adj past1000 rcp26 rcp85"
CVDP_DIR=`pwd`
ESGF_DIR="/data/CMIP/curated_ESGF_replica"
CVDP_OUTDIR="/data/aod/cvdp_pmip34/"

for expt in $expt_names
do
  #first set up some run scripts etc for the experiment
  OUTDIR=$CVDP_OUTDIR/output.$expt
  mkdir -p $OUTDIR
  cp driver.ncl $OUTDIR/$expt.driver.ncl
  sed -i "s:output/:$OUTDIR/:g" $OUTDIR/$expt.driver.ncl
  sed -i "s:ncl_scripts/:$CVDP_DIR/ncl_scripts/:g" $OUTDIR/$expt.driver.ncl
  sed -i "s:Title goes here:$expt:g" $OUTDIR/$expt.driver.ncl
  if [ $expt == "1pctCO2" ] #NOTE: OPTIONS FOR OTHER RUNS NEEDS TO BE SET AS WELL
  then
    sed -i 's:opt_climo = "Full":opt_climo = "Custom":g' $OUTDIR/$expt.driver.ncl
    sed -i "s:climo_syear = 1971:climo_syear = -30:g" $OUTDIR/$expt.driver.ncl
    sed -i "s:climo_eyear = 2000:climo_eyear = 0:g" $OUTDIR/$expt.driver.ncl
  fi  
  if [ $expt == "historical" ] #NOTE: OPTIONS FOR OTHER RUNS NEEDS TO BE SET AS WELL
  then
    sed -i 's:opt_climo = "Full":opt_climo = "Custom":g' $OUTDIR/$expt.driver.ncl
  fi  
  if [ $expt == "rcp85" ] #NOTE: OPTIONS FOR OTHER RUNS NEEDS TO BE SET AS WELL
  then
    sed -i 's:opt_climo = "Full":opt_climo = "Custom":g' $OUTDIR/$expt.driver.ncl
    sed -i "s:climo_syear = 1971:climo_syear = 2070:g" $OUTDIR/$expt.driver.ncl
    sed -i "s:climo_eyear = 2000:climo_eyear = 2099:g" $OUTDIR/$expt.driver.ncl
  fi  
  if [ $expt == "abrupt4xCO2" ] #NOTE: OPTIONS FOR OTHER RUNS NEEDS TO BE SET AS WELL
  then
    sed -i 's:opt_climo = "Full":opt_climo = "Custom":g' $OUTDIR/$expt.driver.ncl
    sed -i "s:climo_syear = 1971:climo_syear = -30:g" $OUTDIR/$expt.driver.ncl
    sed -i "s:climo_eyear = 2000:climo_eyear = 0:g" $OUTDIR/$expt.driver.ncl
  fi  

  rm -f $OUTDIR/namelist

  # And now start filling the namelist
  cd $ESGF_DIR
  datasets=`ls -d */$expt`
  for dataset in $datasets
  do
    model=`echo $dataset | cut -d/ -f 1`
    cd $ESGF_DIR/$dataset
    ncfiles=*.nc
    let start_yr=9999
    let end_yr=1
    for ncfile in $ncfiles
    do
      yr_str=${ncfile##*_}
      this_start_yr=`echo $yr_str | cut -c-4`
      this_end_yr=`echo ${yr_str##*-} | cut -c-4`
      if [ $this_start_yr -lt $start_yr ] ; then start_yr=$this_start_yr; fi
      if [ $this_end_yr -gt $end_yr ] ; then end_yr=$this_end_yr; fi
    done
    let length=$((10#$end_yr))-$((10#$start_yr))
    if [ $length -gt 10 ]; then
      handedit="$model+$expt"
      case $handedit in
        "FGOALS-g2+historical") #some files go 1850-2005, others 1900-2014     
       	  echo "$model $expt | $ESGF_DIR/$dataset/ | 1900 | 2005" >> $OUTDIR/namelist
          ;;
        *) #Default option
       	  echo "$model $expt | $ESGF_DIR/$dataset/ | $start_yr | $end_yr" >> $OUTDIR/namelist
          ;;
      esac    
    fi
  done
  cd $CVDP_DIR
done