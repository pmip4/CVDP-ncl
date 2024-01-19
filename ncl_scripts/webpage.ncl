; Create the index.html, methodology.html, and metrics.html web pages.
;
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_code.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/gsn_csm.ncl"
load "$NCARG_ROOT/lib/ncarg/nclscripts/csm/contributed.ncl"
load "$CVDP_SCRIPTS/functions.ncl"

begin
  print("Starting: webpage.ncl")

  OUTDIR      = getenv("OUTDIR") 
  VERSION     = getenv("VERSION")
  OT          = getenv("OUTPUT_DATA")
  OPT_CLIMO   = getenv("OPT_CLIMO")
  CLIMO_SYEAR = getenv("CLIMO_SYEAR")
  CLIMO_EYEAR = getenv("CLIMO_EYEAR")
  OBS         = getenv("OBS")

  quote = str_get_dq()
  
  if (OPT_CLIMO.eq."Full") then
     subtxt = "Climatological Period Used: Full"
  end if
  if (OPT_CLIMO.eq."Custom") then
     if (toint(CLIMO_SYEAR).lt.0) then
        subtxt = "Climo. Period (relative to record end): "+CLIMO_SYEAR+"-"+CLIMO_EYEAR
     else
        subtxt = "Climatological Period Used: "+CLIMO_SYEAR+"-"+CLIMO_EYEAR
     end if
  end if

  nsim_noobs = numAsciiRow("namelist")
  na = asciiread("namelist",(/nsim_noobs/),"string")
  names = new(nsim_noobs,"string")
  delim = "|"
  do gg = 0,nsim_noobs-1
     names(gg) = str_strip(str_get_field(na(gg),1,delim))
  end do
;  print(names)
  
  txt = new(50,"string")
  quote = str_get_dq()
  table_top_txt = "<div class="+quote+"row"+quote+"><div class="+quote+"col"+quote+"> <table class="+quote+"table table-striped table-bordered"+quote+">"
  table_bottom_txt = "</table></div></div>"  
  
  txt(0) = "<html><head><title>Climate Variability Diagnostics Package</title>"
  txt(1) = "<link rel="+quote+"stylesheet"+quote+" href="+quote+"https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/css/bootstrap.min.css"+quote+" integrity="+quote+"sha384-MCw98/SFnGE8fJT3GXwEOngsV7Zt27NXFoaoApmYm81iuXoPkFOJwJ8ERdknLPMO"+quote+" crossorigin="+quote+"anonymous"+quote+">"
  txt(2) = "<script src="+quote+"https://code.jquery.com/jquery-3.3.1.slim.min.js"+quote+" integrity="+quote+"sha384-q8i/X+965DzO0rT7abK41JStQIAqVgRVzpbzo5smXKp4YfRvH+8abtTE1Pi6jizo"+quote+" crossorigin="+quote+"anonymous"+quote+"></script>"
  txt(3) = "<script src="+quote+"https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.14.3/umd/popper.min.js"+quote+" integrity="+quote+"sha384-ZMP7rVo3mIykV+2+9J3UJ46jBk0WLaUAdn689aCwoqbBJiSnjAK/l8WvCWPIPm49"+quote+" crossorigin="+quote+"anonymous"+quote+"></script>"
  txt(4) = "<script src="+quote+"https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/js/bootstrap.min.js"+quote+" integrity="+quote+"sha384-ChfqqxuZUCnJSK3+MXmPNIyE6ZbWh2IMqE241rYiqJxyMiZ6OW/JmZQ5stwEULTy"+quote+" crossorigin="+quote+"anonymous"+quote+"></script>"
  txt(5) = "<style>body {background-color: WhiteSmoke; font-family: Verdana, Geneva, sans-serif}"
  txt(6) = "img.title {width:990; height:105; align:left}"
  txt(7) = "p.subtitle {font-size:20pt; color:black; text-align:center; font-weight:bold}"
  txt(8) = "p.btext {font-size:11pt; text-align:left}"
  txt(9) = "font.s1 {font-size:13.5pt; text-align:left}"
  txt(10) = "td {text-align:center; font-size:12pt}"
  txt(11) = "td.s1 {text-align:left; font-size:11pt}"
  txt(12) = "td.s2 {border-bottom: 4px double darkgray}"
  txt(13) = "CAPTION {text-align:left; font-size:14pt; font-weight:bold}"
  txt(14) = "</style></head>"

  txt(15) = "<body><div class="+quote+"container"+quote+">"
	 txt(16) = "<div class="+quote+"row"+quote+">"
		txt(17) = "<a href="+quote+"http://www2.geog.ucl.ac.uk/~p2f-v/PMIPVarData/"+quote+"><img class="+quote+"img-fluid"+quote+" src="+quote+"banner.png"+quote+" alt="+quote+"PMIP, UCL and NCAR banners"+quote+"></a>"
  txt(18) = "</div>"

  txt(19) = "<div class="+quote+"row"+quote+"><div class="+quote+"col"+quote+"><table class="+quote+"table my-0"+quote+">"
		txt(20) = "<tr><td class="+quote+"text-left"+quote+"><ul class="+quote+"list-inline my-0"+quote+"><li class="+quote+"list-inline-item"+quote+"><font class=s1><a href="+quote+"http://www2.geog.ucl.ac.uk/~p2f-v/PMIPVarData/"+quote+">Return to PMIPVarData home</a> <br><a href="+quote+"methodology.html"+quote+">Methodology and Definitions</a></font></li><br>"
  if (isfilepresent2(OUTDIR+"metrics.txt")) then
     if (isfilepresent2(OUTDIR+"metrics.table_1.gif")) then
        txt(21) = "<li class="+quote+"list-inline-item"+quote+">Metrics Tables: <a href="+quote+"metrics.table_0.html"+quote+">Pattern Correlations</a> | <a href="+quote+"metrics.table_14.html"+quote+">RMS</a></li><br>"
     else
        txt(21) = "<li class="+quote+"list-inline-item"+quote+"><a href="+quote+"metrics.html"+quote+">Metrics Table</a></li><br>"
     end if
  end if

  if (OBS.eq."True") then
     txt(22) = "<li class="+quote+"list-inline-item"+quote+">Namelists: <a href="+quote+"namelist_obs.html"+quote+">Input</a> | <a href="+quote+"namelist_msftmz.html"+quote+">Derived</a></li><br>"
  else
     txt(22) = "<li class="+quote+"list-inline-item"+quote+">Namelists: <a href="+quote+"namelist_models.html"+quote+">Input</a> | <a href="+quote+"namelist_msftmz.html"+quote+">Derived</a></li><br>"
  end if

  txt(23) = "<li class="+quote+"list-inline-item"+quote+">"+subtxt+"</li><br><li class="+quote+"list-inline-item"+quote+">Created: "+systemfunc("date")+"</li><br><li class="+quote+"list-inline-item"+quote+">CVDP Version "+VERSION+"</li></ul></td>"

  txt(24) = "<td><p class=subtitle>"+webtitle+"</p></td></tr></table></div></div>"
  delete([/subtxt/])
  
  ;Write the header at the top of the page to index.html
  header_txt=[/txt(ind(.not.ismissing(txt)))/]
  write_table(OUTDIR+"index.html","w",header_txt,"%s")
  delete([/header_txt,txt/])

  ;Populate the Means table
  txt = new(50,"string")
  txt(0) = table_top_txt
  txt(2) = "<h3 class="+quote+"display-6"+quote+">Means</h3>"
  txt(3) = "<tr><td><b>SST</b></td><td>"+table_link_setup(OUTDIR,"sst.mean.djf.png","DJF")+"</td><td>"+table_link_setup(OUTDIR,"sst.mean.mam.png","MAM")+"</td><td>"+table_link_setup(OUTDIR,"sst.mean.jja.png","JJA")+"</td><td>"+table_link_setup(OUTDIR,"sst.mean.son.png","SON")+"</td><td>"+table_link_setup(OUTDIR,"sst.mean.ann.png","Annual")+"</td></tr>"    
  txt(4) = "<tr><td><b>TAS</b></td><td>"+table_link_setup(OUTDIR,"tas.mean.djf.png","DJF")+"</td><td>"+table_link_setup(OUTDIR,"tas.mean.mam.png","MAM")+"</td><td>"+table_link_setup(OUTDIR,"tas.mean.jja.png","JJA")+"</td><td>"+table_link_setup(OUTDIR,"tas.mean.son.png","SON")+"</td><td>"+table_link_setup(OUTDIR,"tas.mean.ann.png","Annual")+"</td></tr>"    
  txt(5) = "<tr><td><b>PSL</b></td><td>"+table_link_setup(OUTDIR,"psl.mean.djf.png","DJF")+"</td><td>"+table_link_setup(OUTDIR,"psl.mean.mam.png","MAM")+"</td><td>"+table_link_setup(OUTDIR,"psl.mean.jja.png","JJA")+"</td><td>"+table_link_setup(OUTDIR,"psl.mean.son.png","SON")+"</td><td>"+table_link_setup(OUTDIR,"psl.mean.ann.png","Annual")+"</td></tr>"    
  txt(6) = "<tr><td><b>PR</b></td><td>"+table_link_setup(OUTDIR,"pr.mean.djf.png","DJF")+"</td><td>"+table_link_setup(OUTDIR,"pr.mean.mam.png","MAM")+"</td><td>"+table_link_setup(OUTDIR,"pr.mean.jja.png","JJA")+"</td><td>"+table_link_setup(OUTDIR,"pr.mean.son.png","SON")+"</td><td>"+table_link_setup(OUTDIR,"pr.mean.ann.png","Annual")+"</td></tr>"    
  txt(7) = "<tr><td><b>[PR]</b></td><td>"+table_link_setup(OUTDIR,"pr.za.djf.png","DJF")+"</td><td>"+table_link_setup(OUTDIR,"pr.za.mam.png","MAM")+"</td><td>"+table_link_setup(OUTDIR,"pr.za.jja.png","JJA")+"</td><td>"+table_link_setup(OUTDIR,"pr.za.son.png","SON")+"</td><td>"+table_link_setup(OUTDIR,"pr.za.ann.png","Annual")+"</td></tr>"
  txt(8) = "<tr><td><b>SND</b></td><td>"+table_link_setup(OUTDIR,"snd.mean.djf.png","DJF")+"</td><td>"+table_link_setup(OUTDIR,"snd.mean.mam.png","MAM")+"</td><td>"+table_link_setup(OUTDIR,"snd.mean.jja.png","JJA")+"</td><td>"+table_link_setup(OUTDIR,"snd.mean.son.png","SON")+"</td><td>"+table_link_setup(OUTDIR,"snd.mean.ann.png","Annual")+"</td></tr>"      
  txt(9) = "<tr><td><b>SIC NH</b></td><td>"+table_link_setup(OUTDIR,"aice.mean.nh.djf.png","DJF")+"</td><td>"+table_link_setup(OUTDIR,"aice.mean.nh.mam.png","MAM")+"</td><td>"+table_link_setup(OUTDIR,"aice.mean.nh.jja.png","JJA")+"</td><td>"+table_link_setup(OUTDIR,"aice.mean.nh.son.png","SON")+"</td><td>"+table_link_setup(OUTDIR,"aice.mean.nh.ann.png","Annual")+"</td></tr>"      
  txt(10) = "<tr><td><b>SIC SH</b></td><td>"+table_link_setup(OUTDIR,"aice.mean.sh.djf.png","DJF")+"</td><td>"+table_link_setup(OUTDIR,"aice.mean.sh.mam.png","MAM")+"</td><td>"+table_link_setup(OUTDIR,"aice.mean.sh.jja.png","JJA")+"</td><td>"+table_link_setup(OUTDIR,"aice.mean.sh.son.png","SON")+"</td><td>"+table_link_setup(OUTDIR,"aice.mean.sh.ann.png","Annual")+"</td></tr>"      
  txt(48)=table_bottom_txt
  txt(49)=""
  ;Write out the means table
  mns_txt=[/txt(ind(.not.ismissing(txt)))/]
  write_table(OUTDIR+"index.html","a",mns_txt,"%s")
  delete([/mns_txt,txt/])

  ;Populate the stddev table
  txt = new(50,"string")
  txt(0) = table_top_txt
  txt(1) = "<h3 class="+quote+"display-6"+quote+">Standard Deviations</h3>"
  txt(2) = "<tr><td><b>SST</b></td><td>"+table_link_setup(OUTDIR,"sst.stddev.djf.png","DJF")+"</td><td>"+table_link_setup(OUTDIR,"sst.stddev.mam.png","MAM")+"</td><td>"+table_link_setup(OUTDIR,"sst.stddev.jja.png","JJA")+"</td><td>"+table_link_setup(OUTDIR,"sst.stddev.son.png","SON")+"</td><td>"+table_link_setup(OUTDIR,"sst.stddev.ann.png","Annual")+"</td></tr>"    
  txt(3) = "<tr><td><b>TAS</b></td><td>"+table_link_setup(OUTDIR,"tas.stddev.djf.png","DJF")+"</td><td>"+table_link_setup(OUTDIR,"tas.stddev.mam.png","MAM")+"</td><td>"+table_link_setup(OUTDIR,"tas.stddev.jja.png","JJA")+"</td><td>"+table_link_setup(OUTDIR,"tas.stddev.son.png","SON")+"</td><td>"+table_link_setup(OUTDIR,"tas.stddev.ann.png","Annual")+"</td></tr>"    
  txt(4) = "<tr><td><b>PSL</b></td><td>"+table_link_setup(OUTDIR,"psl.stddev.djf.png","DJF")+"</td><td>"+table_link_setup(OUTDIR,"psl.stddev.mam.png","MAM")+"</td><td>"+table_link_setup(OUTDIR,"psl.stddev.jja.png","JJA")+"</td><td>"+table_link_setup(OUTDIR,"psl.stddev.son.png","SON")+"</td><td>"+table_link_setup(OUTDIR,"psl.stddev.ann.png","Annual")+"</td></tr>"    
  txt(5) = "<tr><td><b>PR</b></td><td>"+table_link_setup(OUTDIR,"pr.stddev.djf.png","DJF")+"</td><td>"+table_link_setup(OUTDIR,"pr.stddev.mam.png","MAM")+"</td><td>"+table_link_setup(OUTDIR,"pr.stddev.jja.png","JJA")+"</td><td>"+table_link_setup(OUTDIR,"pr.stddev.son.png","SON")+"</td><td>"+table_link_setup(OUTDIR,"pr.stddev.ann.png","Annual")+"</td></tr>"    
  txt(6) = "<tr><td><b>SND</b></td><td>"+table_link_setup(OUTDIR,"snd.stddev.djf.png","DJF")+"</td><td>"+table_link_setup(OUTDIR,"snd.stddev.mam.png","MAM")+"</td><td>"+table_link_setup(OUTDIR,"snd.stddev.jja.png","JJA")+"</td><td>"+table_link_setup(OUTDIR,"snd.stddev.son.png","SON")+"</td><td>"+table_link_setup(OUTDIR,"snd.stddev.ann.png","Annual")+"</td></tr>"    
  txt(7) = "<tr><td><b>SIC NH</b></td><td>"+table_link_setup(OUTDIR,"aice.stddev.nh.djf.png","DJF")+"</td><td>"+table_link_setup(OUTDIR,"aice.stddev.nh.mam.png","MAM")+"</td><td>"+table_link_setup(OUTDIR,"aice.stddev.nh.jja.png","JJA")+"</td><td>"+table_link_setup(OUTDIR,"aice.stddev.nh.son.png","SON")+"</td><td>"+table_link_setup(OUTDIR,"aice.stddev.nh.ann.png","Annual")+"</td></tr>"      
  txt(8) = "<tr><td><b>SIC SH</b></td><td>"+table_link_setup(OUTDIR,"aice.stddev.sh.djf.png","DJF")+"</td><td>"+table_link_setup(OUTDIR,"aice.stddev.sh.mam.png","MAM")+"</td><td>"+table_link_setup(OUTDIR,"aice.stddev.sh.jja.png","JJA")+"</td><td>"+table_link_setup(OUTDIR,"aice.stddev.sh.son.png","SON")+"</td><td>"+table_link_setup(OUTDIR,"aice.stddev.sh.ann.png","Annual")+"</td></tr>"      
  txt(48)=table_bottom_txt
  txt(49)=""
  ;Write out the stddev table
  stddev_txt=[/txt(ind(.not.ismissing(txt)))/]
  write_table(OUTDIR+"index.html","a",stddev_txt,"%s")
  delete([/stddev_txt,txt/])

  txt = new(60,"string")
  txt(0) = table_top_txt
  txt(1) = "<h3 class="+quote+"display-6"+quote+">Coupled Modes of Variability</h3>"  
  txt(2) = "<tr><td rowspan=5><b>ENSO</b></td>"
  txt(3) = "<td rowspan=2>Spatial Composites</td><td>SST/TAS/PSL<br>"+table_link_setup(OUTDIR,"nino34.spatialcomp.jja0.png","JJA<sup>0</sup>")+" "+table_link_setup(OUTDIR,"nino34.spatialcomp.son0.png","SON<sup>0</sup>")+"<br>"+table_link_setup(OUTDIR,"nino34.spatialcomp.djf1.png","DJF<sup>+1</sup>")+" "+table_link_setup(OUTDIR,"nino34.spatialcomp.mam1.png","MAM<sup>+1</sup>")+"</td>"
  txt(4) = "<td>PR<br>"+table_link_setup(OUTDIR,"nino34.spatialcomp.pr.jja0.png","JJA<sup>0</sup>")+" "+table_link_setup(OUTDIR,"nino34.spatialcomp.pr.son0.png","SON<sup>0</sup>")+"<br>"+table_link_setup(OUTDIR,"nino34.spatialcomp.pr.djf1.png","DJF<sup>+1</sup>")+" "+table_link_setup(OUTDIR,"nino34.spatialcomp.pr.mam1.png","MAM<sup>+1</sup>")+"</td></tr>"
  txt(5) = "<tr><td>"+table_link_setup(OUTDIR,"nino34.hov.elnino.png","El Ni&ntilde;o Hovm&ouml;ller")+"</td><td>"+table_link_setup(OUTDIR,"nino34.hov.lanina.png","La Ni&ntilde;a Hovm&ouml;ller")+"</td></tr>"
  txt(6) = "<tr class=s1><td class=s2 rowspan=3>Ni&ntilde;o3.4</td><td>"+table_link_setup(OUTDIR,"nino34.timeseries.png","Timeseries")+"</td><td>"+table_link_setup(OUTDIR,"nino34.powspec.png","Power Spectra")+"</td></tr>"
  txt(7) = "<tr><td>"+table_link_setup(OUTDIR,"nino34.monstddev.png","Monthly  Std. Dev.")+"</td><td>"+table_link_setup(OUTDIR,"nino34.runstddev.png","Running Std. Dev.")+"</td></tr>"
  txt(8) = "<tr><td class=s2>"+table_link_setup(OUTDIR,"nino34.autocor.png","Autocorrelation")+"</td><td class=s2>"+table_link_setup(OUTDIR,"nino34.wavelet.png","Wavelet Analysis")+"</td></tr>"

  txt(10) = "<tr><td><b>PDO</b></td>"  
  txt(11) = "<td>Regr: &nbsp;"+table_link_setup(OUTDIR,"pdo.png","SST")+"&nbsp;"+table_link_setup(OUTDIR,"pdo.tasreg.png","TAS")+"&nbsp;"+table_link_setup(OUTDIR,"pdo.prreg.png","PR")+"</td>"
  txt(12) = "<td>"+table_link_setup(OUTDIR,"pdo.timeseries.png","Timeseries")+"</td>"
  txt(13) = "<td>"+table_link_setup(OUTDIR,"pdo.powspec.png","Power Spectra")+"</td></tr>" 

  txt(14) = "<tr><td class=s2><b>IPO</b></td>"  
  txt(15) = "<td class=s2>Regr: &nbsp;"+table_link_setup(OUTDIR,"ipo.png","SST")+"&nbsp"+table_link_setup(OUTDIR,"ipo.tasreg.png","TAS")+"&nbsp;"+table_link_setup(OUTDIR,"ipo.prreg.png","PR")+"</td>"
  txt(16) = "<td class=s2>"+table_link_setup(OUTDIR,"ipo.timeseries.png","Timeseries")+"</td>"
  txt(17) = "<td class=s2>"+table_link_setup(OUTDIR,"ipo.powspec.png","Power Spectra")+"</td></tr>" 

  txt(18) = "<tr><td class=s2><b>IOD</b></td>"  
  txt(19) = "<td class=s2>Regr: &nbsp;"+table_link_setup(OUTDIR,"iod.png","SST")+"&nbsp"+table_link_setup(OUTDIR,"iod.tasreg.png","TAS")+"&nbsp;"+table_link_setup(OUTDIR,"iod.prreg.png","PR")+"</td>"
  txt(20) = "<td class=s2>"+table_link_setup(OUTDIR,"iod.timeseries.png","Timeseries")+"</td>"
  txt(21) = "<td class=s2>"+table_link_setup(OUTDIR,"iod.powspec.png","Power Spectra")+"</td></tr>" 

  txt(22) = "<tr><td class=s2 rowspan=2><b>AMO</b></td>"  
  txt(23) = "<td>Regr: &nbsp;"+table_link_setup(OUTDIR,"amo.png","SST")+"&nbsp;"+table_link_setup(OUTDIR,"amo.tasreg.png","TAS")+"&nbsp;"+table_link_setup(OUTDIR,"amo.prreg.png","PR")+"</td>"
  txt(24) = "<td class=s2 rowspan=2>"+table_link_setup(OUTDIR,"amo.timeseries.png","Timeseries")+"</td>"
  txt(25) = "<td class=s2 rowspan=2>"+table_link_setup(OUTDIR,"amo.powspec.png","Power Spectra")+"</td></tr>" 
  txt(26) = "<tr><td class=s2>Regr LP: &nbsp;"+table_link_setup(OUTDIR,"amo.lp.png","SST")+"&nbsp;"+table_link_setup(OUTDIR,"amo.lp.tasreg.png","TAS")+"&nbsp;"+table_link_setup(OUTDIR,"amo.lp.prreg.png","PR")+"</td></tr>"

  txt(27) = "<tr><td><b>ATL3</b></td>"  
  txt(28) = "<td>Regr: &nbsp;"+table_link_setup(OUTDIR,"atl3.png","SST")+"&nbsp"+table_link_setup(OUTDIR,"atl3.tasreg.png","TAS")+"&nbsp;"+table_link_setup(OUTDIR,"atl3.prreg.png","PR")+"</td>"
  txt(29) = "<td>"+table_link_setup(OUTDIR,"atl3.timeseries.png","Timeseries")+"</td>"
  txt(30) = "<td>"+table_link_setup(OUTDIR,"atl3.powspec.png","Power Spectra")+"</td></tr>" 


  txt(31) = "<tr><td class=s2><b>AMM</b></td>"  
  txt(32) = "<td class=s2>Regr: &nbsp;"+table_link_setup(OUTDIR,"amm.png","SST")+"&nbsp"+table_link_setup(OUTDIR,"amm.tasreg.png","TAS")+"&nbsp;"+table_link_setup(OUTDIR,"amm.prreg.png","PR")+"</td>"
  txt(33) = "<td class=s2>"+table_link_setup(OUTDIR,"amm.timeseries.png","Timeseries")+"</td>"
  txt(34) = "<td class=s2>"+table_link_setup(OUTDIR,"amm.powspec.png","Power Spectra")+"</td></tr>" 

  txt(40) = "<tr><td rowspan=3><b>AMOC</b></td>"  
  txt(41) = "<td>"+table_link_setup(OUTDIR,"amoc.mean.ann.png","Means")+"</td>"
  txt(42) = "<td>"+table_link_setup(OUTDIR,"amoc.stddev.ann.png","Standard Deviations")+"</td>"
  txt(43) = "<td>"+table_link_setup(OUTDIR,"amoc.ann.png","Patterns")+"</td></tr>"
  txt(44) = "<tr><td>"+table_link_setup(OUTDIR,"amoc.timeseries.ann.png","Timeseries")+"</td>"
  txt(45) = "<td>"+table_link_setup(OUTDIR,"amoc.sstreg.ann.png","SST Regressions")+"</td>"
  txt(46) = "<td>"+table_link_setup(OUTDIR,"amoc.tasreg.ann.png","TAS Regressions")+"</td></tr>"
  txt(47) = "<tr><td>"+table_link_setup(OUTDIR,"amoc.powspec.ann.png","Spectra")+"</td>"
  txt(48) = "<td>"+table_link_setup(OUTDIR,"amoc_amo.leadlag.ann.png","AMO/AMOC Lag Corr.")+"</td>" 
  txt(49) = "<td>"+table_link_setup(OUTDIR,"amoc.prreg.ann.png","PR Regressions")+"</td></tr></table>" 

  txt(50)=table_bottom_txt
  ;Write out the cplsst table
  cplsst_txt=[/txt(ind(.not.ismissing(txt)))/]
  write_table(OUTDIR+"index.html","a",cplsst_txt,"%s")
  delete([/cplsst_txt,txt/])


  ;Populate the atmos table
  write_table(OUTDIR+"index.html","a",[/table_top_txt/],"%s")
  write_table(OUTDIR+"index.html","a",[/"<h3 class="+quote+"display-6"+quote+">Atmospheric Modes of Variability</h3>"/],"%s") 
  modes=(/"nam","sam","nao","pna","npo","psa1","psa2"/)
  do i=0,dimsizes(modes)-1
    txt = new(20,"string")
    txt(0) = "<tr><td rowspan=4><b>"+str_upper(modes(i))+"</b></td>"
    txt(1) = "<td>Patterns</td><td>"+table_link_setup(OUTDIR,modes(i)+".djf.png","DJF")+"</td><td>"+table_link_setup(OUTDIR,modes(i)+".mam.png","MAM")+"</td>"
    txt(2) = "<td>"+table_link_setup(OUTDIR,modes(i)+".jja.png","JJA")+"</td><td>"+table_link_setup(OUTDIR,modes(i)+".son.png","SON")+"</td>"
    txt(3) = "<td>"+table_link_setup(OUTDIR,modes(i)+".ann.png","Annual")+"</td><td>"+table_link_setup(OUTDIR,modes(i)+".mon.png","Monthly")+"</td></tr>"
    txt(4) = "<tr><td>Timeseries</td><td>"+table_link_setup(OUTDIR,modes(i)+".timeseries.djf.png","DJF")+"</td><td>"+table_link_setup(OUTDIR,modes(i)+".timeseries.mam.png","MAM")+"</td>"
    txt(5) = "<td>"+table_link_setup(OUTDIR,modes(i)+".timeseries.jja.png","JJA")+"</td><td>"+table_link_setup(OUTDIR,modes(i)+".timeseries.son.png","SON")+"</td>"
    txt(6) = "<td>"+table_link_setup(OUTDIR,modes(i)+".timeseries.ann.png","Annual")+"</td><td>"+table_link_setup(OUTDIR,modes(i)+".timeseries.mon.png","Monthly")+"</td></tr>"
    txt(7) = "<tr><td>SST/TAS Regressions</td><td>"+table_link_setup(OUTDIR,modes(i)+".tempreg.djf.png","DJF")+"</td><td>"+table_link_setup(OUTDIR,modes(i)+".tempreg.mam.png","MAM")+"</td>"
    txt(8) = "<td>"+table_link_setup(OUTDIR,modes(i)+".tempreg.jja.png","JJA")+"</td><td>"+table_link_setup(OUTDIR,modes(i)+".tempreg.son.png","SON")+"</td>"
    txt(9) = "<td>"+table_link_setup(OUTDIR,modes(i)+".tempreg.ann.png","Annual")+"</td><td>"+table_link_setup(OUTDIR,modes(i)+".tempreg.mon.png","Monthly")+"</td></tr>"
    txt(10) = "<tr><td>PR Regressions</td><td>"+table_link_setup(OUTDIR,modes(i)+".prreg.djf.png","DJF")+"</td><td>"+table_link_setup(OUTDIR,modes(i)+".prreg.mam.png","MAM")+"</td>"
    txt(11) = "<td>"+table_link_setup(OUTDIR,modes(i)+".prreg.jja.png","JJA")+"</td><td>"+table_link_setup(OUTDIR,modes(i)+".prreg.son.png","SON")+"</td>"
    txt(12) = "<td>"+table_link_setup(OUTDIR,modes(i)+".prreg.ann.png","Annual")+"</td><td>"+table_link_setup(OUTDIR,modes(i)+".prreg.mon.png","Monthly")+"</td></tr>"
    atmos_txt=[/txt(ind(.not.ismissing(txt)))/]
    write_table(OUTDIR+"index.html","a",atmos_txt,"%s")
    delete([/atmos_txt,txt/])
  end do
  write_table(OUTDIR+"index.html","a",[/table_bottom_txt/],"%s")


  ;Populate the Ice Extent Timeseries
  txt = new(50,"string")
  txt(0) = table_top_txt
  txt(1) = "<h3 class="+quote+"display-6"+quote+">Ice Extent Timeseries</h3>"
  txt(3) = "<tr><td rowspan=2><b>SIC NH</b></td><td>"+table_link_setup(OUTDIR,"aice.extent.nh.djf.png","DJF")+"</td>"
  txt(4) = "<td>"+table_link_setup(OUTDIR,"aice.extent.nh.mam.png","MAM")+"</td>"
  txt(5) = "<td>"+table_link_setup(OUTDIR,"aice.extent.nh.jja.png","JJA")+"</td>"
  txt(6) = "<td>"+table_link_setup(OUTDIR,"aice.extent.nh.son.png","SON")+"</td>"
  txt(7) = "<td>"+table_link_setup(OUTDIR,"aice.extent.nh.ann.png","Annual")+"</td>"
  txt(8) = "<td>"+table_link_setup(OUTDIR,"aice.extent.nh.mon.png","Monthly")+"</td></tr>"
  txt(9) = "<tr><td colspan=2>"+table_link_setup(OUTDIR,"aice.extent.nh.feb.png","Feb")+"&nbsp;&nbsp;"+table_link_setup(OUTDIR,"aice.extent.nh.mar.png","Mar")+"&nbsp;&nbsp;"+table_link_setup(OUTDIR,"aice.extent.nh.sep.png","Sep")+"</td>"
  txt(11) = "<td colspan=2>"+table_link_setup(OUTDIR,"aice.extent.anom.nh.mon.png","Monthly Anomalies")+"</td>"
  txt(12) = "<td colspan=2>"+table_link_setup(OUTDIR,"aice.extent.nh.climo.png","Climatology")+"</td></tr>"
  txt(13) = "<tr><td rowspan=2><b>SIC SH</b></td><td>"+table_link_setup(OUTDIR,"aice.extent.sh.djf.png","DJF")+"</td>"
  txt(14) = "<td>"+table_link_setup(OUTDIR,"aice.extent.sh.mam.png","MAM")+"</td>"
  txt(15) = "<td>"+table_link_setup(OUTDIR,"aice.extent.sh.jja.png","JJA")+"</td>"
  txt(16) = "<td>"+table_link_setup(OUTDIR,"aice.extent.sh.son.png","SON")+"</td>"
  txt(17) = "<td>"+table_link_setup(OUTDIR,"aice.extent.sh.ann.png","Annual")+"</td>"
  txt(18) = "<td>"+table_link_setup(OUTDIR,"aice.extent.sh.mon.png","Monthly")+"</td></tr>"
  txt(19) = "<tr><td colspan=2>"+table_link_setup(OUTDIR,"aice.extent.sh.feb.png","Feb")+"&nbsp;&nbsp;"+table_link_setup(OUTDIR,"aice.extent.sh.mar.png","Mar")+"&nbsp;&nbsp;"+table_link_setup(OUTDIR,"aice.extent.sh.sep.png","Sep")+"</td>"
  txt(21) = "<td colspan=2>"+table_link_setup(OUTDIR,"aice.extent.anom.sh.mon.png","Monthly Anomalies")+"</td>"
  txt(22) = "<td colspan=2>"+table_link_setup(OUTDIR,"aice.extent.sh.climo.png","Climatology")+"</td></tr></table>"
  txt(48)=table_bottom_txt
  txt(49)=""
  ;Write out the ice table
  ice_txt=[/txt(ind(.not.ismissing(txt)))/]
  write_table(OUTDIR+"index.html","a",ice_txt,"%s")
  delete([/ice_txt,txt/])


  ;Populate the trends table
  txt = new(50,"string")
  txt(0) = table_top_txt
  txt(1) = "<h3 class="+quote+"display-6"+quote+">Global Trend Maps</h3>"
  txt(2) = "<tr><td><b>SST</b></td><td>"+table_link_setup(OUTDIR,"sst.trends.djf.png","DJF")+"</td>"
  txt(3) = "<td>"+table_link_setup(OUTDIR,"sst.trends.mam.png","MAM")+"</td>"
  txt(4) = "<td>"+table_link_setup(OUTDIR,"sst.trends.jja.png","JJA")+"</td>"
  txt(5) = "<td>"+table_link_setup(OUTDIR,"sst.trends.son.png","SON")+"</td>"
  txt(6) = "<td>"+table_link_setup(OUTDIR,"sst.trends.ann.png","Annual")+"</td>"
  txt(7) = "<td>"+table_link_setup(OUTDIR,"sst.trends.mon.png","Monthly")+"</td></tr>"
  txt(8) = "<tr><td><b>TAS</b></td><td>"+table_link_setup(OUTDIR,"tas.trends.djf.png","DJF")+"</td>"
  txt(9) = "<td>"+table_link_setup(OUTDIR,"tas.trends.mam.png","MAM")+"</td>"
  txt(10) = "<td>"+table_link_setup(OUTDIR,"tas.trends.jja.png","JJA")+"</td>"
  txt(11) = "<td>"+table_link_setup(OUTDIR,"tas.trends.son.png","SON")+"</td>"
  txt(12) = "<td>"+table_link_setup(OUTDIR,"tas.trends.ann.png","Annual")+"</td>"
  txt(13) = "<td>"+table_link_setup(OUTDIR,"tas.trends.mon.png","Monthly")+"</td></tr>"
  txt(14) = "<tr><td><b>PSL</b></td><td>"+table_link_setup(OUTDIR,"psl.trends.djf.png","DJF")+"</td>"
  txt(15) = "<td>"+table_link_setup(OUTDIR,"psl.trends.mam.png","MAM")+"</td>"
  txt(16) = "<td>"+table_link_setup(OUTDIR,"psl.trends.jja.png","JJA")+"</td>"
  txt(17) = "<td>"+table_link_setup(OUTDIR,"psl.trends.son.png","SON")+"</td>"
  txt(18) = "<td>"+table_link_setup(OUTDIR,"psl.trends.ann.png","Annual")+"</td>"
  txt(19) = "<td>"+table_link_setup(OUTDIR,"psl.trends.mon.png","Monthly")+"</td></tr>"
  txt(20) = "<tr><td><b>PR</b></td><td>"+table_link_setup(OUTDIR,"pr.trends.djf.png","DJF")+"</td>"
  txt(21) = "<td>"+table_link_setup(OUTDIR,"pr.trends.mam.png","MAM")+"</td>"
  txt(22) = "<td>"+table_link_setup(OUTDIR,"pr.trends.jja.png","JJA")+"</td>"
  txt(23) = "<td>"+table_link_setup(OUTDIR,"pr.trends.son.png","SON")+"</td>"
  txt(24) = "<td>"+table_link_setup(OUTDIR,"pr.trends.ann.png","Annual")+"</td>"
  txt(25) = "<td>"+table_link_setup(OUTDIR,"pr.trends.mon.png","Monthly")+"</td></tr>" 
  txt(26) = "<tr><td><b>SND</b></td><td>"+table_link_setup(OUTDIR,"snd.trends.djf.png","DJF")+"</td>"
  txt(27) = "<td>"+table_link_setup(OUTDIR,"snd.trends.mam.png","MAM")+"</td>"
  txt(28) = "<td>"+table_link_setup(OUTDIR,"snd.trends.jja.png","JJA")+"</td>"
  txt(29) = "<td>"+table_link_setup(OUTDIR,"snd.trends.son.png","SON")+"</td>"
  txt(30) = "<td>"+table_link_setup(OUTDIR,"snd.trends.ann.png","Annual")+"</td>"
  txt(31) = "<td>"+table_link_setup(OUTDIR,"snd.trends.mon.png","Monthly")+"</td></tr>"
  txt(32) = "<tr><td><b>SIC NH</b></td><td>"+table_link_setup(OUTDIR,"aice.trends.nh.djf.png","DJF")+"</td>"
  txt(33) = "<td>"+table_link_setup(OUTDIR,"aice.trends.nh.mam.png","MAM")+"</td>"
  txt(34) = "<td>"+table_link_setup(OUTDIR,"aice.trends.nh.jja.png","JJA")+"</td>"
  txt(35) = "<td>"+table_link_setup(OUTDIR,"aice.trends.nh.son.png","SON")+"</td>"
  txt(36) = "<td>"+table_link_setup(OUTDIR,"aice.trends.nh.ann.png","Annual")+"</td>"
  txt(37) = "<td>"+table_link_setup(OUTDIR,"aice.trends.nh.mon.png","Monthly")+"</td></tr>" 
  txt(38) = "<tr><td><b>SIC SH</b></td><td>"+table_link_setup(OUTDIR,"aice.trends.sh.djf.png","DJF")+"</td>"
  txt(39) = "<td>"+table_link_setup(OUTDIR,"aice.trends.sh.mam.png","MAM")+"</td>"
  txt(40) = "<td>"+table_link_setup(OUTDIR,"aice.trends.sh.jja.png","JJA")+"</td>"
  txt(41) = "<td>"+table_link_setup(OUTDIR,"aice.trends.sh.son.png","SON")+"</td>"
  txt(42) = "<td>"+table_link_setup(OUTDIR,"aice.trends.sh.ann.png","Annual")+"</td>"
  txt(43) = "<td>"+table_link_setup(OUTDIR,"aice.trends.sh.mon.png","Monthly")+"</td></tr></table>"
  txt(48)=table_bottom_txt
  txt(49)=""
  ;Write out the trends table
  trends_txt=[/txt(ind(.not.ismissing(txt)))/]
  write_table(OUTDIR+"index.html","a",trends_txt,"%s")
  delete([/trends_txt,txt/])

  ;Populate the timeseries table
  txt = new(50,"string")
  txt(0) = table_top_txt
  txt(1) = "<h3 class="+quote+"display-6"+quote+">Globally-Averaged Timeseries</h3>"
  txt(2) = "<tr><td><b>SST</b></td><td>"+table_link_setup(OUTDIR,"sst.timeseries.djf.png","DJF")+"</td>"
  txt(3) = "<td>"+table_link_setup(OUTDIR,"sst.timeseries.mam.png","MAM")+"</td>"
  txt(4) = "<td>"+table_link_setup(OUTDIR,"sst.timeseries.jja.png","JJA")+"</td>"
  txt(5) = "<td>"+table_link_setup(OUTDIR,"sst.timeseries.son.png","SON")+"</td>"
  txt(6) = "<td>"+table_link_setup(OUTDIR,"sst.timeseries.ann.png","Annual")+"</td>"
  txt(7) = "<td>"+table_link_setup(OUTDIR,"sst.timeseries.mon.png","Monthly")+"</td></tr>"
  txt(8) = "<tr><td><b>TAS</b></td><td>"+table_link_setup(OUTDIR,"tas.timeseries.djf.png","DJF")+"</td>"
  txt(9) = "<td>"+table_link_setup(OUTDIR,"tas.timeseries.mam.png","MAM")+"</td>"
  txt(10) = "<td>"+table_link_setup(OUTDIR,"tas.timeseries.jja.png","JJA")+"</td>"
  txt(11) = "<td>"+table_link_setup(OUTDIR,"tas.timeseries.son.png","SON")+"</td>"
  txt(12) = "<td>"+table_link_setup(OUTDIR,"tas.timeseries.ann.png","Annual")+"</td>"
  txt(13) = "<td>"+table_link_setup(OUTDIR,"tas.timeseries.mon.png","Monthly")+"</td></tr>"
  txt(14) = "<tr><td><b>PR</b></td><td>"+table_link_setup(OUTDIR,"pr.timeseries.djf.png","DJF")+"</td>"
  txt(15) = "<td>"+table_link_setup(OUTDIR,"pr.timeseries.mam.png","MAM")+"</td>"
  txt(16) = "<td>"+table_link_setup(OUTDIR,"pr.timeseries.jja.png","JJA")+"</td>"
  txt(17) = "<td>"+table_link_setup(OUTDIR,"pr.timeseries.son.png","SON")+"</td>"
  txt(18) = "<td>"+table_link_setup(OUTDIR,"pr.timeseries.ann.png","Annual")+"</td>"
  txt(19) = "<td>"+table_link_setup(OUTDIR,"pr.timeseries.mon.png","Monthly")+"</td></tr>"
  txt(48)=table_bottom_txt
  txt(49)=""
  ;Write out the timeseries table
  timeseries_txt=[/txt(ind(.not.ismissing(txt)))/]
  write_table(OUTDIR+"index.html","a",timeseries_txt,"%s")
  delete([/timeseries_txt,txt/])


  ;Populate the runtrends table
  txt = new(50,"string")
  txt(0) = table_top_txt
  txt(1) = "<h3 class="+quote+"display-6"+quote+">Running Trends of Globally-Averaged Monthly Timeseries</h3>"
  txt(2) = "<tr><td><b>SST</b></td><td>"+table_link_setup(OUTDIR,"sst.8yr_runtrend.mon.png","8yr")+"</td>"
  txt(3) = "<td>"+table_link_setup(OUTDIR,"sst.10yr_runtrend.mon.png","10yr")+"</td>"
  txt(4) = "<td>"+table_link_setup(OUTDIR,"sst.12yr_runtrend.mon.png","12yr")+"</td>"
  txt(5) = "<td>"+table_link_setup(OUTDIR,"sst.14yr_runtrend.mon.png","14yr")+"</td>"
  txt(6) = "<td>"+table_link_setup(OUTDIR,"sst.16yr_runtrend.mon.png","16yr")+"</td></tr>"
  txt(7) = "<tr><td><b>TAS</b></td><td>"+table_link_setup(OUTDIR,"tas.8yr_runtrend.mon.png","8yr")+"</td>"
  txt(8) = "<td>"+table_link_setup(OUTDIR,"tas.10yr_runtrend.mon.png","10yr")+"</td>"
  txt(9) = "<td>"+table_link_setup(OUTDIR,"tas.12yr_runtrend.mon.png","12yr")+"</td>"
  txt(10) = "<td>"+table_link_setup(OUTDIR,"tas.14yr_runtrend.mon.png","14yr")+"</td>"
  txt(11) = "<td>"+table_link_setup(OUTDIR,"tas.16yr_runtrend.mon.png","16yr")+"</td></tr>"
  txt(48)=table_bottom_txt
  txt(49)=""
  ;Write out the runtrends table
  runtrends_txt=[/txt(ind(.not.ismissing(txt)))/]
  write_table(OUTDIR+"index.html","a",runtrends_txt,"%s")
  delete([/runtrends_txt,txt/])

  ;Populate the monsoon table
  txt = new(50,"string")
  txt(0) = table_top_txt
  txt(1) = "<h3 class="+quote+"display-6"+quote+">Monsoon diagnostics</h3>"
  txt(2) = "<tr><td colspan=5>"+table_link_setup(OUTDIR,"global_monsoon_domain.png","Global map of monsoon rainfall")+"</td>"
  txt(3) = "<tr><td rowspan=2><b>Area</b></td><td>"+table_link_setup(OUTDIR,"monsoon_area_global.timeseries.png","GLOBAL")+"</td>"
  txt(4) = "<td>"+table_link_setup(OUTDIR,"monsoon_area_EAS.timeseries.png","EAS")+"</td>"
  txt(5) = "<td>"+table_link_setup(OUTDIR,"monsoon_area_AUSMC.timeseries.png","AUSMC")+"</td>"
  txt(6) = "<td>"+table_link_setup(OUTDIR,"monsoon_area_NAF.timeseries.png","NAF")+"</td></tr>"
  txt(7) = "<tr><td>"+table_link_setup(OUTDIR,"monsoon_area_NAMS.timeseries.png","NAMS")+"</td>"
  txt(8) = "<td>"+table_link_setup(OUTDIR,"monsoon_area_SAF.timeseries.png","SAF")+"</td>"
  txt(9) = "<td>"+table_link_setup(OUTDIR,"monsoon_area_SAMS.timeseries.png","SAMS")+"</td>"
  txt(10) = "<td>"+table_link_setup(OUTDIR,"monsoon_area_SAS.timeseries.png","SAS")+"</td></tr>"
  txt(11) = "<tr><td rowspan=2><b>Amount</b></td><td>"+table_link_setup(OUTDIR,"monsoon_rain_global.timeseries.png","GLOBAL")+"</td>"
  txt(12) = "<td>"+table_link_setup(OUTDIR,"monsoon_rain_EAS.timeseries.png","EAS")+"</td>"
  txt(13) = "<td>"+table_link_setup(OUTDIR,"monsoon_rain_AUSMC.timeseries.png","AUSMC")+"</td>"
  txt(14) = "<td>"+table_link_setup(OUTDIR,"monsoon_rain_NAF.timeseries.png","NAF")+"</td></tr>"
  txt(15) = "<tr><td>"+table_link_setup(OUTDIR,"monsoon_rain_NAMS.timeseries.png","NAMS")+"</td>"
  txt(16) = "<td>"+table_link_setup(OUTDIR,"monsoon_rain_SAF.timeseries.png","SAF")+"</td>"
  txt(17) = "<td>"+table_link_setup(OUTDIR,"monsoon_rain_SAMS.timeseries.png","SAMS")+"</td>"
  txt(18) = "<td>"+table_link_setup(OUTDIR,"monsoon_rain_SAS.timeseries.png","SAS")+"</td></tr>"
  txt(48)=table_bottom_txt
  txt(49)=""
  ;Write out the runtrends table
  runtrends_txt=[/txt(ind(.not.ismissing(txt)))/]
  write_table(OUTDIR+"index.html","a",runtrends_txt,"%s")
  delete([/runtrends_txt,txt/])


  ;Populate the add_ts table
  txt = new(50,"string")
  txt(0) = table_top_txt
  txt(1) = "<h3 class="+quote+"display-6"+quote+">Additional Indices</h3>"
  txt(2) = "<tr><td>"+table_link_setup(OUTDIR,"amm.timeseries.png","Atlantic Meridional Mode")+"</td>"
  txt(3) = "<td>"+table_link_setup(OUTDIR,"atl3.timeseries.png","Atlantic Ni&ntilde;o (ATL3)")+"</td>"
  txt(4) = "<td>"+table_link_setup(OUTDIR,"tna.timeseries.png","Tropical North Atlantic SST")+"</td>"
  txt(5) = "<td>"+table_link_setup(OUTDIR,"tsa.timeseries.png","Tropical South Atlantic SST")+"</td></tr>"
  txt(6) = "<tr><td>"+table_link_setup(OUTDIR,"nino12.timeseries.png","ni&ntilde;o1+2")+"</td>"
  txt(7) = "<td>"+table_link_setup(OUTDIR,"nino3.timeseries.png","ni&ntilde;o3")+"</td>"
  txt(8) = "<td>"+table_link_setup(OUTDIR,"nino4.timeseries.png","ni&ntilde;o4")+"</td>"
  txt(9) = "<td>"+table_link_setup(OUTDIR,"npi.timeseries.ndjfm.png","North Pacific PSL")+"</td></tr>"
  txt(10) = "<tr><td>"+table_link_setup(OUTDIR,"iod.timeseries.png","Indian Ocean SST Dipole")+"</td>"
  txt(11) = "<td>"+table_link_setup(OUTDIR,"tio.timeseries.png","Tropical Indian Ocean SST")+"</td>"
  txt(12) = "<td>"+table_link_setup(OUTDIR,"eeio.timeseries.png","Eastern Equatorial Indian Ocean SST")+"</td>"
  txt(13) = "<td>"+table_link_setup(OUTDIR,"socn.timeseries.png","Southern Ocean SST")+"</td></tr>"
  txt(48)=table_bottom_txt
  txt(49)=""
  add_ts_txt=[/txt(ind(.not.ismissing(txt)))/]
  write_table(OUTDIR+"index.html","a",add_ts_txt,"%s")
  delete([/add_ts_txt,txt/])
   
  ;Populate the ipcc_reg table if any AR6 images are present...
  if (isfilepresent2(OUTDIR+"ipcc_MDG_tas.timeseries.png") .or. isfilepresent2(OUTDIR+"ipcc_MDG_pr.timeseries.png")) then
    txt = new(100,"string")
    txt(0) = table_top_txt
    txt(1) = "<h3 class="+quote+"display-6"+quote+">Regional Timeseries</h3>"
    nice_regnames=(/"Global (land & ocean)","Global (land only)","Global (ocean only)",\ ;global regions
               "Greenland/Iceland", "N.W. North-America", "N.E. North-America", "W.North-America", "C. North-America",\
               "E. North-America", "N. Central-America", "S. Central-America", "Caribbean", "N.W. South-America",\
               "N. South-America", "N.E. South-America", "South-American-Monsoon", "S.W. South-America", "S.E. South-America",\
               "S. South-America", "N. Europe", "West & Central-Europe", "E. Europe", "Mediterranean", "Sahara", "Western Africa",\
               "Central Africa", "N. Eastern Africa", "S. Eastern-Africa", "W. Southern Africa", "E. Southern Africa",\
               "Madagascar", "Russian Arctic", "W. Siberia", "E. Siberia", "Russian Far-East",\
               "W. Central Asia", "E. Central Asia", "Tibetan Plateau", "E. Asia", "Arabian Peninsula","S. Asia","S.E. Asia",\
               "N. Australia", "C. Australia", "E. Australia", "S. Australia","New Zealand", "E. Antarctica", "W. Antarctica",\
               "Arctic Ocean", "N. Pacific", "Equatorial Pacific", "S. Pacific", "N. Atlantic",\
               "Equat. Atlantic", "S. Atlantic", "Arabian Sea", "Bay of Bengal",\
               "Equat. Indian Ocean", "S. Indian Ocean", "Southern Ocean",\
               "NH High Lats (all)","NH High Lats (land)","NH High Lats (ocean)",\ ; Latitude bands
               "NH Mid-Lats (all)","NH Mid-Lats (land)","NH Mid-Lats (ocean)",\
               "NH Tropics (all)","NH Tropics (land)","NH Tropics (ocean)",\
               "SH Tropics (all)","SH Tropics (land)","SH Tropics (ocean)",\
               "SH Mid-lats (all)","SH Mid-lats (land)","SH Mid-Lats (ocean)",\
               "SH High Lats (all)","SH High lats (land)","SH High Lats (ocean)"/)
    regnames=(/"GLOBAL_all","GLOBAL_lnd","GLOBAL_ocn",\
               "GIC","NWN","NEN","WNA","CNA","ENA","NCA","SCA","CAR_lnd","CAR_ocn","NWS","NSA","NES",\ ;Iturbide et al (2020) land regions
               "SAM","SWS","SES","SSA","NEU","WCE","EEU","MED_lnd","MED_ocn","SAH","WAF","CAF","NEAF",\
               "SEAF","WSAF","ESAF","MDG","RAR","WSB","ESB","RFE","WCA","ECA","TIB","EAS","ARP","SAS",\
               "SEA_lnd","SEA_ocn","NAU","CAU","EAU","SAU","NZ","EAN","WAN",\
               "ARO","NPO","EPO","SPO","NAO","EAO","SAO","ARS","BOB","EIO","SIO","SOO",\ ;Iturbide et al (2020) oceans
               "NH_highlats_all","NH_highlats_lnd","NH_highlats_ocn",\ ; Latitude bands
               "NH_midlats_all","NH_midlats_lnd","NH_midlats_ocn",\
               "NH_tropics_all","NH_tropics_lnd","NH_tropics_ocn",\
               "SH_tropics_all","SH_tropics_lnd","SH_tropics_ocn",\
               "SH_midlats_all","SH_midlats_lnd","SH_midlats_ocn",\
               "SH_highlats_all","SH_highlats_lnd","SH_highlats_ocn"/)
    do reg_i=0,dimsizes(regnames)-1
       txt(2+reg_i) = "<tr><td> "+nice_regnames(reg_i)+" </td>"+\
                "<td>"+table_link_setup(OUTDIR,"ipcc_"+regnames(reg_i)+"_tas.timeseries.png",regnames(reg_i)+" temp.")+"</td>"+\
                "<td>"+table_link_setup(OUTDIR,"ipcc_"+regnames(reg_i)+"_pr.timeseries.png",regnames(reg_i)+" precip.")+"</td></tr>"
    end do
    txt(98)=table_bottom_txt
    txt(99)=""
    ipcc_reg_txt=[/txt(ind(.not.ismissing(txt)))/]
    write_table(OUTDIR+"index.html","a",ipcc_reg_txt,"%s")
    delete([/ipcc_reg_txt,txt/])
  else
     ;Populate the ipcc_reg table if any AR5 images are present...
     if (isfilepresent2(OUTDIR+"ipcc_AMZ_tas.timeseries.png") .or. isfilepresent2(OUTDIR+"ipcc_AMZ_pr.timeseries.png")) then
        txt = new(100,"string")
        txt(0) = table_top_txt
        txt(1) = "<h3 class="+quote+"display-6"+quote+">Regional Timeseries</h3>"
        regnames=(/"GLOBAL_all","GLOBAL_lnd","GLOBAL_ocn",\ ;global domains
               "ALA","AMZ","CAM","CAS","CEU","CGI","CNA","EAF","EAS","ENA",\ ;SREX regions
               "MED","NAS","NAU","NEB","NEU","SAF","SAH","SAS_lnd","SAS_ocn","SAU",\
               "SEA_lnd","SEA_ocn","SSA","TIB","WAF","WAS","WNA","WSA",\
               "ANT_lnd","ARC_lnd","ANT_ocn","ARC_ocn","CAR","NTP","STP","ETP","WIO",\ ;and the new AR5 regions
               "NH_highlats_all","NH_highlats_lnd","NH_highlats_ocn","NH_midlats_all","NH_midlats_lnd",\
               "NH_midlats_ocn","NH_tropics_all","NH_tropics_lnd","NH_tropics_ocn","SH_tropics_all",\
               "SH_tropics_lnd","SH_tropics_ocn","SH_midlats_all","SH_midlats_lnd","SH_midlats_ocn",\
               "SH_highlats_all","SH_highlats_lnd","SH_highlats_ocn"/) ; and the latitude bands
        do reg_i=0,dimsizes(regnames)-1
           txt(2+reg_i) = "<tr><td> "+regnames(reg_i)+" </td>"+\
              "<td>"+table_link_setup(OUTDIR,"ipcc_"+regnames(reg_i)+"_tas.timeseries.png",regnames(reg_i)+" temp.")+"</td>"+\
              "<td>"+table_link_setup(OUTDIR,"ipcc_"+regnames(reg_i)+"_pr.timeseries.png",regnames(reg_i)+" precip.")+"</td></tr>"
        end do
        txt(98)=table_bottom_txt
        txt(99)=""
        ipcc_reg_txt=[/txt(ind(.not.ismissing(txt)))/]
        write_table(OUTDIR+"index.html","a",ipcc_reg_txt,"%s")
        delete([/ipcc_reg_txt,txt/])
     end if
   end if

  ;add the table bottom and tidy up...
  write_table(OUTDIR+"index.html","a",[/"<br>","</body></html>"/],"%s")
  delete([/quote,names,na,nsim_noobs/])

;----------------------------------------------------------------------------
;--   Create calculation description webpage
;----------------------------------------------------------------------------
  txt = new(200,"string")
  quote = str_get_dq()
  
  txt(0) = "<html><head><title>Climate Variability Diagnostics Package</title>"
  txt(1) = "<link rel="+quote+"stylesheet"+quote+" href="+quote+"https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/css/bootstrap.min.css"+quote+" integrity="+quote+"sha384-MCw98/SFnGE8fJT3GXwEOngsV7Zt27NXFoaoApmYm81iuXoPkFOJwJ8ERdknLPMO"+quote+" crossorigin="+quote+"anonymous"+quote+">"
  txt(2) = "<script src="+quote+"https://code.jquery.com/jquery-3.3.1.slim.min.js"+quote+" integrity="+quote+"sha384-q8i/X+965DzO0rT7abK41JStQIAqVgRVzpbzo5smXKp4YfRvH+8abtTE1Pi6jizo"+quote+" crossorigin="+quote+"anonymous"+quote+"></script>"
  txt(3) = "<script src="+quote+"https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.14.3/umd/popper.min.js"+quote+" integrity="+quote+"sha384-ZMP7rVo3mIykV+2+9J3UJ46jBk0WLaUAdn689aCwoqbBJiSnjAK/l8WvCWPIPm49"+quote+" crossorigin="+quote+"anonymous"+quote+"></script>"
  txt(4) = "<script src="+quote+"https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/js/bootstrap.min.js"+quote+" integrity="+quote+"sha384-ChfqqxuZUCnJSK3+MXmPNIyE6ZbWh2IMqE241rYiqJxyMiZ6OW/JmZQ5stwEULTy"+quote+" crossorigin="+quote+"anonymous"+quote+"></script>"

  txt(5) = "<style>body {background-color: WhiteSmoke; font-family: Verdana, Geneva, sans-serif}"
  txt(6) = "img.title {width:990; height:105; align:left}"
  txt(7) = "p.title {font-size:20pt; color:black; font-weight:bold; text-align:center}"
  txt(8) = "p.subtitle1 {font-size:12pt; color:gray}"
  txt(9) = "p.subtitle {font-size:16pt; color:black; font-weight:bold; text-align:left}"
  txt(10) = "p.btext {font-size:9pt}"
  txt(11) = "td {text-align:left; font-size:12pt}"
  txt(12) = "td.s1 {text-align:left; font-size:11pt}"
  txt(13) = "CAPTION {text-align:left; font-size:14pt; font-weight:bold}"
  txt(14) = "</style></head><BODY>"
  txt(15) = "<img class=title src="+quote+"cas-cvdp.png"+quote+" alt="+quote+"CVDP logo"+quote+">"  
  txt(16) = "<TABLE width='990' border=0 cellpadding=6><tr><td class=s1 width='300'><a href="+quote+"index.html"+quote+">Back to Diagnostics Plots</a></td>"
  txt(17) = "<td><p class=title>Methodology and Definitions</p></td></tr></table><hr width=990 align=left>" 

  txt(20) = "<p class=subtitle>General Notes</p>"
  txt(21) = "<TABLE width='800' border=1 frame=void rules=all cellpadding=6 bordercolor=darkgray>"
  txt(22) = "<tr><td><ul><li>TS is surface ("+quote+"skin"+quote+") temperature and is used in lieu of sea surface temperatures (SSTs), TAS is 2m air temperature (CESM equivalent = TREFHT)."
  txt(23) = "<li>PR is total precipitation (CESM equivalent = PRECC+PRECL), PSL is sea level pressure, SND is snow depth (SNOWDP), and SIC is ice concentration (aice)."
  txt(24) = "<li>The annual cycle is removed prior to every calculation by subtracting the long-term monthly means. Exception: The annual cycle is not removed for mean spatial maps."
  txt(25) = "<li>Area-averages are always based on cosine of latitude weighting."
  txt(26) = "<li>The following calculations use linearly detrended data: standard deviations, nino3.4 spectra, nino3.4 autocorrelations, ENSO spatial composites, and ENSO Hovm&ouml;llers."
  txt(27) = "<li>For visual clarity, the Y-axis <i>may</i> differ amongst individual panels on a particular plot."
  txt(28) = "<li>Climatological Zonal Averages: Climatological means are zonally averaged over the globe." 
  txt(29) = "<li>Power Spectra: The best-fit first-order Markov red noise spectrum (red curve) and its 95% (blue curve) and 99% (green curve) confidence bounds are shown on each panel. Top X-axis shows the period (in years), and the bottom X-axis shows the frequency (cycles/mo). If calculated, the observational spectrum is overlaid in gray on each model spectrum. The spectra are displayed in variance-conserving form." 
  txt(30) = "<li>Wavelet Analysis: A wavelet transform is computed using a Morlet wavelet with a wavenumber of 6. Areas significant at the 95% based on a chi-square test are stippled and the “cone of influence” is hatched. See Torrence, C. and G. P. Compo, 1998: A Practical Guide to Wavelet Analysis. Bull. Amer. Meteor. Soc., 79, 61-78. doi: http://dx.doi.org/10.1175/1520-0477(1998)079<0061:APGTWA>2.0.CO;2."
  txt(31) = "<li>Running Trends: N-year running trends are computed by calculating the linear trend over the N-year interval beginning at each successive timestep.  For instance, for a global timeseries that runs from 1970-2012, the 8yr running trend value for January 1970 is the linear trend during January 1970 - December 1977, and the value for January 2005 is the linear trend during January 2005 - December 2012."
  txt(32) = "<li>Running Standard Deviations: 30-year running standard deviations are computed by calculating the standard deviation centered over the 30 year interval at each successive timestep, with a minimum of 35 years of data required. For example, for a timeseries that runs from 1920-2010, the 30yr running standard deviation value for January 1935 is calculated over the period January 1920-December 1949. The right subtitle shows the minimum / mean / maximum of the computed timeseries." 
  txt(33) = "<li>Metrics Tables: Area-weighted pattern correlations and rms differences are calculated between observations and each model simulation (regridded to match the observational grid) for 11 climate metrics. The Total Score column shows the average of the 11 pattern correlations (Z-transformed) and rms differences. The following domains are used to compute the pattern correlations and rms differences: Means, standard deviations, ENSO, AMO, and PDO: Global; global for means, standard deviations, ENSO, AMO, and PDO; entire longitude/temporal range shown for El Nino and La Nina Hovm&ouml;llers; entire domain shown for NAM (20:90&deg;N) and SAM (20:90&deg;S)."
  txt(34) = "<li>EOF significance: If an eigenvalue is significantly seperated from neighboring values a star is appended to the percent variance explained on the plot. Significance is calculated following North et al. (MWR, 1982)."
  txt(35) = "<li>Ice Extent: Any grid cell defined as having a value at or above 15% is assumed to be 100% ice covered. The area of these grid cells is summed to create ice extent. For data sets with a northern hemisphere pole hole the CVDP looks for an attribute named pole_hole_area that is attached to the AREA variable in the netCDF file. The format of pole_hole_area should be start month (YYYYMM), end month (YYYYMM), area value, (repeat as necessary). If pole_hole_area is detected the CVDP will add the area value to the calculated northern hemisphere ice extent timeseries from the specified start month to the specified end month, and a * is placed after the dataset name in the ice extent plots."    
  txt(36) = "<li>For more information on observational datasets and climate indices, see the <a href="+quote+"http://climatedataguide.ucar.edu/"+quote+" target="+quote+"_blank"+quote+">Climate Data Guide</a>.</ul>"
  txt(37) = "</td></tr></table>"

  txt(40) = "<p class=subtitle>Modes of Variability</p>"
  txt(41) = "<TABLE width='800' border=1 frame=void rules=all cellpadding=6 bordercolor=darkgray>"
  txt(42) = "<tr><td><b>ENSO Spatial Composites</b></td>"
  txt(43) = "<td>The normalized December nino3.4 timeseries is used to composite all years greater than 1 standard deviation (El Ni&ntilde;o) and all years less that -1 standard deviation (La Ni&ntilde;a). The number of El Ni&ntilde;o/La Ni&ntilde;a events composited is shown in the right subtitle. The December nino3.4 timeseries is based on the December values of the monthly nino3.4 time series smoothed with a 3-point binomial filter. TS/TAS/PSL composites: Temperatures are color shaded and in units of Celsius. Sea level pressure is contoured from -16 to 16hPa by 2hPa; negative contours are dashed. PR composites: Precipitation is color shaded and is in units of mm/day. See Deser, C., A. S. Phillips, R. A. Tomas, Y. Okumura, M. A. Alexander, A. Capotondi, J. D. Scott, Y. -O. Kwon, and M. Ohba, 2012: ENSO and Pacific Decadal Variability in Community Climate System Model Version 4. <i>J. Climate</i>, 25, 2622-2651, doi: 10.1175/JCLI-D-11-00301.1.</td></tr>"   
  txt(44) = "<tr><td><b>ENSO Hovm&ouml;llers</b></td>"
  txt(45) = "<td>A 1-2-1 running average is applied to the monthly nino3.4 timeseries, and then December values are selected and normalized. Meridional averages are calculated by averaging from 3&deg;S:3&deg;N, and spatial patterns are formed by compositing from Jan year 0 to May year 2 where the nino3.4 (1-2-1 weighted) December (year 0) index is greater than 1 (El Niño) and those years where the index is less than -1 (La Niña). See Deser, C., A. S. Phillips, R. A. Tomas, Y. Okumura, M. A. Alexander, A. Capotondi, J. D. Scott, Y. -O. Kwon, and M. Ohba, 2012: ENSO and Pacific Decadal Variability in Community Climate System Model Version 4. J. Climate, 25, 2622-2651, doi: 10.1175/JCLI-D-11-00301.1.</td></tr>"  

  txt(46) = "<tr><td><b>PDO</b> (Pacific Decadal Oscillation)</td>"  
  txt(47) = "<td>Monthly index timeseries defined as the leading principal component (PC) of North Pacific (20:70&deg;N, 110&deg;E:100&deg;W) area-weighted SST* anomalies, where SST* denotes that the global mean SST anomaly has been removed at each timestep. Pattern created by regressing SST anomalies (in Celsius) at each grid box onto the normalized PC timeseries. Low pass-filtered timeseries (black curve) is based on a a 61-month running mean. See Deser, C., M. A. Alexander, S. -P. Xie, and A. S. Phillips, 2010: Sea surface temperature variability: patterns and mechanisms. <i>Ann. Rev. Mar. Sci.</i>, 2010.2, 115-143, doi:10.1146/annurev-marine-120408-151453. Also see Mantua, N. J., S. R. Hare, Y. Zhang, J. M. Wallace, and R. Francis, 1997: A Pacific interdecadal climate oscillation with impacts on salmon production. <i>Bull. Amer. Met. Soc.</i>, 1069-1079. For more information on the PDO see the <a href="+quote+"https://climatedataguide.ucar.edu/climate-data/pacific-decadal-oscillation-pdo-definition-and-indices?qt-climatedatasetmaintabs=1"+quote+" target="+quote+"_blank"+quote+">Climate Data Guide</a>.</td></tr>"
  txt(48) = "<tr><td><b>IPO</b> (Interdecadal Pacific Oscillation)</td>"  
  txt(49) = "<td>Monthly index timeseries defined as the leading principal component (PC) of 13yr low pass filtered Pacific (40&deg;S:60&deg;N, 110&deg;E:70&deg;W) area-weighted SST* anomalies, where SST* denotes that the global mean SST anomaly has been removed at each timestep.  Pattern created by regressing SST anomalies (in Celsius) at each grid box onto the normalized PC timeseries. At least 40 years of data are required for the IPO to be calculated. See Meehl, G.A. and A. Hu, 2007: Megadroughts in the Indian Monsoon Region and Southwest North America and a Mechanism for Associated Multidecadal Pacific Sea Surface Temperature Anomalies, <i>J. Clim</i>, 19, 1605-1623, doi: 10.1175/JCLI3675.1.</td></tr>"

  txt(50) = "<tr><td><b>AMO</b> (Atlantic Multidecadal Oscillation)</td>"  
  txt(51) = "<td>Monthly index timeseries defined as area-weighted SST* anomalies averaged over the North Atlantic (0:60&deg;N, 80&deg;W:0&deg;E), where SST* denotes that the global (60&deg;S:60&deg;N) mean SST anomaly has been removed at each timestep. Pattern created by regressing SST* anomalies onto the index timeseries and smoothing with a 9-point spatial filter. Low pass-filtered timeseries (black curve superimposed on the monthly timeseries) is based on a a 61-month running mean. Based on Trenberth, K. E., and D. J. Shea, 2006: Atlantic hurricanes and natural variability in 2005, <i>Geophys. Res. Lett.</i>, 33, L12704, doi:10.1029/2006GL026894. Low-pass filtered regression maps ("+quote+"Regr LP"+quote+") use a 10-year running mean on both the index timeseries and the field being regressed. For more information on the AMO see the <a href="+quote+"https://climatedataguide.ucar.edu/climate-data/atlantic-multi-decadal-oscillation-amo?qt-climatedatasetmaintabs=1"+quote+" target="+quote+"_blank"+quote+">Climate Data Guide</a>.</td></tr>"
  txt(52) = "<tr><td><b>AMOC</b></td>"
  ; txt(53) = "<td>The Atlantic Meridional Overturning Circulation (AMOC) is defined as the oceanic meridional mass transport (Sv) in the Atlantic sector. To compute AMOC, we follow the methods of Danabasoglu et al. (2012). Here we use annual averages of the AMOC, weighted by the cosine of the latitude and vertical extent of each model layer. Areas in which AMOC variance is low (standard deviation < 1e-6 Sv) are set to missing values for clarity. The leading EOF and associated principal component (PC) timeseries are computed over the Atlantic basin from 33&deg;S to 90&deg;N. The AMOC patterns are created by regressing the AMOC anomalies (in Sv) onto the normalized PC timeseries. The SST/TAS patterns associated with AMOC variations are created by regressing TAS/SST anomalies (in Celsius) at each grid box over the globe onto the normalized AMOC PC timeseries. A 15-point low-pass Lanczos filter is applied to the AMOC PC (and AMO) timeseries prior to computing lead/lag correlations, with a minimum of 90 years of data required. The data are not detrended (unlike Danabasoglu et al., 2012). See Danabasoglu, G., S. G. Yeager, Y. -O. Kwon, J. J. Tribbia, A. S. Phillips, and J. W. Hurrell, 2012. Variability of the Atlantic Meridional Overturning Circulation in CCSM4. J. Climate, 25, 5153-5172, doi: 10.1175/JCLI-D-11-00463.1.<br><br>For CCSM4 and CESM1, the MOC variable is read in, the Eulerian Mean, Eddy-Induced and Submeso components are summed, and the Atlantic Ocean + Mediterranean Sea + Labrador Sea + GIN Sea + Arctic Ocean + Hudson Bay transport region is selected. For CCSM2 and CCSM3 the same transport region is selected but only the Eulerian Mean component is used as that is all that is available. For CMIP5 (CMIP6) data the msftmyz (msftmz) variable is read in and the atlantic_arctic_ocean basin is used. For CMIP3 data, the stfmmc variable is read in and the atlantic_ocean geo_region is used.</td></tr>" 
  txt(53) = "<td>The Atlantic Meridional Overturning Circulation (AMOC) is defined as the oceanic meridional mass transport (Sv) in the Atlantic sector. To compute AMOC time series, we take the maximum meridional overturning streamfunction at 30oN, below 500m. This is a deviation from the original approach by Phillips et al (2014), which adopted the method of Danabasoglu et al (2012). This deviation is documented by Zhoa et al (2022), and was motivated by the past2k runs for which the EOF-based approach appears unhelpful. The AMOC patterns are created by regressing the AMOC anomalies (in Sv) onto the AMOC timeseries. The SST/TAS patterns associated with AMOC variations are created by regressing TAS/SST anomalies (in Celsius) at each grid box over the globe onto the AMOC timeseries. A 15-point low-pass Lanczos filter is applied to the AMOC (and AMO) timeseries prior to computing lead/lag correlations, with a minimum of 90 years of data required. The data are not detrended (unlike Danabasoglu et al., 2012). See Danabasoglu, G., S. G. Yeager, Y. -O. Kwon, J. J. Tribbia, A. S. Phillips, and J. W. Hurrell, 2012. Variability of the Atlantic Meridional Overturning Circulation in CCSM4. J. Climate, 25, 5153-5172, doi: 10.1175/JCLI-D-11-00463.1.<br><br>For CCSM4 and CESM1, the MOC variable is read in, the Eulerian Mean, Eddy-Induced and Submeso components are summed, and the Atlantic Ocean + Mediterranean Sea + Labrador Sea + GIN Sea + Arctic Ocean + Hudson Bay transport region is selected. For CCSM2 and CCSM3 the same transport region is selected but only the Eulerian Mean component is used as that is all that is available. For CMIP5 (CMIP6) data the msftmyz (msftmz) variable is read in and the atlantic_arctic_ocean basin is used. For CMIP3 data, the stfmmc variable is read in and the atlantic_ocean geo_region is used. See Zhao, A., Brierley, C. M., Jiang, Z., Eyles, R., Oyarzún, D., and Gomez-Dans, J.: Analysing the PMIP4-CMIP6 collection: a workflow and tool (pmip_p2fvar_analyzer v1), Geosci. Model Dev., 15, 2475-2488, https://doi.org/10.5194/gmd-15-2475-2022, 2022. </td></tr>" 

  txt(55) = "<tr><td><b>NAM</b> (Northern Annular Mode)</td>"  
  txt(56) = "<td>Seasonal/annual PSL averages are formed, square root of the cosine of the latitude weighting is applied, and then the leading EOF and associated principal component (PC) timeseries are computed over 20:90&deg;N, 0:360&deg;E. Pattern created by regressing global PSL anomalies (in hPa) onto normalized PC timeseries. Based on Hurrell, J. W., and C. Deser, 2009: North Atlantic climate variability: The role of the North Atlantic Oscillation. <i>J. Mar. Syst.</i>, 78, 28-41, doi:10.1016/j.jmarsys.2008.11.026. Also see Thompson, D. W. J., and J. M. Wallace, 2000: Annular modes in the extratropical circulation. Part I: Month-to-month variability. <i>J. Climate</i>, 13, 1000-1016.</td></tr>"  
  txt(57) = "<tr><td><b>NAO</b> (North Atlantic Oscillation)</td>"  
  txt(58) = "<td>Seasonal/annual PSL averages are formed, square root of the cosine of latitude weighting is applied, and then the leading EOF and associated principal component (PC) timeseries are computed over 20:80&deg;N, 90&deg;W:40&deg;E. Pattern created by regressing global PSL anomalies (in hPa) onto normalized PC timeseries. Based on Hurrell, J. W. and C. Deser, 2009: North Atlantic climate variability: The role of the North Atlantic Oscillation. <i>J. Mar. Syst.</i>, 78, 28-41, doi:10.1016/j.jmarsys.2008.11.026. For more information on the NAO see the <a href="+quote+"https://climatedataguide.ucar.edu/climate-data/hurrell-north-atlantic-oscillation-nao-index-pc-based?qt-climatedatasetmaintabs=1"+quote+" target="+quote+"_blank"+quote+">Climate Data Guide</a>.</td></tr>"  
  txt(59) = "<tr><td><b>SAM/PSA1/PSA2</b> (Southern Annular Mode, Pacific South American Patterns 1/2)</td>"  
  txt(60) = "<td>Seasonal/annual PSL averages are formed, square root of the cosine of latitude weighting is applied, and then the 1st (SAM), 2nd (PSA1) and 3rd (PSA2) EOFs and associated principal component (PC) timeseries are computed over 20:90&deg;S, 0:360&deg;E. Patterns created by regressing global PSL anomalies (in hPa) onto normalized PC timeseries. SAM calculation based on Thompson, D. W. J. and J.M. Wallace, 2000: Annular modes in the extratropical circulation. Part I: Month-to-month variability. <i>J. Climate</i>, 13, 1000-1016.</td></tr>"  
  txt(61) = "<tr><td><b>PNA/NPO</b> (Pacific North American Pattern, North Pacific Oscillation)</td>" 
  txt(62) = "<td>Seasonal/annual PSL averages are formed, the square root of the cosine of the latitude weighting is applied, and then the 1st (PNA) and 2nd (NPO) EOFs and associated principal component (PC) timeseries are computed over 20:85&deg;N, 120&deg;E:120&deg;W. Patterns created by regressing global PSL anomalies (in hPa) onto normalized PC timeseries.</td></tr>" 
  txt(63) = "<tr><td><b>SST Regressions</b></td>"
  txt(64) = "<td>SST anomalies (in Celsius) at each grid box are regressed upon the normalized atmospheric mode timeseries.</td></tr>" 
  txt(65) = "<tr><td><b>TAS Regressions</b></td>"
  txt(66) = "<td>TAS anomalies (in Celsius) at each grid box are regressed upon the normalized atmospheric mode timeseries.</td></tr>" 
  txt(67) = "<tr><td><b>PR Regressions</b></td>"
  txt(68) = "<td>PR anomalies (in mm/day) at each grid box are regressed upon the normalized atmospheric mode timeseries.</td></tr>" 
  txt(69) = "</table>"
  
  txt(80) = "<p class=subtitle>Climate Indices</p>"
  txt(81) = "<TABLE width='800' border=1 frame=void rules=all cellpadding=6 bordercolor=darkgray>"
  txt(82) = "<tr><td><b>Atlantic Meridional Mode</b></td>"
  txt(83) = "<td>Defined as the difference between area-averaged SST anomalies (in Celsius) computed over 5:15&deg;N, 20:50&deg;W and area-averaged SST anomalies computed over 5:15&deg;S, 20&degW:10&deg;E. Red/blue shading denotes positive/negative departures from the best-fit linear trend line. See Doi, T., T. Tozuka and T. Yamagata (2009), Interannual variability of the Guinea Dome and its possible link with the Atlantic Meridional Mode. Climate Dynamics, 33, 985-998, doi:10.1007/s00382-009-0574-z.</td></tr>"
  txt(84) = "<tr><td><b>Atlantic Ni&ntilde;o (ATL3)</b></td>"
  txt(85) = "<td>Area-averaged SST anomalies (in Celsius) computed over 3&deg;S:3&deg;N, 20&deg;W:0&deg;E. Red/blue shading denotes positive/negative departures from the best-fit linear trend line. See Zebiak, S. E., (1993): Air–sea interaction in the equatorial Atlantic region. Journal of Climate, 6, 1567–1586.</td></tr>"
  txt(86) = "<tr><td><b>Tropical North Atlantic SST</b></td>"
  txt(87) = "<td>Area-averaged SST anomalies (in Celsius) computed over 5.5:23.5&deg;N, 15:57.5&deg;W. Red/blue shading denotes positive/negative departures from the best-fit linear trend line. See Enfield, D.B., A.M. Mestas, D.A. Mayer, and L. Cid-Serrano (1999), How ubiquitous is the dipole relationship in tropical Atlantic sea surface temperatures?, JGR-O, 104, 7841-7848.</td></tr>"
  txt(88) = "<tr><td><b>Tropical South Atlantic SST</b></td>"
  txt(89) = "<td>Area-averaged SST anomalies (in Celsius) computed over 0:20&deg;S, 30&deg;W:10&deg;E. Red/blue shading denotes positive/negative departures from the best-fit linear trend line. See Enfield, D.B., A.M. Mestas, D.A. Mayer, and L. Cid-Serrano (1999), How ubiquitous is the dipole relationship in tropical Atlantic sea surface temperatures?, JGR-O, 104, 7841-7848.</td></tr>"
  txt(90) = "<tr><td><b>ni&ntilde;o1+2</b></td>"
  txt(91) = "<td>Area-averaged SST anomalies (in Celsius) computed over 0:10&deg;S, 80:90&deg;W. Red/blue shading denotes positive/negative departures from the best-fit linear trend line.</td></tr>"
  txt(92) = "<tr><td><b>ni&ntilde;o3</b></td>"
  txt(93) = "<td>Area-averaged SST anomalies (in Celsius) computed over 5&deg;S:5&deg;N, 90:150&deg;W. Red/blue shading denotes positive/negative departures from the best-fit linear trend line. See Trenberth, K. E. (1997) The Definition of El Niño. Bulletin of the American Meteorological Society, 78, 2771-2777.</td></tr>"
  txt(94) = "<tr><td><b>ni&ntilde;o3.4</b></td>"
  txt(95) = "<td>Area-averaged SST anomalies (in Celsius) computed over 5&deg;S:5&deg;N, 120:170&deg;W. Red/blue shading denotes positive/negative departures from the best-fit linear trend line. See Trenberth, K. E. (1997) The Definition of El Niño. Bulletin of the American Meteorological Society, 78, 2771-2777.</td></tr>"
  txt(96) = "<tr><td><b>ni&ntilde;o4</b></td>"
  txt(97) = "<td>Area-averaged SST anomalies (in Celsius) computed over 5&deg;S:5&deg;N, 160&deg;E:150&deg;W. Red/blue shading denotes positive/negative departures from the best-fit linear trend line.</td></tr>"
  txt(98) = "<tr><td><b>NPI</b> (North Pacific PSL Index)</td>"
  txt(99) = "<td>Winter (December-March) average PSL anomalies (in hPa) area-averaged over 30&deg;:65&deg;N, 160&deg;E:140&deg;W. Based on Trenberth, K. E. and J. W. Hurrell, 1994: Decadal atmosphere-ocean variations in the Pacific, <i>Climate Dynamics</i>, 9, 303-319.</td></tr>"    

  txt(100) = "<tr><td><b>Indian Ocean SST Dipole</b></td>"
  txt(101) = "<td>Defined as the difference between area-averaged SST anomalies (in Celsius) computed over 10&deg;S:10&deg;N, 50:70&deg;E and area-averaged SST anomalies computed over 0:10&deg;S, 90:110&deg;E. Red/blue shading denotes positive/negative departures from the best-fit linear trend line. See: Saji N.H., Goswami B.N., Vinayachandran P.N., Yamagata T., 1999: A dipole mode in the tropical Indian Ocean, Nature, 401, 360-363.</td></tr>"
  txt(102) = "<tr><td><b>Tropical Indian Ocean SST</b></td>"
  txt(103) = "<td>Area-averaged SST anomalies (in Celsius) computed over 15&deg;S:15&deg;N, 40:110&deg;E. Red/blue shading denotes positive/negative departures from the best-fit linear trend line.</td></tr>"
  txt(104)= "<tr><td><b>Southern Ocean SST</b></td>"
  txt(105)= "<td>Area-averaged SST anomalies (in Celsius) computed over 50&deg;:70&deg;S, 0:360&deg;E. Red/blue shading denotes positive/negative departures from the best-fit linear trend line.</td></tr>"
  txt(106) = "</table>"
  txt(107) = ""
  
  txt(112) = "<br>Created "+systemfunc("date")
  txt(113) = "<p class=btext>CVDP Version "+VERSION+"</p>"
  txt(114) = "</body></html>"
  
  tt = ind(.not.ismissing(txt))
  txt2 = txt(:tt(dimsizes(tt)-1)+1)
  txt2 = where(ismissing(txt2),"",txt2)
  asciiwrite(OUTDIR+"methodology.html",txt2)
  delete([/tt,txt,txt2/])
;----------------------------------------------------------------------------
;--   Create metrics webpage
;----------------------------------------------------------------------------
  if (isfilepresent2(OUTDIR+"metrics.txt")) then
     txt = new(500,"string")  
     quote = str_get_dq()
  
     txt(0) = "<html><head><title>Climate Variability Diagnostics Package</title>"
     txt(1) = "<link rel="+quote+"stylesheet"+quote+" href="+quote+"https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/css/bootstrap.min.css"+quote+" integrity="+quote+"sha384-MCw98/SFnGE8fJT3GXwEOngsV7Zt27NXFoaoApmYm81iuXoPkFOJwJ8ERdknLPMO"+quote+" crossorigin="+quote+"anonymous"+quote+">"
     txt(2) = "<script src="+quote+"https://code.jquery.com/jquery-3.3.1.slim.min.js"+quote+" integrity="+quote+"sha384-q8i/X+965DzO0rT7abK41JStQIAqVgRVzpbzo5smXKp4YfRvH+8abtTE1Pi6jizo"+quote+" crossorigin="+quote+"anonymous"+quote+"></script>"
     txt(3) = "<script src="+quote+"https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.14.3/umd/popper.min.js"+quote+" integrity="+quote+"sha384-ZMP7rVo3mIykV+2+9J3UJ46jBk0WLaUAdn689aCwoqbBJiSnjAK/l8WvCWPIPm49"+quote+" crossorigin="+quote+"anonymous"+quote+"></script>"
     txt(4) = "<script src="+quote+"https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/js/bootstrap.min.js"+quote+" integrity="+quote+"sha384-ChfqqxuZUCnJSK3+MXmPNIyE6ZbWh2IMqE241rYiqJxyMiZ6OW/JmZQ5stwEULTy"+quote+" crossorigin="+quote+"anonymous"+quote+"></script>"

     txt(5) = "<style>body {background-color: WhiteSmoke; font-family: Verdana, Geneva, sans-serif}"
     txt(6) = "img.title {width:990; height:105; align:left}"
     txt(7) = "p.subtitle1 {font-size:15pt; color:gray}"
     txt(8) = "p.subtitle {font-size:20pt; color:black; text-align:center; font-weight:bold}"
     txt(9) = "p.btext {font-size:12pt; text-align:left}"
     txt(10) = "p.btext2 {font-size:9pt; text-align:left}"
     txt(11) = "td {text-align:center; font-size:12pt}"
     txt(12) = "td.s1 {text-align:left; font-size:11pt}"
     txt(13) = "CAPTION {text-align:left; font-size:14pt; font-weight:bold}"
     txt(14) = "</style></head><BODY>"
     txt(15) = "<img class=title src="+quote+"cas-cvdp.png"+quote+" alt="+quote+"CVDP logo"+quote+">"
     txt(16)= "<TABLE width='990' border=0 cellpadding=6>"
     txt(17) = "<tr><td width='300'><p class=btext><a href="+quote+"index.html"+quote+">Back to Diagnostics Plots</a></p></td>"
     txt(18) = "<td><p class=subtitle>"+webtitle+"</p></td></tr></table><hr width=990 align=left><p class=subtitle1>Metrics Table</p>" 
     
     z = asciiread(OUTDIR+"metrics.txt",(/-1/),"string")
     nlines = dimsizes(z)
     txt(24) = "<PRE>"
     do gg = 0,nlines-1
        txt(25+gg) = z(gg)
     end do
     txt(25+nlines) = "</PRE>"
     txt(25+nlines+1) = "<p class=btext><a href="+quote+"namelist_obs"+quote+">Observations Used</a></p>"
     txt(25+nlines+2) = "Created "+systemfunc("date")
     txt(25+nlines+3) = "<p class=btext2>CVDP Version "+VERSION+"</p></body></html>"
  
     tt = ind(.not.ismissing(txt))
     txt2 = txt(:tt(dimsizes(tt)-1)+1)
     txt2 = where(ismissing(txt2),"",txt2)
     asciiwrite(OUTDIR+"metrics.html",txt2)
     delete([/txt,txt2,tt/])
  end if 
  if (isfilepresent2(OUTDIR+"metrics.table_1.gif")) then  ; create sorted metrics table pages
     txt = new(500,"string")  
     quote = str_get_dq()
  
     txt(0) = "<html><head><title>Climate Variability Diagnostics Package</title>"
     txt(1) = "<link rel="+quote+"stylesheet"+quote+" href="+quote+"https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/css/bootstrap.min.css"+quote+" integrity="+quote+"sha384-MCw98/SFnGE8fJT3GXwEOngsV7Zt27NXFoaoApmYm81iuXoPkFOJwJ8ERdknLPMO"+quote+" crossorigin="+quote+"anonymous"+quote+">"
     txt(2) = "<script src="+quote+"https://code.jquery.com/jquery-3.3.1.slim.min.js"+quote+" integrity="+quote+"sha384-q8i/X+965DzO0rT7abK41JStQIAqVgRVzpbzo5smXKp4YfRvH+8abtTE1Pi6jizo"+quote+" crossorigin="+quote+"anonymous"+quote+"></script>"
     txt(3) = "<script src="+quote+"https://cdnjs.cloudflare.com/ajax/libs/popper.js/1.14.3/umd/popper.min.js"+quote+" integrity="+quote+"sha384-ZMP7rVo3mIykV+2+9J3UJ46jBk0WLaUAdn689aCwoqbBJiSnjAK/l8WvCWPIPm49"+quote+" crossorigin="+quote+"anonymous"+quote+"></script>"
     txt(4) = "<script src="+quote+"https://stackpath.bootstrapcdn.com/bootstrap/4.1.3/js/bootstrap.min.js"+quote+" integrity="+quote+"sha384-ChfqqxuZUCnJSK3+MXmPNIyE6ZbWh2IMqE241rYiqJxyMiZ6OW/JmZQ5stwEULTy"+quote+" crossorigin="+quote+"anonymous"+quote+"></script>"

     txt(5) = "<style>body {background-color: WhiteSmoke; font-family: Verdana, Geneva, sans-serif}"
     txt(6) = "img.title {width:990; height:105; align:left}"
     txt(7) = "p.subtitle1 {font-size:20pt; color:darkgray}"
     txt(8) = "p.subtitle {font-size:20pt; color:black; text-align:center; font-weight:bold}"
     txt(9) = "p.btext {font-size:12pt; text-align:left}"
     txt(10) = "p.btext2 {font-size:9pt; text-align:left}"
     txt(11) = "td {text-align:center; font-size:12pt}"
     txt(12) = "td.s1 {text-align:left; font-size:11pt}"
     txt(13) = "td.tablehdr {text-align:center; font-size:17pt}"
     txt(14) = "CAPTION {text-align:left; font-size:14pt; font-weight:bold}</style></head><BODY>"
     txt(15) = "<img class=title src="+quote+"cas-cvdp.png"+quote+" alt="+quote+"CVDP logo"+quote+">"
     txt(16)= "<TABLE width='990' border=0 cellpadding=6>"


     sort_txt = (/"<a href="+quote+"metrics.table_0.html"+quote+">Namelist (default)</a> | ","<a href="+quote+"metrics.table_1.html"+quote+">Namelist (Alphabetically)</a> | ","<a href="+quote+"metrics.table_2.html"+quote+">ENSO TAS</a> | ","<a href="+quote+"metrics.table_3.html"+quote+">ENSO PSL</a> | ", \
                  "<a href="+quote+"metrics.table_4.html"+quote+">El Ni&ntilde;o Hovm&ouml;ller</a><br>","<a href="+quote+"metrics.table_5.html"+quote+">La Ni&ntilde;a Hovm&ouml;ller</a> | ","<a href="+quote+"metrics.table_6.html"+quote+">AMO</a> | ","<a href="+quote+"metrics.table_7.html"+quote+">PDO</a> | ", \
                  "<a href="+quote+"metrics.table_8.html"+quote+">NAM</a> | ","<a href="+quote+"metrics.table_9.html"+quote+">SAM</a> | ","<a href="+quote+"metrics.table_10.html"+quote+">SST std dev</a> | ","<a href="+quote+"metrics.table_11.html"+quote+">PSL std dev</a> | ", \
                  "<a href="+quote+"metrics.table_12.html"+quote+">PR std dev</a> | ","<a href="+quote+"metrics.table_13.html"+quote+">Mean Score</a>"/)
     sort_txt2 = (/"Namelist (default)","Namelist (Alphabetically)","ENSO TAS","ENSO PSL","El Ni&ntilde;o Hovm&ouml;ller","La Ni&ntilde;a Hovm&ouml;ller","AMO","PDO","NAM","SAM","SST std dev","PSL std dev","PR std dev","Mean Score"/)

     sort_txtA = (/"<a href="+quote+"metrics.table_14.html"+quote+">Namelist (default)</a> | ","<a href="+quote+"metrics.table_15.html"+quote+">Namelist (Alphabetically)</a> | ","<a href="+quote+"metrics.table_16.html"+quote+">ENSO TAS</a> | ","<a href="+quote+"metrics.table_17.html"+quote+">ENSO PSL</a> | ", \
                  "<a href="+quote+"metrics.table_18.html"+quote+">El Ni&ntilde;o Hovm&ouml;ller</a><br>","<a href="+quote+"metrics.table_19.html"+quote+">La Ni&ntilde;a Hovm&ouml;ller</a> | ","<a href="+quote+"metrics.table_20.html"+quote+">AMO</a> | ","<a href="+quote+"metrics.table_21.html"+quote+">PDO</a> | ", \
                  "<a href="+quote+"metrics.table_22.html"+quote+">NAM</a> | ","<a href="+quote+"metrics.table_23.html"+quote+">SAM</a> | ","<a href="+quote+"metrics.table_24.html"+quote+">SST std dev</a> | ","<a href="+quote+"metrics.table_25.html"+quote+">PSL std dev</a> | ", \
                  "<a href="+quote+"metrics.table_26.html"+quote+">PR std dev</a> | ","<a href="+quote+"metrics.table_27.html"+quote+">Mean Score</a>"/)

     strarr = new(14,string)
     strarr = " | "
     strarr(13) = " "
     do gg = 0,13
           txt(17) = "<tr><td width='50'><p class=btext>Go to:</p></td><td class=s1 width='300'><a href="+quote+"methodology.html"+quote+">Methodology and Definitions</a><br><a href="+quote+"index.html"+quote+">Diagnostics Plots</a><br><a href="+quote+"metrics.table_"+(gg+14)+".html"+quote+">RMS Metric Tables</a></td>"
           txt(18) = "<td><p class=subtitle>"+webtitle+"</p></td></tr></table><hr width=990 align=left>"
           sort_txtT = sort_txt
           sort_txtT(gg) = "<b>"+sort_txt2(gg)+"</b>"+strarr(gg)
           txt(24) = "<p class=subtitle1><b>Pattern Correlation Metrics Tables</b></p>"
           txt(25) = "<TABLE width='900' border=0 cellpadding=16><tr><td width=50><b>Sort By:</b></td><td>"+str_concat(sort_txtT)+"</td></tr></table>" 
           txt(26) = "<img width=980 src="+quote+"metrics.table_"+gg+".gif"+quote+" />"
           txt(27) = "<p class=btext><a href="+quote+"namelist_obs"+quote+">Observations Used</a></p>"
           txt(28) = "Created "+systemfunc("date")
           txt(29) = "<p class=btext2>CVDP Version "+VERSION+"</p></body></html>"
           tt = ind(.not.ismissing(txt))
           txt2 = txt(:tt(dimsizes(tt)-1)+1)
           txt2 = where(ismissing(txt2),"",txt2)
           asciiwrite(OUTDIR+"metrics.table_"+gg+".html",txt2)
           delete([/txt2,tt,sort_txtT/])
     end do

     
     do gg = 0,13
           txt(17) = "<tr><td width='50'><p class=btext>Go to:</p></td><td class=s1 width='300'><a href="+quote+"methodology.html"+quote+">Methodology and Definitions</a><br><a href="+quote+"index.html"+quote+">Diagnostics Plots</a><br><a href="+quote+"metrics.table_"+gg+".html"+quote+">Pattern Correlation Metric Tables</a></td>"
           txt(18) = "<td><p class=subtitle>"+webtitle+"</p></td></tr></table><hr width=990 align=left>"
           sort_txtT = sort_txtA
           sort_txtT(gg) = "<b>"+sort_txt2(gg)+"</b>"+strarr(gg)
           txt(24) = "<p class=subtitle1><b>RMS Metrics Tables</b></p>"
           txt(25) = "<TABLE width='900' border=0 cellpadding=16><tr><td width=50><b>Sort By:</b></td><td>"+str_concat(sort_txtT)+"</td></tr></table>"
           txt(26) = "<img width=980 src="+quote+"metrics.table_"+(gg+14)+".gif"+quote+" />"
           txt(27) = "<p class=btext><a href="+quote+"namelist_obs"+quote+">Observations Used</a></p>"
           txt(28) = "Created "+systemfunc("date")
           txt(29) = "<p class=btext2>CVDP Version "+VERSION+"</p></body></html>"
           tt = ind(.not.ismissing(txt))
           txt2 = txt(:tt(dimsizes(tt)-1)+1)
           txt2 = where(ismissing(txt2),"",txt2)
           asciiwrite(OUTDIR+"metrics.table_"+(gg+14)+".html",txt2)
           delete([/txt2,tt/])
     end do
     delete([/txt,strarr/])
  end if
;----------------------------------------------------------------------------
; Namelist pages
  txt := new(500,"string")  
  
  txt(0) = "<HTML><HEAD><TITLE>Climate Variability Diagnostics Package</TITLE><STYLE>"
  txt(1) = "body {background-color: WhiteSmoke; font-family: Verdana, Geneva, sans-serif}"
  txt(2) = "img.title {width:990; height:105; align:left}"
  txt(3) = "p.subtitle1 {font-size:20pt; color:darkgray}"
  txt(4) = "p.subtitle {font-size:20pt; color:black; text-align:center; font-weight:bold}"
  txt(5) = "p.btext {font-size:12pt; text-align:left}"
  txt(6) = "p.btext2 {font-size:9pt; text-align:left}"
  txt(7) = "p.c {font-size:9pt; text-align:left, white-space:pre}"
  txt(9) = "td.s1 {text-align:left; font-size:11pt}"
  
  txt(20) = "td {text-align:center; font-size:12pt}"
  txt(21) = "td.s1 {text-align:left; font-size:11pt}"
  txt(22) = "td.tablehdr {text-align:center; font-size:17pt}"
  txt(23) = "CAPTION {text-align:left; font-size:14pt; font-weight:bold}"
  txt(24) = "</STYLE></HEAD><BODY>"
  txt(25) = "<img class="+quote+"img-fluid"+quote+" src="+quote+"cas-cvdp.png"+quote+" alt="+quote+"CVDP logo"+quote+">"
  txt(26)= "<TABLE width='990' border=0 cellpadding=6>"
  txt(27) = "<tr><td width='30'><p class=btext>Go to:</p></td><td class=s1 width='380'><a href="+quote+"index.html"+quote+">Diagnostics Plots</a><br><hr>"

  namelist_obs_qtxt = "Input Namelists: "
  if (OBS.eq."True") then
     txt(28) = "Input Namelists: <b>Observations</b> | <a href="+quote+"namelist_simulations.html"+quote+">Simulations</a><br>"
     txt(29) = "Derived Namelists: <a href="+quote+"namelist_msftmz.html"+quote+">MSFTMZ</a> | <a href="+quote+"namelist_pr.html"+quote+">PR</a> | <a href="+quote+"namelist_psl.html"+quote+">PSL</a> | "
     txt(30) = "<br><a href="+quote+"namelist_siconc_nh.html"+quote+">SICONC NH</a> | <a href="+quote+"namelist_siconc_sh.html"+quote+">SICONC SH</a> | <a href="+quote+"namelist_snd.html"+quote+">SND</a> | <a href="+quote+"namelist_tas.html"+quote+">TAS</a> |"
     txt(31) = "<a href="+quote+"namelist_ts.html"+quote+">TS</a></td><td><h2 class="+quote+"text-center"+quote+">"+webtitle+"</h2></td></tr></table><hr width=990 align=left>"
     txt(32) = "<p class=subtitle1>Input Namelist: Observations</p>" 
     z := asciiread(OUTDIR+"namelist_obs",(/-1/),"string")
     nlines = dimsizes(z)
     txt(33) = "<p class=c>"
     do gg = 0,nlines-1
        txt(33+gg) = z(gg)+"<br>"
     end do
     txt(34+nlines) = "</p>"
     txt(34+nlines+1) = "Created "+systemfunc("date")
     txt(34+nlines+2) = "<p class=btext2>CVDP Version "+VERSION+"</p></body></html>"
     tt := ind(.not.ismissing(txt))
     txt2 := txt(:tt(dimsizes(tt)-1)+1)
     txt2 = where(ismissing(txt2),"",txt2)
     asciiwrite(OUTDIR+"namelist_obs.html",txt2)

     namelist_obs_qtxt = "Input Namelists: <a href="+quote+"namelist_obs.html"+quote+">Observations</a> | "
  end if
  txt(28:) = txt@_FillValue

  txt(28) = namelist_obs_qtxt+"<b>Simulations</b><br>"
  txt(29) = "Derived Namelists: <a href="+quote+"namelist_msftmz.html"+quote+">MSFTMZ</a> | <a href="+quote+"namelist_pr.html"+quote+">PR</a> | <a href="+quote+"namelist_psl.html"+quote+">PSL</a> | "
  txt(30) = "<br><a href="+quote+"namelist_siconc_nh.html"+quote+">SICONC NH</a> | <a href="+quote+"namelist_siconc_sh.html"+quote+">SICONC SH</a> | <a href="+quote+"namelist_snd.html"+quote+">SND</a> | <a href="+quote+"namelist_tas.html"+quote+">TAS</a> |"
  txt(31) = "<a href="+quote+"namelist_ts.html"+quote+">TS</a></td><td><h2 class="+quote+"text-center"+quote+">"+webtitle+"</h2></td></tr></table><hr width=990 align=left>"
  txt(32) = "<p class=subtitle1>Input Namelist: Simulations</p>" 
  z := asciiread(OUTDIR+"namelist",(/-1/),"string")
  nlines = dimsizes(z)
  txt(33) = "<p class=c>"
  do gg = 0,nlines-1
     txt(33+gg) = z(gg)+"<br>"
  end do
  txt(34+nlines) = "</p>"
  txt(34+nlines+1) = "Created "+systemfunc("date")
  txt(34+nlines+2) = "<p class=btext2>CVDP Version "+VERSION+"</p></body></html>"
  tt := ind(.not.ismissing(txt))
  txt2 := txt(:tt(dimsizes(tt)-1)+1)
  txt2 = where(ismissing(txt2),"",txt2)
  asciiwrite(OUTDIR+"namelist_simulations.html",txt2)
  txt(28:) = txt@_FillValue

  txt(28) = namelist_obs_qtxt+"<a href="+quote+"namelist_simulations.html"+quote+">Simulations</a><br>"
  txt(29) = "Derived Namelists: <b>MSFTMZ</b> | <a href="+quote+"namelist_pr.html"+quote+">PR</a> | <a href="+quote+"namelist_psl.html"+quote+">PSL</a> | "
  txt(30) = "<br><a href="+quote+"namelist_siconc_nh.html"+quote+">SICONC NH</a> | <a href="+quote+"namelist_siconc_sh.html"+quote+">SICONC SH</a> | <a href="+quote+"namelist_snd.html"+quote+">SND</a> | <a href="+quote+"namelist_tas.html"+quote+">TAS</a> |"
  txt(31) = "<a href="+quote+"namelist_ts.html"+quote+">TS</a></td><td><h2 class="+quote+"text-center"+quote+">"+webtitle+"</h2></td></tr></table><hr width=990 align=left>"
  txt(32) = "<p class=subtitle1>Derived Namelist: MSFTMZ</p>" 
  z := asciiread(OUTDIR+"namelist_moc",(/-1/),"string")
  nlines = dimsizes(z)
  txt(33) = "<p class=c>"
  do gg = 0,nlines-1
     txt(33+gg) = z(gg)+"<br>"
  end do
  txt(34+nlines) = "</p>"
  txt(34+nlines+1) = "Created "+systemfunc("date")
  txt(34+nlines+2) = "<p class=btext2>CVDP Version "+VERSION+"</p></body></html>"
  tt := ind(.not.ismissing(txt))
  txt2 := txt(:tt(dimsizes(tt)-1)+1)
  txt2 = where(ismissing(txt2),"",txt2)
  asciiwrite(OUTDIR+"namelist_msftmz.html",txt2)

  txt(28) = namelist_obs_qtxt+"<a href="+quote+"namelist_simulations.html"+quote+">Simulations</a><br>"
  txt(29) = "Derived Namelists: <a href="+quote+"namelist_msftmz.html"+quote+">MSFTMZ</a> | <b>PR</b> | <a href="+quote+"namelist_psl.html"+quote+">PSL</a> | "
  txt(30) = "<br><a href="+quote+"namelist_siconc_nh.html"+quote+">SICONC NH</a> | <a href="+quote+"namelist_siconc_sh.html"+quote+">SICONC SH</a> | <a href="+quote+"namelist_snd.html"+quote+">SND</a> | <a href="+quote+"namelist_tas.html"+quote+">TAS</a> |"
  txt(31) = "<a href="+quote+"namelist_ts.html"+quote+">TS</a></td><td><h2 class="+quote+"text-center"+quote+">"+webtitle+"</h2></td></tr></table><hr width=990 align=left>"
  txt(32) = "<p class=subtitle1>Derived Namelist: PR</p>" 
  z := asciiread(OUTDIR+"namelist_prect",(/-1/),"string")
  nlines = dimsizes(z)
  txt(33) = "<p class=c>"
  do gg = 0,nlines-1
     txt(33+gg) = z(gg)+"<br>"
  end do
  txt(34+nlines) = "</p>"
  txt(34+nlines+1) = "Created "+systemfunc("date")
  txt(34+nlines+2) = "<p class=btext2>CVDP Version "+VERSION+"</p></body></html>"
  tt := ind(.not.ismissing(txt))
  txt2 := txt(:tt(dimsizes(tt)-1)+1)
  txt2 = where(ismissing(txt2),"",txt2)
  asciiwrite(OUTDIR+"namelist_pr.html",txt2)

  txt(28) = namelist_obs_qtxt+"<a href="+quote+"namelist_simulations.html"+quote+">Simulations</a><br>"
  txt(29) = "Derived Namelists: <a href="+quote+"namelist_msftmz.html"+quote+">MSFTMZ</a> | <a href="+quote+"namelist_pr.html"+quote+">PR</a> | <b>PSL</b> | "
  txt(30) = "<br><a href="+quote+"namelist_siconc_nh.html"+quote+">SICONC NH</a> | <a href="+quote+"namelist_siconc_sh.html"+quote+">SICONC SH</a> | <a href="+quote+"namelist_snd.html"+quote+">SND</a> | <a href="+quote+"namelist_tas.html"+quote+">TAS</a> |"
  txt(31) = "<a href="+quote+"namelist_ts.html"+quote+">TS</a></td><td><h2 class="+quote+"text-center"+quote+">"+webtitle+"</h2></td></tr></table><hr width=990 align=left>"
  txt(32) = "<p class=subtitle1>Derived Namelist: PSL</p>" 
  z := asciiread(OUTDIR+"namelist_psl",(/-1/),"string")
  nlines = dimsizes(z)
  txt(33) = "<p class=c>"
  do gg = 0,nlines-1
     txt(33+gg) = z(gg)+"<br>"
  end do
  txt(34+nlines) = "</p>"
  txt(34+nlines+1) = "Created "+systemfunc("date")
  txt(34+nlines+2) = "<p class=btext2>CVDP Version "+VERSION+"</p></body></html>"
  tt := ind(.not.ismissing(txt))
  txt2 := txt(:tt(dimsizes(tt)-1)+1)
  txt2 = where(ismissing(txt2),"",txt2)
  asciiwrite(OUTDIR+"namelist_psl.html",txt2)

  txt(28) = namelist_obs_qtxt+"<a href="+quote+"namelist_simulations.html"+quote+">Simulations</a><br>"
  txt(29) = "Derived Namelists: <a href="+quote+"namelist_msftmz.html"+quote+">MSFTMZ</a> | <a href="+quote+"namelist_pr.html"+quote+">PR</a> | <a href="+quote+"namelist_psl.html"+quote+">PSL</a> | "
  txt(30) = "<br></b>SICONC NH</b> | <a href="+quote+"namelist_siconc_sh.html"+quote+">SICONC SH</a> | <a href="+quote+"namelist_snd.html"+quote+">SND</a> | <a href="+quote+"namelist_tas.html"+quote+">TAS</a> |"
  txt(31) = "<a href="+quote+"namelist_ts.html"+quote+">TS</a></td><td><h2 class="+quote+"text-center"+quote+">"+webtitle+"</h2></td></tr></table><hr width=990 align=left>"
  txt(32) = "<p class=subtitle1>Derived Namelist: SICONC NH</p>" 
  z := asciiread(OUTDIR+"namelist_aice_nh",(/-1/),"string")
  nlines = dimsizes(z)
  txt(33) = "<p class=c>"
  do gg = 0,nlines-1
     txt(33+gg) = z(gg)+"<br>"
  end do
  txt(34+nlines) = "</p>"
  txt(34+nlines+1) = "Created "+systemfunc("date")
  txt(34+nlines+2) = "<p class=btext2>CVDP Version "+VERSION+"</p></body></html>"
  tt := ind(.not.ismissing(txt))
  txt2 := txt(:tt(dimsizes(tt)-1)+1)
  txt2 = where(ismissing(txt2),"",txt2)
  asciiwrite(OUTDIR+"namelist_siconc_nh.html",txt2)

  txt(28) = namelist_obs_qtxt+"<a href="+quote+"namelist_simulations.html"+quote+">Simulations</a><br>"
  txt(29) = "Derived Namelists: <a href="+quote+"namelist_msftmz.html"+quote+">MSFTMZ</a> | <a href="+quote+"namelist_pr.html"+quote+">PR</a> | <a href="+quote+"namelist_psl.html"+quote+">PSL</a> | "
  txt(30) = "<br><a href="+quote+"namelist_siconc_nh.html"+quote+">SICONC NH</a> | <b>SICONC SH</b> | <a href="+quote+"namelist_snd.html"+quote+">SND</a> | <a href="+quote+"namelist_tas.html"+quote+">TAS</a> |"
  txt(31) = "<a href="+quote+"namelist_ts.html"+quote+">TS</a></td><td><h2 class="+quote+"text-center"+quote+">"+webtitle+"</h2></td></tr></table><hr width=990 align=left>"
  txt(32) = "<p class=subtitle1>Derived Namelist: SICONC SH</p>" 
  z := asciiread(OUTDIR+"namelist_aice_sh",(/-1/),"string")
  nlines = dimsizes(z)
  txt(33) = "<p class=c>"
  do gg = 0,nlines-1
     txt(33+gg) = z(gg)+"<br>"
  end do
  txt(34+nlines) = "</p>"
  txt(34+nlines+1) = "Created "+systemfunc("date")
  txt(34+nlines+2) = "<p class=btext2>CVDP Version "+VERSION+"</p></body></html>"
  tt := ind(.not.ismissing(txt))
  txt2 := txt(:tt(dimsizes(tt)-1)+1)
  txt2 = where(ismissing(txt2),"",txt2)
  asciiwrite(OUTDIR+"namelist_siconc_sh.html",txt2)

  txt(28) = namelist_obs_qtxt+"<a href="+quote+"namelist_simulations.html"+quote+">Simulations</a><br>"
  txt(29) = "Derived Namelists: <a href="+quote+"namelist_msftmz.html"+quote+">MSFTMZ</a> | <a href="+quote+"namelist_pr.html"+quote+">PR</a> | <a href="+quote+"namelist_psl.html"+quote+">PSL</a> | "
  txt(30) = "<br><a href="+quote+"namelist_siconc_nh.html"+quote+">SICONC NH</a> | <a href="+quote+"namelist_siconc_sh.html"+quote+">SICONC SH</a> | <b>SND</b> | <a href="+quote+"namelist_tas.html"+quote+">TAS</a> |"
  txt(31) = "<a href="+quote+"namelist_ts.html"+quote+">TS</a></td><td><h2 class="+quote+"text-center"+quote+">"+webtitle+"</h2></td></tr></table><hr width=990 align=left>"
  txt(32) = "<p class=subtitle1>Derived Namelist: SND</p>" 
  z := asciiread(OUTDIR+"namelist_snowdp",(/-1/),"string")
  nlines = dimsizes(z)
  txt(33) = "<p class=c>"
  do gg = 0,nlines-1
     txt(33+gg) = z(gg)+"<br>"
  end do
  txt(34+nlines) = "</p>"
  txt(34+nlines+1) = "Created "+systemfunc("date")
  txt(34+nlines+2) = "<p class=btext2>CVDP Version "+VERSION+"</p></body></html>"
  tt := ind(.not.ismissing(txt))
  txt2 := txt(:tt(dimsizes(tt)-1)+1)
  txt2 = where(ismissing(txt2),"",txt2)
  asciiwrite(OUTDIR+"namelist_snd.html",txt2)

  txt(28) = namelist_obs_qtxt+"<a href="+quote+"namelist_simulations.html"+quote+">Simulations</a><br>"
  txt(29) = "Derived Namelists: <a href="+quote+"namelist_msftmz.html"+quote+">MSFTMZ</a> | <a href="+quote+"namelist_pr.html"+quote+">PR</a> | <a href="+quote+"namelist_psl.html"+quote+">PSL</a> | "
  txt(30) = "<br><a href="+quote+"namelist_siconc_nh.html"+quote+">SICONC NH</a> | <a href="+quote+"namelist_siconc_sh.html"+quote+">SICONC SH</a> | <a href="+quote+"namelist_snd.html"+quote+">SND</a> | <b>TAS</b> |"
  txt(31) = "<a href="+quote+"namelist_ts.html"+quote+">TS</a></td><td><h2 class="+quote+"text-center"+quote+">"+webtitle+"</h2></td></tr></table><hr width=990 align=left>"
  txt(32) = "<p class=subtitle1>Derived Namelist: TAS</p>" 
  z := asciiread(OUTDIR+"namelist_trefht",(/-1/),"string")
  nlines = dimsizes(z)
  txt(33) = "<p class=c>"
  do gg = 0,nlines-1
     txt(33+gg) = z(gg)+"<br>"
  end do
  txt(34+nlines) = "</p>"
  txt(34+nlines+1) = "Created "+systemfunc("date")
  txt(34+nlines+2) = "<p class=btext2>CVDP Version "+VERSION+"</p></body></html>"
  tt := ind(.not.ismissing(txt))
  txt2 := txt(:tt(dimsizes(tt)-1)+1)
  txt2 = where(ismissing(txt2),"",txt2)
  asciiwrite(OUTDIR+"namelist_tas.html",txt2)

  txt(28) = namelist_obs_qtxt+"<a href="+quote+"namelist_simulations.html"+quote+">Simulations</a><br>"
  txt(29) = "Derived Namelists: <a href="+quote+"namelist_msftmz.html"+quote+">MSFTMZ</a> | <a href="+quote+"namelist_pr.html"+quote+">PR</a> | <a href="+quote+"namelist_psl.html"+quote+">PSL</a> | "
  txt(30) = "<br><a href="+quote+"namelist_siconc_nh.html"+quote+">SICONC NH</a> | <a href="+quote+"namelist_siconc_sh.html"+quote+">SICONC SH</a> | <a href="+quote+"namelist_snd.html"+quote+">SND</a> | <a href="+quote+"namelist_tas.html"+quote+">TAS</a> |"
  txt(31) = "<b>TS</b></td><td><h2 class="+quote+"text-center"+quote+">"+webtitle+"</h2></td></tr></table><hr width=990 align=left>"
  txt(32) = "<p class=subtitle1>Derived Namelist: TS</p>" 
  z := asciiread(OUTDIR+"namelist_ts",(/-1/),"string")
  nlines = dimsizes(z)
  txt(33) = "<p class=c>"
  do gg = 0,nlines-1
     txt(33+gg) = z(gg)+"<br>"
  end do
  txt(34+nlines) = "</p>"
  txt(34+nlines+1) = "Created "+systemfunc("date")
  txt(34+nlines+2) = "<p class=btext2>CVDP Version "+VERSION+"</p></body></html>"
  tt := ind(.not.ismissing(txt))
  txt2 := txt(:tt(dimsizes(tt)-1)+1)
  txt2 = where(ismissing(txt2),"",txt2)
  asciiwrite(OUTDIR+"namelist_ts.html",txt2)

  print("Finished: webpage.ncl")  
end


