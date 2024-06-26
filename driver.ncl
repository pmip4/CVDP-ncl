;
; CVDP driver script. To run the CVDP at the command line type: ncl driver.ncl
; To run the CVDP at the command line, put it in background mode, and write the terminal output
; to a file named file.out, type: ncl driver.ncl >&! file.out &
; 
;============================================================================================
  outdir            = "/project/CVDP/"                     ; location of output files   (must end in a "/")
                                                           ; It is recommended that a new or empty directory be pointed to here 
                                                           ; as existing files in outdir can get removed.

  namelists_only       = "False"             ; Set to True to only create the variable namelists. Useful
                                             ; upon running the package for the first time to verify that the correct
                                             ; files are being selected by the package. (See files in namelist_byvar/ directory)
                                             ; Set to False to run the entire package. 
                                             
  obs                  = "False"              ; True = analyze and plot observations (specified in namelist_obs), False = do not
  scale_timeseries     = "False"              ; True = scale timeseries so that x-axis length is comparable across timeseries, False = do not
  output_data          = "True"              ; True = output selected calculated data to a netCDF file. Make sure .nc files from previous CVDP
                                             ;        runs are not in outdir or they will get added to or modified.  
  compute_modes_mon    = "True"              ; True = compute DJF, MAM, JJA, SON, Annual and Monthly Atmospheric Modes of Variability 
                                             ; False = do not compute the Monthly Atmospheric Modes of Variability  (saves computation time)                               
;- - - - - - - - - - - - - - - - - -   
  opt_climo         = "Full"                 ; Full  = remove climatology based on full record of each simulation,
                                             ; Custom = set climatological period using climo_syear (climatological start year) and climo_eyear (climatological end year) 

  if (opt_climo.eq."Custom") then            ; When climo_syear and climo_eyear are positive, remove the climatology/annual cycle based on these years.
     climo_syear    = -30                    ;   Both settings should be within the range of years of all specified model runs and observational datasets. 
     climo_eyear    = 0                    ; When climo_syear is negative, remove the climatology/annual cycle relative to the end of each model run
  end if                                     ;   or observational dataset. Example: climo_syear = -25, climo_eyear = 0 will result in the climatology
                                             ;   being removed from the last 26 years of each model run and observations. 
;- - - - - - - - - - - - - - - - - -   
  colormap          = 0               ; 0 = default colormaps, 1 = colormaps better for color blindness

  output_type       = "png"           ; png = create png files, ps = create postscript files as well as png files (for web viewing).  
  
  png_scale         = 1.5             ; Set the output .png size. Value between .1->5.  Any value > 1 (< 1) increases (decreases) png size. 
                                      ; When output_type = "png" a value of 1 will result in a png sized 1500 (H) x 1500 (W) before automatic cropping of white space
                                      ; When output_type = "ps"  a value of 1 will result in a png density setting of 144 before automatic cropping of white space
  webpage_title     = "Title goes here"          ; Set webpage title   
  
  tar_output        = "False"               ; True = tar up all output in outdir and remove individual files, False = do not                                      
                                            ; Note: ALL files in outdir will be tarred up and then removed from the outdir directory. 

;---Advanced Options----------------------------------------------------------------------                                             
  zp = "ncl_scripts/"    ; directory path of CVDP NCL scripts. (must end in a "/")
                         ; Examples: "ncl_scripts/" if all code is local, or on CGD or CISL systems: "~asphilli/CESM-diagnostics/CVDP/Release/v4.1.0/ncl_scripts/"
                         ; Regardless of this setting the following files should be in one directory: namelist, driver.ncl, and namelist_obs. 
                         ; If pointing to code in ~asphilli make sure the driver script version #s match between this script and the script in ~asphilli.
  
  ncl_exec = "ncl"       ; This can be changed to a different path if a different version of NCL needs to be used, such as "/different/path/to/bin/ncl"                           
                         
  run_style = "parallel" ; parallel = allow simple python-based parallelization to occur. X number of CVDP NCL scripts will be called at once. 
                         ;            X is set via max_num_tasks. Terminal output will be harder to follow.
                         ; serial = call CVDP NCL scripts serially.    

  max_num_tasks = 4      ; Set the number of CVDP NCL scripts that can be called at once. If greater than 1 the scripts will be called in parallel. (If unsure set to 3)     
  
  modular = "False"      ; True = Run only those CVDP scripts specified in modular_list.
                         ; False = Run all CVDP scripts (Default)

  modular_list = "pdo,aice.trends_timeseries,sst.indices"  ; When modular = "True" list the CVDP scripts that will be run. 
                                           ; Example: modular_list = "amoc,amo,pr.trends_timeseries"
                                           ; For a list of available scripts see complete_list at line 72. 

  machine_casesen = "CMIP_ONLY"  ; True = Your filesystem is case sensitive  (Default)
                             ; False = Your filesystem is case insensitive                                                          
;========END USER MODIFICATIONS===========================================================
  version = "5.2.0.PMIP"

  start=systemfunc("date")
  print("Starting: Climate Variability Diagnostics Package ("+start+")")

  complete_list = "psl.nam_nao,psl.pna_npo,tas.trends_timeseries,snd.trends,psl.trends,amo,pdo,sst.indices,pr.trends_timeseries,"+\
                   "psl.sam_psa,sst.mean_stddev,psl.mean_stddev,pr.mean_stddev,sst.trends_timeseries,amoc,tas.mean_stddev,"+\
                   "snd.mean_stddev,aice.mean_stddev,aice.trends_timeseries,ipo,iod,amm,atl3,pr.indices,tas.indices,monsoon"

  loadscript(zp+"functions.ncl")
  outfiles = (/"ts","trefht","psl","prect","snowdp","moc","maxnum","aice_nh","aice_sh"/)
  rm_obsfiles(outfiles)

  if (isfilepresent2(outdir+"metrics_orig.txt")) then    ; remove metrics_orig.txt file if present
     system("rm "+outdir+"metrics_orig.txt")
  end if

  if (opt_climo.eq."Custom") then
     if (climo_syear.ge.climo_eyear) then
        print("Specified custom climatology start year (climo_syear) cannot be greater than or equal to the specified end year (climo_eyear), exiting CVDP.")
        exit 
     end if
  else
     climo_syear = -999
     climo_eyear = -999
  end if

  if (.not.isfilepresent2(outdir)) then
     system("mkdir "+outdir)
  end if
  envvar_str = "   export OUTDIR="+outdir+";   export OBS="+obs+";   export SCALE_TIMESERIES="+scale_timeseries+";   "+\
         "export OUTPUT_DATA="+output_data+";   export VERSION="+version+";   export PNG_SCALE="+png_scale+";   "+\
         "export OPT_CLIMO="+opt_climo+";   export CLIMO_SYEAR="+climo_syear+";   export CLIMO_EYEAR="+climo_eyear+";   "+\
         "export COMPUTE_MODES_MON="+compute_modes_mon+";   export OUTPUT_TYPE="+output_type+";   export MACHINE="+machine_casesen+";   "+\
         "export COLORMAP="+colormap+";   export CVDP_SCRIPTS="+zp+";   export MAX_TASKS="+max_num_tasks+";"  
  ncl_exec = ncl_exec+" -n -Q" 

  system(envvar_str + " "+str_sub_str(ncl_exec," -Q","")+" "+zp+"namelist.ncl")     ; create variable namelists
  if (namelists_only.eq."True") then
     print("Variable namelists have been created. Examine files in namelist_byvar/ directory to verify CVDP file selection.")
     print("Finished: Climate Variability Diagnostics Package ("+systemfunc("date")+")")
     rm_obsfiles(outfiles)
     exit
  end if   
;------------------------------
; Call CVDP calculation scripts
;
  if (modular.eq."True") then
     cm_list = str_sub_str(modular_list," ","")   ; remove spaces if present
     cm_list = str_sub_str(cm_list,",",".ncl,")   ; add .ncl in to end of each script name
  else
     cm_list = str_sub_str(complete_list,",",".ncl,")   ; add .ncl in to end of each script name
  end if
  cm_list = cm_list+".ncl"                     ; add .ncl in to last script name

  if (run_style.eq."parallel") then
     cm_list = str_sub_str(cm_list,","," "+zp)
     system(envvar_str+" python "+zp+"runTasks.py "+zp+cm_list)
  else
     cm_list = str_sub_str(cm_list,","," "+ncl_exec+" "+zp)
     cm_list = str_sub_str(cm_list,".ncl",".ncl;")
     system(envvar_str+" "+ncl_exec+" "+zp+cm_list) 
  end if
;-------------------------------
; Finalize netCDF files, create metrics tables, and finalize images.

  if (output_data.eq."True") then     ; finalize output nc files   
     system(envvar_str + " "+ncl_exec+" "+zp+"ncfiles.append.ncl")
  end if 

  met_files = systemfunc("ls "+outdir+"metrics.*.txt  2> /dev/null")
  if (dimsizes(met_files).eq.9) then   ; if all 9 metrics text files are present, create metrics table(s)
     system("   export OUTDIR="+outdir+"; "+ncl_exec+" "+zp+"metrics.ncl")
  end if
      
  image_finalize(outdir,output_type,max_num_tasks,zp,toint(144*png_scale),start)    ; trim whitespace, convert to .png (if necessary) and apply watermarks to images
 
  system("cp "+zp+"cas-cvdp.png "+outdir)
  system("cp "+zp+"banner.png "+outdir)
  system("cp namelist_byvar/* "+outdir)
  system("cp namelist "+outdir)
  if (obs.eq."True") then
     system("cp namelist_obs "+outdir)
  end if
;-------------------------------
; Create webpages
  quote = str_get_dq()
  system("   export OUTDIR="+outdir+";   export VERSION="+version+";   export OUTPUT_DATA="+output_data+";   "+\
         "export OPT_CLIMO="+opt_climo+";   export CLIMO_SYEAR="+climo_syear+";   export CLIMO_EYEAR="+climo_eyear+";   "+\
         "export OBS="+obs+";   export CVDP_SCRIPTS="+zp+"; "+ncl_exec+" 'webtitle="+quote+webpage_title+quote+"' "+zp+"webpage.ncl")
  delete(quote)
;-------------------------------
; Create tar file
  if (tar_output.eq."True") then
     if (isfilepresent2(outdir+"cvdp.tar")) then
        system("rm "+outdir+"cvdp.tar")
     end if
     system("cd "+outdir+"; tar -cf cvdp.tar *")
     system("cd "+outdir+"; rm *.gif *.png *.ps *.txt *.html *.nc namelist*")
  end if
;-------------------------------
; Cleanup
  rm_obsfiles(outfiles)
  delete([/outfiles,outdir,obs,scale_timeseries,output_data,opt_climo,climo_syear,climo_eyear,\
           png_scale,webpage_title,compute_modes_mon,met_files/])

  print("Finished: Climate Variability Diagnostics Package ("+systemfunc("date")+")")
  
