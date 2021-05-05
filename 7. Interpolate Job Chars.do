/* 8. INTERPOLATE JOB CHARS
Name: Stephanie D. Cheng
Date Created: 1-9-19
Date Updated: 3-19-19

This .do file combines the job type indicators given in "4. Job Type Indicators.do" with
job characteristics in "6. Job Characteristics.do." It then interpolates job characteristics 
based off job start dates and between survey years.

*/

global MAIN "H:/SDC_Postdocs"
global DATA "${MAIN}/Data"
global RESULTS "${MAIN}/Results"
global TEMP "${MAIN}/Temp"

*** 1. MERGE JOB INDICATORS ONTO JOB CHARACTERISTICS ***
use "${DATA}/DRF_SDR_JobType_LONG.dta", clear
merge 1:1 refid refyr using "${DATA}/DRF_SDR_JobChar.dta"
drop _merge

// Identifier for new job
gen newjob = .
sort refid refyr
foreach i in PD AC TE GV ID NP {
	replace newjob = 1 if `i'i==6	// new job
	by refid: replace newjob = 1 if `i'i!=0 & `i'i!=. & `i'i[_n-1]==0	// not in job last year but in job this year
	replace newjob = 1 if (refyr==phdcy_min & `i'i!=0 & `i'i!=.)	// job in year of graduation
}

// Create job ID based off new jobs
preserve
	keep refid refyr newjob
	keep if newjob==1
	bys refid: gen jobID = _n
	save "${TEMP}/JobTypeChar JobIDs.dta", replace
restore

// Merge job IDs back onto full data set
merge 1:1 refid refyr using "${TEMP}/JobTypeChar JobIDs.dta"

// Fill in job IDs for continuous years in job
sort refid phdcy_min refyr
bys refid: replace jobID = jobID[_n-1] if missing(jobID) & _n>1 & !(PDi==0 & ACi==0 & TEi==0 & GVi==0 & IDi==0 & NPi==0) & !(PDi==. & ACi==. & TEi==. & GVi==. & IDi==. & NPi==.)

order refid phdcy_min refyr jobID

save "${TEMP}/DRF_SDR_JobTypeChar.dta", replace

*** 2. FILL IN / INTERPOLATE JOB CHARACTERISTICS ***
use "${TEMP}/DRF_SDR_JobTypeChar.dta", clear

// Destring institution codes
rename instcod instcod_ORIG
destring instcod_ORIG, gen(instcod) force

// Only keep years have a job, since those are the chars filling in
// Will append back the others later
preserve
	keep if jobID==.
	save "${TEMP}/JobTypeChar_nojob.dta", replace
restore

keep if jobID!=.

// Fill in job characteristics
foreach i in job_start emp_supField ocpr_FULL emsecsm emsecdt {

	// Fill down first
	sort refid jobID refyr
	by refid jobID: replace `i' = `i'[_n-1] if missing(`i') & _n>1
	
	// Resort so refyr decreasing, so filling up works properly
	gsort refid jobID -refyr
	by refid jobID: replace `i' = `i'[_n-1] if missing(`i') & _n>1

}

// Fill in location info for US locations -> maybe don't do this, and just merge to info?
foreach i in state instcod_n instcod_city instcod  {

	// Fill down first
	sort refid jobID refyr
	by refid jobID: replace `i' = `i'[_n-1] if missing(`i') & _n>1
	
	// Resort so refyr decreasing, so filling up works properly
	gsort refid jobID -refyr
	by refid jobID: replace `i' = `i'[_n-1] if missing(`i') & _n>1

}

// If it's a new business, only make it new bus for up to 5 years
gen newbus_ORIG = newbus

	// Fill in down only
	sort refid jobID refyr
	by refid jobID: replace newbus = newbus[_n-1] if missing(newbus) & _n>1

	// Count how many times newbus
	gen newbus_COUNT = 1 if newbus==1
	sort refid jobID refyr
	by refid jobID: replace newbus_COUNT = newbus_COUNT[_n-1]+1 if newbus[_n-1]==1 & newbus_COUNT!=.
	
	// Replace newbus with 0 if over 5 years
	replace newbus = 0 if newbus_COUNT>5 & newbus_COUNT!=.
	drop newbus_COUNT
	
/* Interpolate job characteristics - DON'T DO THIS
foreach var of varlist SALi emsize act* wa* mgr* sup* fs* govsup tenured jobins jobpens jobproft jobvac {

	sort refid jobID refyr
	by refid jobID: ipolate `var' refyr, gen(`var'_i)
	
	// If transition, see whether positive or negative
	gen `var'_c = `var'_i - `var'_i[_n-1]

}
*/

/* For indicators, replace non-0's and non-1's with +/- 0.5 to signify a transition - DON'T DO THIS
foreach i in actrd acttch actcap actded actmgt actrdt actres ///
				ward watea waadm wasvc waacc waaprsh wabrsh wacom wadev wadsn waemrl wamgmt waot waprod waqm wasale ///
				mgrind mgrnat mgrsoc mgroth ///
				fsagr fsdoe fshhs fsnasa fsnih fsnsf fsot fsaid fscom fsded fsdod fsdot fsepa fshud fsint fsjus fslab fsnrc fsst fsva ///
				supwk govsup tenured jobins jobpens jobproft jobvac {
	replace `i'_i = 0.75 if `i'_i>0 & `i'_i<1 & `i'_c>0	// positive transition (closer to 1)
	replace `i'_i = 0.25 if `i'_i>0 & `i'_i<1 & `i'_c<0	// negative transition (closer to 0)
}


// No longer needed: Replace govsup = 1 if any of the fs* == 1
foreach var of varlist fs* {
	replace govsup_i = 1 if `var'==1
}
*/

save "${TEMP}/DRF_SDR_JobTypeChar_int.dta", replace

*** 3. CLEAN UP ***
use "${TEMP}/DRF_SDR_JobTypeChar_int.dta", clear

// Add back in other dates (without jobs)
append using "${TEMP}/JobTypeChar_nojob.dta"

// Keep only important variables
keep refid phdcy_min refyr DRForig SDRorig jobID PDi ACi TEi GVi IDi PDi NPi UNi NLi NIi yrs* ///
	job_start pj* emp_supField ocpr_FULL ocedrlp* state emsecsm emsecdt pdaffil pdloc pdoccode emst instcod* ///
	SALi fullTimeP hrswk act* wa* mgr* sup* fs* govsup tenured emsize job* newbus facrank nr* chchg chcon chfam chlay chloc chot chpay chret chsch ///
	nw* pt* sat* sp*

save "${DATA}/DRF_SDR_JobTypeChar_int_FULL.dta", replace
