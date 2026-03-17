#!/bin/bash

REPLICA_DIR="/gws/nopw/j04/ncas_generic/users/ucfaccb/virtual_ESGF_replica"

##CMIP5
#expt_names="piControl abrupt4xCO2 1pctCO2 historical lgm midHolocene past1000 rcp26 rcp85"
#model_names="bcc-csm1-1 CCSM4 CNRM-CM5 CSIRO-Mk3-6-0 CSIRO-Mk3L-1-2 EC-EARTH-2-2 FGOALS-g2 FGOALS-s2 GISS-E2-R HadCM3 HadGEM2-CC HadGEM2-ES IPSL-CM5A-LR KCM1-2-2 MIROC-ESM MPI-ESM-P MRI-CGCM3 MRI-ESM2-0"

#for gcm in $model_names
#do
#  mkdir -p $REPLICA_DIR/$gcm
#  for expt in $expt_names
#  do
#    this_esgf="/badc/cmip5/data/cmip5/output?/*/$gcm/$expt"
#    #this_esgf="/badc/cmip5/data/pmip3/output/*/$gcm/$expt"
#    if [ -d $this_esgf ]; then
#      this_virtual=$REPLICA_DIR/$gcm/$expt
#      mkdir -p $this_virtual
#      cd $this_esgf
#      datafiles=`ls mon/{atmos,landIce,ocean,seaIce}/{Amon,LImon,Omon,OImon}/r1i1p1/latest/{ts/,tas/,psl/,pr/,snd/,msftmyz/,sic/,}{tas_Amon*nc,ts_Amon*nc,pr_Amon*nc,psl_Amon*nc,snd_LImon*nc,msftmyz_Omon*nc,sic_OImon*nc}`
#      cd $this_virtual
#      for fil in $datafiles
#      do
#        ln -s $this_esgf/$fil ${fil##*/} 
#      done
#    fi 
#  done
#done

#CMIP6
CMIP_expt_names="piControl abrupt-4xCO2 1pctCO2 historical"
PMIP_expt_names="lgm midHolocene lig127k past1000"
ScenarioMIP_expt_names="ssp126 ssp585"
model_names="CESM2 GISS-E2-1-G IPSL-CM6A-LR"
datadirs="r1i1p1f1/Amon/ts/gr r1i1p1f1/Amon/tas/gr r1i1p1f1/Amon/psl/gr r1i1p1f1/Amon/pr/gr r1i1p1f1/LImon/snd/gr r1i1p1f1/Omon/msftmyz/gr r1i1p1f1/OImon/siconc/gr r1i1p1f1/Amon/ts/gn r1i1p1f1/Amon/tas/gn r1i1p1f1/Amon/psl/gn r1i1p1f1/Amon/pr/gn r1i1p1f1/LImon/snd/gn r1i1p1f1/Omon/msftmyz/gn r1i1p1f1/OImon/siconc/gn"


for gcm in $model_names
do
  mkdir -p $REPLICA_DIR/$gcm
  for expt in $CMIP_expt_names
  do
    this_CMIP="/badc/cmip6/data/CMIP6/CMIP/*/$gcm/$expt"
    if [ -d $this_CMIP ]; then
      this_virtual=$REPLICA_DIR/$gcm/$expt
      mkdir -p $this_virtual
      cd $this_CMIP
      for datadir in $datadirs
      do 
        if [ -d $datadir ]; then
          cd $datadir
          datafiles=`ls -l latest/*.nc | cut -d\> -f 2 | sed 's:../files:files:g'`
          cd $this_virtual
          for fil in $datafiles
          do
            ln -s $this_CMIP/$datadir/$fil ${fil##*/} 
          done
        fi
        cd $this_CMIP
      done 
    fi 
  done
done

for gcm in $model_names
do
  for expt in $PMIP_expt_names
  do
    this_PMIP="/badc/cmip6/data/CMIP6/PMIP/*/$gcm/$expt"
    if [ -d $this_PMIP ]; then
      this_virtual=$REPLICA_DIR/$gcm/$expt
      mkdir -p $this_virtual
      cd $this_PMIP
      for datadir in $datadirs
      do 
        if [ -d $datadir ]; then
          cd $datadir
          datafiles=`ls -l latest/*.nc | cut -d\> -f 2 | sed 's:../files:files:g'`
          cd $this_virtual
          for fil in $datafiles
          do
            ln -s $this_PMIP/$datadir/$fil ${fil##*/} 
          done
        fi
      cd $this_PMIP
      done 
    fi 
  done
done

for gcm in $model_names
do
  for expt in $ScenarioMIP_expt_names
  do
    this_ScenarioMIP="/badc/cmip6/data/CMIP6/ScenarioMIP/*/$gcm/$expt"
    if [ -d $this_ScenarioMIP ]; then
      this_virtual=$REPLICA_DIR/$gcm/$expt
      mkdir -p $this_virtual
      cd $this_ScenarioMIP
      for datadir in $datadirs
      do 
        if [ -d $datadir ]; then
          cd $datadir
          datafiles=`ls -l latest/*.nc | cut -d\> -f 2 | sed 's:../files:files:g'`
          cd $this_virtual
          for fil in $datafiles
          do
            ln -s $this_ScenarioMIP/$datadir/$fil ${fil##*/} 
          done
        fi
      cd $this_ScenarioMIP
      done 
    fi 
  done
done

#PMIP3
expt_names="piControl past1000"
gcm="HadCM3"

mkdir -p $REPLICA_DIR/$gcm
for expt in $expt_names
do
  this_esgf="/badc/cmip5/data/pmip3/output/UOED/$gcm/$expt"
  if [ -d $this_esgf ]; then
    this_virtual=$REPLICA_DIR/$gcm/$expt
    mkdir -p $this_virtual
    cd $this_esgf
    datafiles=`ls mon/{atmos,landIce,ocean,seaIce}/{Amon,LImon,Omon,OImon}/r1i1p1/files/{ts_*/,tas_*/,psl_*/,pr_*/,snd_*/,msftmyz_*/,sic_*/,}{tas_Amon*nc,ts_Amon*nc,pr_Amon*nc,psl_Amon*nc,snd_LImon*nc,msftmyz_Omon*nc,sic_OImon*nc}`
    cd $this_virtual
    for fil in $datafiles
    do
      ln -s $this_esgf/$fil ${fil##*/} 
    done
  fi 
done


# TO BE RUN ON THE UCL SERVER, AS CEDA DOES NOT HAVE PMIP3 REPLICATE
#PMIP3
#CURATED_DIR="/data/CMIP/curated_ESGF_replica"
#expt_names="piControl abrupt4xCO2 1pctCO2 historical lgm midHolocene past1000 rcp26 rcp85"
#model_names="COSMOS-ASO CSIRO-Mk3L-1-2 EC-EARTH-2-2 HadCM3 KCM1-2-2"
#
#for gcm in $model_names
#do
#  mkdir -p $REPLICA_DIR/$gcm
#  for expt in $expt_names
#  do
#    this_esgf="/data/CMIP/pmip3/output/*/$gcm/$expt"
#    if [ -d $this_esgf ]; then
#      this_virtual=$CURATED_DIR/$gcm/$expt
#      mkdir -p $this_virtual
#      cd $this_esgf
#      datafiles=`ls mon/{atmos,landIce,ocean,seaIce}/{Amon,LImon,Omon,OImon}/r1i1p1/*/{ts/,tas/,psl/,pr/,snd/,msftmyz/,sic/,}{tas_Amon*nc,ts_Amon*nc,pr_Amon*nc,psl_Amon*nc,snd_LImon*nc,msftmyz_Omon*nc,sic_OImon*nc}`
#      cd $this_virtual
#      for fil in $datafiles
#      do
#        ln -s $this_esgf/$fil ${fil##*/} 
#      done
#    fi 
#  done
#done
