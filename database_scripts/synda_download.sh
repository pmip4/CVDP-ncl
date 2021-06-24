#!/usr/bin/env bash
#This script runs a series of synda install commands. It needs to be run with sudo on the synda machine at UCL

models="BCC-CSM2-MR BCC-ESM1 IPSL-CM6A-LR CNRM-CM6-1 GFDL-CM4 GISS-E2-1-G IPSL-CM6A-LR CESM2 MIROC6 MRI-ESM2-0"
expts="piControl abrupt-4xCO2 1pctCO2 historical lgm midHolocene"

for mod in $models
do
  for expt in $expts
  do
    sudo synda install -y source_id=$mod experiment_id=$expt variable=ts,tas,psl,pr table_id=Amon
    sudo synda install -y source_id=$mod experiment_id=$expt variable=snd table_id=LImon
    sudo synda install -y source_id=$mod experiment_id=$expt variable=siconc table_id=SImon
  done
done
