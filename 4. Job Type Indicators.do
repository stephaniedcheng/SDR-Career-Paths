/* 4. CREATE JOB TYPE INDICATORS
Name: Stephanie D. Cheng
Date Created: 12-3-18
Date Updated: 2-10-19

This .do file takes the datasets created in DRF and SDR Job Identifiers, then
creates indicators for the type of job they're in each year.

*/

global MAIN "H:/SDC_Postdocs"
global DATA "${MAIN}/Data"
global RESULTS "${MAIN}/Results"
global TEMP "${MAIN}/Temp"

*** 1. COMBINE DRF AND SDR DATA ***
use "${DATA}/DRF_JobTypes.dta", clear
merge 1:m refid using "${DATA}/SDR_JobTypes.dta"
rename _merge _mergeSDR

// Last survey had info
bys refid: egen max_refyr = max(refyr)
replace max_refyr = 0 if max_refyr==.	// that means never appears in the SDR

save "${DATA}/DRF_SDR_FULL.dta", replace

*** 2. ADD INDICATORS ***
use "${DATA}/DRF_SDR_FULL.dta", clear

// Create indicators for each job type for each year
foreach i in PD AC TE GV ID NP UN NL {

	// Create first-pass indicator
	forvalues yr = 1942(1)2015 {
	
		// 1st indicator: New job -> strtyr for PD, AC, GV, ID, NP; lwyr for UN, NL
		gen `i'1i`yr'_t = 6*(`i'==1 & (strtyr==`yr' | lwyr==`yr'-1))
		
		// 2nd indicator: From postdoc retrospective data -> should only be PD, since others don't have endyr
		gen `i'2i`yr'_t = 5*(`i'==1 & strtyr<=`yr' & endyr>=`yr' & endyr!=.)
		
		// 3rd indicator: In job at time of survey; fill in from startyr
		gen `i'3i`yr'_t = 4*(`i'==1 & strtyr<=`yr' & refyr>=`yr' & endyr==.)
		
		// 4th indicator: Last time worked -> should only be UN, NL since others don't have lwyr
		gen `i'4i`yr'_t = 3*(`i'==1 & lwyr<=`yr' & refyr>=`yr')
		
		// 5th indicator: In same job since last survey -> should only be PD, AD, GV, ID, NP since others have emsmi=="L"
		gen `i'5i`yr'_t = 0
		replace `i'5i`yr'_t = 2 if `i'==1 & emsmi_yr<=`yr' & refyr>=`yr' & emsmi=="1"	// same job, same employer
		replace `i'5i`yr'_t = 1.9 if `i'==1 & emsmi_yr<=`yr' & refyr>=`yr' & emsmi=="3"	// same job, different employer
		replace `i'5i`yr'_t = 1.8 if `i'==1 & emsmi_yr<=`yr' & refyr>=`yr' & (emsmi=="2" | emsmi=="Y") 	// same employer, unclear if same job
	
		// 6th indicator: Expected to be in job from DRF -> should be all but UN, which = . for all
		gen `i'6i`yr'_t = 1*(`i'0i==1 & `yr'==phdcy_min) 	// now have it for the year that you graduated (use to do year you graduated and next year, but that overcounts)
		
		// Take the max for each row
		gen `i'i`yr'_T = max(`i'1i`yr'_t, `i'2i`yr'_t, `i'3i`yr'_t, `i'4i`yr'_t, `i'5i`yr'_t, `i'6i`yr'_t)
			
		// Take the max for same refid
		bys refid: egen `i'i`yr' = max(`i'i`yr'_T)
	
		// Replace 0s with . if shouldn't have any data for it
		replace `i'i`yr' = . if `i'i`yr'==0 & `yr'<phdcy_min	// before PhD
		replace `i'i`yr' = . if `i'i`yr'==0 & `yr'>max_refyr	// after last time in survey
		
	}
}

	// Clean up
	drop AC*_t TE*_t GV*_t ID*_t NP*_t UN*_t NL*_t *_T
	sort refid refyr

	// 7th Indicator: If no info in that year (and no end date from previous year), denote 0.5 for middle year in before year's job type
	
		// Determine if no job info in that year
		forvalues yr = 1942(1)2015 {
			egen anyInfo_t`yr' = rowtotal(PDi`yr' ACi`yr' TEi`yr' GVi`yr' IDi`yr' NPi`yr' UNi`yr' NLi`yr')
			gen NIi`yr' = (anyInfo_t`yr'==0)
				replace NIi`yr' = . if `yr'<phdcy_min | `yr'>max_refyr	// replace if don't have any data for those years
		}
			
			// save "${TEMP}/BigRun NoInfo.dta", replace // To not slow down runs
		
		// Once start SDR surveys, use previous year's job type if no job info in that year
		gen flag = 0
		forvalues yr = 1993(1)2015 {
			local prevyr = `yr'-1
			
			// For non-postdoc, no end dates, so easy change
			foreach i in AC TE GV ID NP UN NL {
				gen `i'7i`yr' = 0.5*(NIi`yr'==1 & NIi`prevyr'==0 & `i'i`prevyr'>0 & `i'i`prevyr'!=.)
				replace flag = 1 if NIi`yr'==1 & NIi`prevyr'==0 & `i'i`prevyr'>0 & `i'i`prevyr'!=.
			}
			
				// For postdocs, so long as previous year not denoting an endyr
				bys refid: egen PDend`prevyr' = max(PD2i`prevyr'_t)	// never had an indicator of 5 in previous year
				gen PD7i`yr' = 0.5*(NIi`yr'==1 & NIi`prevyr'==0 & PDend`prevyr'!=5 & PDi`prevyr'>0 & PDi`prevyr'!=0) // then replace
				replace flag = 2 if NIi`yr'==1 & NIi`prevyr'==0 & PDend`prevyr'!=5 & PDi`prevyr'>0 & PDi`prevyr'!=0 
		}
		
		bys refid: egen RedFlag = max(flag)	// check
		
	// Now replace the initial code (had to be out of the loop before to avoid cascading values)
	forvalues yr = 1993(1)2015 {
		foreach i in PD AC TE GV ID NP UN NL {
			replace `i'i`yr' = `i'7i`yr' if `i'i`yr'==0 & `i'7i`yr'==0.5
		}
	}
	
	// Clean up
	drop *_t anyInfo_t* PDend* RedFlag flag *7i*
	sort refid refyr	
		
save "${TEMP}/DRF_SDR_JobTypeIndicators.dta", replace

*** 3. CREATE MATRIX OF VARIABLES VALID YEAR SURVEYED: Survey weights (wtsurvy), salary ***
use "${TEMP}/DRF_SDR_JobTypeIndicators.dta", clear

foreach yr in 1993 1995 1997 1999 2001 2003 2006 2008 2010 2013 2015 {
	gen SALi`yr'_t = salary1i if salary1i!=. & refyr==`yr'
	replace SALi`yr'_t = salary0i if SALi`yr'_t==. & salary0i!=. & refyr==`yr'	// if don't have salary, use expected salary from DRF
	gen WTi`yr'_t = wtsurvy if refyr==`yr'
}

// Take the max across refid
foreach yr in 1993 1995 1997 1999 2001 2003 2006 2008 2010 2013 2015 {
	foreach var in SAL WT {
		bys refid: egen `var'i`yr' = max(`var'i`yr'_t)
	}
}
drop *_t

*** 4. KEEP ONE OBSERVATION FOR EACH REFID ***
keep refid phdcy_min birthdate byear phdfield phd_supField max_refyr *0i PDi* ACi* TEi* GVi* IDi* NPi* UNi* NLi* NIi* SALi* WTi*
order refid phdcy_min birthdate byear phdfield phd_supField max_refyr *0i PDi* ACi* TEi* GVi* IDi* NPi* UNi* NLi* NIi* SALi* WTi*
duplicates drop

save "${DATA}/DRF_SDR_JobTypeInd_FULL.dta", replace

*** 5. WHEN HAD NEW JOBS ***
// Start new jobs, first time in job type, last time in job type, # jobs, # years in jobs

use "${DATA}/DRF_SDR_JobTypeInd_FULL.dta", clear

foreach i in PD AC TE GV ID NP UN NL {

	// First job start
	gen `i's1 = .
	forvalues yr=1942(1)2015 {
		*replace `i's1 = `yr' if `i's1==. & (`i'i`yr'==6 | (`i'i`yr'==1 & `yr'-phdcy_min<=1 & `yr'-phdcy_min>=0))	// either 1st job or from DRF
		replace `i's1 = `yr' if `i's1==. & `i'i`yr'>0 & `i'i`yr'!=.	// first time we observe them in that job
	}
	
	// Other job starts
	forvalues num=2(1)10 {
		local prevnum = `num' - 1
		gen `i's`num' = .
		
		forvalues yr = 1942(1)2015 {
			replace `i's`num' = `yr' if `i's`num'==. & `i's`prevnum'!=. & `i's`prevnum'<`yr' & `i'i`yr'==6
		}
	}

	// First year in that job type
	egen first`i' = rowmin(`i's1-`i's10)
	
	// Last year in that job type
	egen last`i' = rowmax(`i's1-`i's10)
	forvalues yr=1942(1)2014 {
		local nextyr = `yr' + 1
		replace last`i' = `yr' if last`i'<`yr' & (`i'i`nextyr'==0 | `i'i`nextyr'==.) & `i'i`yr'!=0 & `i'i`yr'!=.
	}
	replace last`i' = 2015 if `i'i2015>=1 & `i'i2015!=.	// if in the job in 2015, that's the last year
	
	// # of jobs
	gen num`i' = .
	forvalues num = 1(1)9{
		local nextnum = `num' + 1
		replace num`i' = `num' if `i's`num'!=. & `i's`nextnum'==.
	}
	replace num`i' = 10 if `i's10!=.
	
	// Years in job
	gen yrs`i' = 0
	forvalues yr=1942(1)2015 {
		replace yrs`i' = yrs`i' + 1 if `i'i`yr'>=1 & `i'i`yr'!=.
		replace yrs`i' = yrs`i' + 0.5 if `i'i`yr'==0.5
	}
}

save "${TEMP}/DRF_SDR_Job Types Over Time.dta", replace

*** 6. RESHAPE SO CAN MERGE ONTO OTHER JOB CHARACTERISTICS - taking too long to reshape salary, so moving that to job chars instead
use "${DATA}/DRF_SDR_JobTypeInd_FULL.dta", clear
keep refid phdcy_min PDi* ACi* TEi* GVi* IDi* NPi* UNi* NLi* NIi*
reshape long PDi ACi TEi GVi IDi NPi UNi NLi NIi, i(refid phdcy_min) j(refyr)

// Give post-grad experience in each year (most important for postdoc experience)
foreach i in PD AC TE GV ID NP UN NL {
	gen is`i'=(`i'i>=1 & `i'i!=.)
	replace is`i'=0.5 if `i'i==0.5	// half a year if 7th indicator

	gen yrs`i' = 0
	replace yrs`i' = 1 if `i'i!=0 & `i'i!=. & phdcy_min==refyr
	by refid: replace yrs`i' = yrs`i'[_n-1] + is`i' if refyr>phdcy_min
}
drop is*

save "${DATA}/DRF_SDR_JobType_LONG.dta", replace

*** 7a. GRAD TRANSITIONS ***
// Necessary to do? In "A3. Postdoc Facts.do", I just look at whether have that job within 2 years of graduation, and that seems a little cleaner
use "${TEMP}/DRF_SDR_Job Types Over Time.dta", clear
	
	// Earliest job after graduation
	egen firstJobYr = rowmin(firstPD firstAC firstTE firstGV firstID firstNP firstUN firstNL)
	egen DRFinfo = rowmax(PD0i AC0i TE0i ID0i NP0i GV0i NL0i)

	foreach i in PD AC TE GV ID NP UN NL {
		gen GRt`i' = 0
		replace GRt`i' = 1 if `i'0i==1	// DRF info
		replace GRt`i' = 1 if DRFinfo==0 & first`i'==firstJobYr & firstJobYr-phdcy_min<=2 & firstJobYr-phdcy_min>0	// no DRF info, so first job within 2 yrs after graduation
	}

	// Create indicator if no info
	gen GRtNI = (GRtPD==0 & GRtAC==0 & GRtTE==0 & GRtGV==0 & GRtID==0 & GRtNP==0 & GRtUN==0 & GRtNL==0)

	// Might be useful to standardize indicators so that percents match up
	egen totIndGR = rowtotal(GRtPD GRtAC GRtTE GRtGV GRtID GRtNP GRtUN GRtNL GRtNI)

	foreach i in PD AC TE GV ID NP UN NL NI {
		gen GRt`i's = GRt`i' / totIndGR
	}
	
save "${TEMP}/DRF_SDR_Grad Transitions.dta", replace

*** 7b. OTHER JOB TRANSITIONS ***
use "${TEMP}/DRF_SDR_Grad Transitions.dta", clear

	foreach j in PD AC TE ID GV NP UN NL {

		// Find first job after this type
		foreach i in PD AC TE ID GV NP UN NL {
			if "`i'"!="`j'" {
				gen first`j'_`i' = .
				
				forvalues num = 1(1)9 {
					replace first`j'_`i' = `i's`num' if first`j'_`i'==. & `i's`num'>=last`j' // find the earliest job type that's after their last `j'
				}
			}
		}
		
		// Transition: Job within 2 yrs after last `j'
		egen minFirstT`j' = rowmin(first`j'_*)	// earliest of job types
		
		foreach i in PD AC TE ID GV NP UN NL {
			if "`i'"!="`j'" {
				gen `j't`i' = (first`j'_`i'==minFirstT`j' & minFirstT`j'!=. & minFirstT`j'-last`j'<=2)
			}
		}

		// If stay in `j' until last time observed (and no other switches)
		gen `j't`j' = 0
		egen otherTrans`j' = rowmax(`j't*)
		
		forvalues yr=1942(1)2015 {
			replace `j't`j' = 1 if max_refyr==`yr' & `j'i`yr'>0 & `j'i`yr'!=. & otherTrans`j'==0
		}	
		
		// Create indicator if ind -> no info
		gen `j'tNI = (yrs`j'>0 & `j't`j'==0 & otherTrans`j'==0)

		// Might be useful to standardize indicators so that percents match up
		egen totInd`j' = rowtotal(`j'tPD `j'tAC `j'tTE `j'tGV `j'tID `j'tNP `j'tUN `j'tNL `j'tNI)

		foreach i in PD AC TE ID GV NP UN NL NI {
			gen `j't`i's = `j't`i' / totInd`j'
		}	
	}
	
save "${TEMP}/DRF_SDR_All Job Transitions.dta", replace	
	
	

/*** 7a. GRAD TRANSITIONS ***
	// Necessary to do? In "A3. Postdoc Facts.do", I just look at whether have that job within 2 years of graduation, and that seems a little cleaner
use "${TEMP}/DRF_SDR_Job Types Over Time.dta", clear
	
	// Earliest job after graduation
	egen firstJobYr = rowmin(firstPD firstAC firstTE firstGV firstID firstNP firstUN firstNL)
	egen DRFinfo = rowmax(PD0i AC0i TE0i ID0i NP0i GV0i NL0i)

	foreach i in PD AC TE GV ID NP UN NL {
		gen GRt`i' = 0
		replace GRt`i' = 1 if `i'0i==1	// DRF info
		replace GRt`i' = 1 if DRFinfo==0 & first`i'==firstJobYr & firstJobYr-phdcy_min<=2 & firstJobYr-phdcy_min>0	// no DRF info, so first job within 2 yrs after graduation
	}

	// Create indicator if no info
	gen GRtNI = (GRtPD==0 & GRtAC==0 & GRtTE==0 & GRtGV==0 & GRtID==0 & GRtNP==0 & GRtUN==0 & GRtNL==0)

	// Might be useful to standardize indicators so that percents match up
	egen totInd = rowtotal(GRtPD GRtAC GRtTE GRtGV GRtID GRtNP GRtUN GRtNL GRtNI)

	foreach i in PD AC TE GV ID NP UN NL NI {
		gen GRt`i's = GRt`i' / totInd
	}
	
save "${TEMP}/DRF_SDR_Grad Transitions.dta", replace

***7b. POSTDOC TRANSITIONS ***
use "${TEMP}/DRF_SDR_Job Types Over Time.dta", clear
	
	// Find first job after postdoc
	foreach i in AC TE GV ID NP UN NL {
		gen firstPD_`i' = .
		
		forvalues num = 1(1)9 {
			replace firstPD_`i' = `i's`num' if firstPD_`i'==. & `i's`num'>=lastPD // find the earliest job type that's after their last PD
		}
	}

	// Transition: Job within 2 yrs after last postdoc
	egen minFirstTPD = rowmin(firstPD_AC firstPD_TE firstPD_GV firstPD_ID firstPD_NP firstPD_UN firstPD_NL)	// earliest of job types

	foreach i in AC TE GV ID NP UN NL {
		gen PDt`i' = (firstPD_`i'==minFirstTPD & minFirstTPD-lastPD<=2)
		replace PDt`i' = 0 if yrsPD==0
	}

	// If stay in postdoc last time observed (and no other switches)
	gen PDtPD = 0
	forvalues yr=1942(1)2015 {
		replace PDtPD = 1 if max_refyr==`yr' & PDi`yr'>0 & PDi`yr'!=. & PDtAC==0 & PDtTE==0 & PDtGV==0 & PDtID==0 & PDtNP==0 & PDtUN==0 & PDtNL==0
	}

	/* If don't have postdoc experience, take earliest job after graduation
	egen firstJobYr = rowmin(firstAC firstTE firstGV firstID firstNP firstUN firstNL)	// first job

	foreach i in AC TE GV ID NP UN NL {
		replace PDt`i' = 1 if yrsPD==0 & `i'0i==1	// DRF info
		replace PDt`i' = 1 if yrsPD==0 & first`i'==firstJobYr & firstJobYr-phdcy_min<=2 & firstJobYr-phdcy_min>0	// no DRF info, so first job within 2 yrs after graduation
	}
	*/

	// Create indicator if no info
	gen PDtNI = (yrsPD>0 & PDtAC==0 & PDtTE==0 & PDtGV==0 & PDtID==0 & PDtNP==0 & PDtUN==0 & PDtNL==0 & PDtPD==0)

	// Might be useful to standardize indicators so that percents match up
	egen totInd = rowtotal(PDtAC PDtTE PDtGV PDtID PDtNP PDtUN PDtNL PDtNI PDtPD)

	foreach i in AC TE GV ID NP UN NL NI PD {
		gen PDt`i's = PDt`i' / totInd
	}

	save "${DATA}/DRF_SDR_Postdoc Transitions.dta", replace

*** 7c. ADD IN ACADEMIC / INDUSTRY TRANSITIONS (See if absorbing states in "B4. Acad Ind Transitions.do") ***
use "${DATA}/DRF_SDR_Postdoc Transitions.dta", clear

	// Find first job after academic
	foreach i in PD TE GV ID NP UN NL {
		gen firstAC_`i' = .
		
		forvalues num = 1(1)9 {
			replace firstAC_`i' = `i's`num' if firstAC_`i'==. & `i's`num'>=lastAC // find the earliest job type that's after their last AC
		}
	}

	// Transition: Job within 2 yrs after last AC
	egen minFirstTAC = rowmin(firstAC_PD firstAC_TE firstAC_GV firstAC_ID firstAC_NP firstAC_UN firstAC_NL)	// earliest of job types

	foreach i in PD TE GV ID NP UN NL {
		gen ACt`i' = (firstAC_`i'==minFirstTAC & minFirstTAC-lastAC<=2)
	}
	
	// If stay in academic last time observed (and no other switches)
	gen ACtAC = 0
	forvalues yr=1942(1)2015 {
		replace ACtAC = 1 if max_refyr==`yr' & ACi`yr'>0 & ACi`yr'!=. & ACtPD==0 & ACtTE==0 & ACtGV==0 & ACtID==0 & ACtNP==0 & ACtUN==0 & ACtNL==0
	}

	// Create indicator if acad -> no info
	gen ACtNI = (yrsAC>0 & ACtPD==0 & ACtTE==0 & ACtGV==0 & ACtID==0 & ACtNP==0 & ACtUN==0 & ACtNL==0 & ACtAC==0)

	// Might be useful to standardize indicators so that percents match up
	egen totIndAC = rowtotal(ACtPD ACtTE ACtGV ACtID ACtNP ACtUN ACtNL ACtNI ACtAC)

	foreach i in PD TE GV ID NP UN NL NI AC {
		gen ACt`i's = ACt`i' / totIndAC
	}

** Add in industry **	
	// Find first job after industry
	foreach i in PD TE GV AC NP UN NL {
		gen firstID_`i' = .
		
		forvalues num = 1(1)9 {
			replace firstID_`i' = `i's`num' if firstID_`i'==. & `i's`num'>=lastID // find the earliest job type that's after their last ID
		}
	}

	// Transition: Job within 2 yrs after last ID
	egen minFirstTID = rowmin(firstID_PD firstID_TE firstID_GV firstID_AC firstID_NP firstID_UN firstID_NL)	// earliest of job types

	foreach i in PD TE GV AC NP UN NL {
		gen IDt`i' = (firstID_`i'==minFirstTID & minFirstTID-lastID<=2)
	}

	// If stay in academic last time observed (and no other switches)
	gen IDtID = 0
	forvalues yr=1942(1)2015 {
		replace IDtID = 1 if max_refyr==`yr' & IDi`yr'>0 & IDi`yr'!=. & IDtPD==0 & IDtTE==0 & IDtGV==0 & IDtPD==0 & IDtNP==0 & IDtUN==0 & IDtNL==0
	}	
	
	// Create indicator if ind -> no info
	gen IDtNI = (yrsID>0 & IDtPD==0 & IDtTE==0 & IDtGV==0 & IDtAC==0 & IDtNP==0 & IDtUN==0 & IDtNL==0 & IDtID==0)

	// Might be useful to standardize indicators so that percents match up
	egen totIndID = rowtotal(IDtPD IDtTE IDtGV IDtAC IDtNP IDtUN IDtNL IDtNI IDtID)

	foreach i in PD TE GV AC NP UN NL NI ID {
		gen IDt`i's = IDt`i' / totIndID
	}	
	
save "${TEMP}/DRF_SDR_Acad Ind Transitions.dta", replace
	
/*
// If didn't have info on what doing in DRF, take earliest job <2yrs of graduation
egen firstJobYr = rowmin(first*)

foreach i in AC GV TE ID UN NL {

	gen PDt`i' = 0
	replace PDt`i' = 1 if yrsPD==0 & `i'0i==1	// for those who didn't postdoc, what did after graduation?
	replace PDt`i' = 1 if yrsPD==0 & first`i'==firstJobYr & firstJobYr-phdcy_min<2 & firstJobYr-phdcy_min>0	// if no info right after graduation, first job <2yrs after graduation
	
	forvalues yr=1942(1)2015 {
		replace PDt`i' = 1 if `yr'-lastPD>0 & `yr'-lastPD<2 & `i'i`yr'!=0 & `i'i`yr'!=.	// first job <2yrs after last postdoc
	}
}

// How many have no info?	
br refid PDt* first* last* phdcy_min if PDtAC==0 & PDtGV==0 & PDtTE==0 & PDtID==0 & PDtUN==0 & PDtNL==0	// 49,325 / 156,108 (31.6%)

save "${TEMP}/DRF_SDR_Postdoc Transitions.dta", replace
