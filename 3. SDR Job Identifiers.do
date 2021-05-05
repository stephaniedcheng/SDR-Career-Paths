/* 3. SDR Job Identifiers.do
Name: Stephanie D. Cheng
Date Created: 12-3-18
Date Updated: 12-3-18

This .do file identifies job type from each SDR survey year. It uses
this information to create identifiers for whether an individual goes into
a postdoc (using Ginther & Kahn methodology), tenure-track academia, gov,
industry, unemployment, or not in labor force.

*/

global MAIN "H:/SDC_Postdocs"
global DATA "${MAIN}/Data"
global RESULTS "${MAIN}/Results"
global TEMP "${MAIN}/Temp"

*** 1. POSTDOC: COLLECT START/END DATA FROM 1995, 2006 RETROSPECTIVE ***
/* NOTE: Some issues with individuals seeming to list the same start/end for 2 separate postdocs.
Since I'm doing a crude count ("are you in a postdoc in this year?"), for now, will treat this as
1 postdoc. To be considered a separate postdoc, it must have unique refid-pd_start-pd_end.
*/

use "${DATA}/Stata/esdr95.dta", clear

// Adjust 1995 variables to match 2006 variables
rename pd*sm95 pd*smo
rename pd*em95 pd*emo
rename pd*sy95 pd*syr
rename pd*ey95 pd*eyr

// Append retrospectives together
append using "${DATA}/Stata/esdr06.dta"

// Turn start and end data into month-1-year data
forvalues i = 1(1)3 {
	gen pd`i'start = mdy(pd`i'smo, 1, pd`i'syr)
	gen pd`i'end = mdy(pd`i'emo, 1, pd`i'eyr)
	
	// If don't have end date, make last date of that retrospective's year
	replace pd`i'end = mdy(12,31,refyr) if pd`i'start!=. & pd`i'end==.
}
format pd*start pd*end %d
format %8.0g refyr

// Some errors with numbering, so instead, just get start and end dates for each refid
// (easiest to do by reshaping long)
rename pd*start pd_start*
rename pd*end pd_end*
keep refid refyr pd_start* pd_end*

reshape long pd_start pd_end, i(refid refyr) j(pdno)

// Keep only first record of postdoc
keep if pd_start!=.
drop pdno
gsort refid pd_start pd_end -refyr
by refid pd_start pd_end: gen dup = _n
keep if dup==1
drop dup

// Make close to the rest of the SDR data
gen PD = 1
rename refyr retroyr	// mark as retrospective, not data at that time
rename pd_start job_start
rename pd_end job_end

gen strtyr = year(job_start)
gen endyr = year(job_end)

save "${DATA}/Retrospective PD Times.dta", replace

*** 2. ALL JOB TYPES: SDR SURVEY INFORMATION ***

// Collect necessary info
foreach yr in 93 95 97 99 01 03 06 08 10 13 15 {

	use "${DATA}/Stata/esdr`yr'.dta", clear
	if inlist(`yr', 93) {
		keep refid refyr emsmi88 salary emsecsm emsecdt facten lwmn lwyr lfstat pdix wtsurvy
		rename emsmi88 emsmi
	}
	if inlist(`yr', 95) {
		keep refid refyr emsmi salary emsecsm emsecdt facten strtmn strtyr lwmn lwyr lfstat pd*sm95 pd*em95 pd*sy95 pd*ey95 wtsurvy
		
		/* Don't do this - seems to cause a lot of people who aren't working to be in postdoc positions
		// no current principal job is postdoc indicator, so will say pdix==1 if any of the pd indicators match start month/year and have no end date
		gen pdix = "N"
		forvalues i = 1(1)3 {
			replace pdix = "Y" if strtmn==pd`i'sm95 & strtyr==pd`i'sy95 & pd`i'em95>=98 & pd`i'ey95>=9998
		}
		*/
	}
	if inlist(`yr', 97, 99, 01, 03) {
		keep refid refyr emsmi salary emsecsm emsecdt facten strtmn strtyr lwmn lwyr lfstat pdix wtsurvy
	}
	if inlist(`yr', 06, 08, 10, 13, 15) {
		keep refid refyr emsmi salary emsecsm emsecdt tensta strtmn strtyr lwmn lwyr lfstat pdix wtsurvy
	}

	save "${TEMP}/sdr_jobtype`yr'.dta", replace
}

// Append together
use "${TEMP}/sdr_jobtype93.dta", clear
foreach yr in 95 97 99 01 03 06 08 10 13 15 {
	append using "${TEMP}/sdr_jobtype`yr'.dta"
}

// Job Type
gen PD = (pdix=="Y")
gen AC = (PD==0 & (facten=="1" | facten=="2" | facten=="3" | tensta=="3" | tensta=="4"))	// tenure-track
gen TE = (PD==0 & AC==0 & emsecsm=="1")
gen ID = (emsecdt=="21" | emsecdt=="22")
gen NP = (emsecdt=="23")
gen GV = (emsecsm=="2")
gen UN = (lfstat=="2")
gen NL = (lfstat=="3")

// Year referenced by emsmi
gen emsmi_yr = .
replace emsmi_yr = 1988 if emsmi!="" & refyr==1993
foreach yr in 95 97 99 {
	replace emsmi_yr = refyr-2 if emsmi!="" & refyr==19`yr'
}
foreach yr in 01 03 08 10 15 {
	replace emsmi_yr = refyr-2 if emsmi!="" & refyr==20`yr'
}
foreach yr in 06 13 {
	replace emsmi_yr = refyr-3 if emsmi!="" & refyr==20`yr'
}

// Job start date, possible end date for last job
gen job_start = mdy(strtmn, 1, strtyr)
format job_start %td

gen last_end = mdy(lwmn, 1, lwyr)	// only for unemployed
format last_end %td

format %8.0g refyr lwyr strtyr

// Replace missing dates / salary with .
replace strtyr = . if strtyr>=9998
replace lwyr = . if lwyr>=9998

replace salary = . if salary>=999998
rename salary salary1i

// Only keep neceessary variables
keep refid refyr wtsurvy PD AC TE GV ID NP UN NL job_start strtyr salary1i emsmi_yr emsmi last_end lwyr
order refid refyr wtsurvy PD AC TE GV ID NP UN NL job_start strtyr salary1i emsmi_yr emsmi last_end lwyr

// Add back in retrospective data
append using "${DATA}/Retrospective PD Times.dta"

save "${DATA}/SDR_JobTypes.dta", replace

