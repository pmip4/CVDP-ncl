#!/bin/bash

expt_names="piControl abrupt4xCO2 1pctCO2 historical lgm midHolocene lig127k past1000 rcp26 rcp85"
CVDP_DIR=`pwd`
ESGF_DIR="/data/CMIP/curated_ESGF_replica"
CVDP_OUTDIR="/data/aod/cvdp_pmip34/"

cd $ESGF_DIR
gcms=`ls -d */ | cut -d/ -f1`
cd $CVDP_DIR

for gcm in $gcms
do
  echo Making namelists for $gcm 
  OUTDIR=$CVDP_OUTDIR/individual_gcms/$gcm
  mkdir -p $OUTDIR
  cp $CVDP_DIR/driver.ncl $OUTDIR/$gcm.driver.ncl
  sed -i "s:output/:$OUTDIR/:g" $OUTDIR/$gcm.driver.ncl
  sed -i "s:ncl_scripts/:$CVDP_DIR/ncl_scripts/:g" $OUTDIR/$gcm.driver.ncl
  sed -i "s:Title goes here:$gcm:g" $OUTDIR/$gcm.driver.ncl
  rm -f $OUTDIR/namelist
  

  # And now start filling the namelist
  for expt in $expt_names
  do
    if [ -d $ESGF_DIR/$gcm/$expt ]
    then
      cd $ESGF_DIR/$gcm/$expt
      ncfiles=`ls -d *.nc`
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
          if [ $this_start_yr -lt $start_yr ]; then start_yr=$this_start_yr; fi
          if [ $this_end_yr -gt $end_yr ]; then end_yr=$this_end_yr; fi
        fi
      done
      let length=$((10#$end_yr))-$((10#$start_yr))
      if [ $length -gt 10 ]; then
        handedit="$gcm+$expt"
        case $handedit in
          "FGOALS-g2+historical") #some files go 1850-2005, others 1900-2014     
       	    echo "$model $expt | $ESGF_DIR/$gcm/$expt/ | 1900 | 2005" >> $OUTDIR/namelist
            ;;
          *) #Default option
       	    echo "$model $expt | $ESGF_DIR/$gcm/$expt/ | $start_yr | $end_yr" >> $OUTDIR/namelist
            ;;
        esac    
      fi
    fi
  done
  cd $CVDP_DIR
done

echo " "
echo " "

cd $CVDP_OUTDIR/individual_gcms/
gcms=`ls -d */ | cut -d/ -f1`
for gcm in $gcms
do
  echo Launching CVDP on $gcm 
  cd $CVDP_OUTDIR/individual_gcms/$gcm
  ncl -n $gcm.driver.ncl >& out.log &
done
cd $CVDP_DIR
