/* 8. FULL SDR SAMPLE
Name: Stephanie D. Cheng
Date Created: 1-10-19
Date Updated: 3-29-19

This .do file combines worker and job characteristics to create the final SDR sample.

*/

global MAIN "H:/SDC_Postdocs"
global DATA "${MAIN}/Data"
global RESULTS "${MAIN}/Results"
global TEMP "${MAIN}/Temp"
global LOOKUPS "${MAIN}/Lookups"

*** 1. COMBINE WORKER AND JOB CHARACTERISTICS ***
use "${DATA}/DRF_SDR_ChangeWorkChar.dta", clear
merge 1:1 refid refyr DRForig SDRorig using "${DATA}/DRF_SDR_JobTypeChar_int_FULL.dta"
drop _merge

// Merge in worker characteristics
merge m:1 refid using "${DATA}/sdrdrf_FULL.dta", update	// this should be the master file for phdcy_min
drop _merge

// Some DRF -1, which should be missing
rename byear byear_DRF
replace byear_DRF = . if byear_DRF==-1

// Clean birth year if missing in DRF
bys refid: replace byear_SDR = byear_SDR[_N] // Fillin SDR birth year
gen byear = byear_DRF
replace byear = byear_SDR if byear==.

// Fill in weights
egen numID_refid = group(refid)	// use to format as panel
sort numID_refid refyr

tsset numID_refid refyr
tsfill

	// Fill in 1st weight down
	bys numID_refid: carryforward wtsurvy1, gen(wtsurvy1_t1)
	// Fill in 1st weight up
	gsort numID_refid -refyr
	by numID_refid: carryforward wtsurvy1_t1, gen(wtsurvy1_f)
	// Fill in avg weight
	bys numID_refid: egen wtsurvyAvg_f = max(wtsurvyAvg)

	// Drop temp
	drop wtsurvy1 wtsurvy1_t1 wtsurvyAvg

// Age, quadratic age in each year
gen age = refyr - byear
replace age = . if refyr<phdcy_min | byear==.
gen age2 = age^2

// Merge on child YOB indicators
merge m:1 refid using "${DATA}/SDR Child YOB 1-5.dta", keepusing(yob_*)
drop _merge

// Use child YOB to fill in anyChild indicator
rename anyChild anyChildORIG
gen anyChild = anyChildORIG
replace anyChild = (refyr>=yob_1early) if anyChild==. & yob_1early!=.

// Replace job ID with unique identifier (currently connected with refid)
rename jobID jobNum
egen jobIDi = group(refid jobNum)			// at the ind-job level
egen jobyrIDi = group(refid jobNum refyr)	// at the ind-job-year level

// Worker location is previous year's location
sort refid refyr
foreach i in state instcod_n instcod_city {
	by refid: gen `i'1 = `i'[_n-1]
}

// For year graduate / after PhD, previous location is school location
gen phdinst_st = substr(phdinst_city, -2, 2)

replace state1 = phdinst_st if refyr==phdcy_min+1 | refyr==phdcy_min
replace instcod_n1 = phdinst_n if refyr==phdcy_min+1
replace instcod_city1 = phdinst_city if refyr==phdcy_min+1 | refyr==phdcy_min

// Fill in US citizenship if didn't change from DRF to SDR
	sort numID_refid refid refyr
	tsset numID_refid refyr
	
	foreach i in UScit USpr USnative {
		by numID_refid: ipolate `i' refyr, gen(`i'_i) // if ipolate not 0 or 1, then changed over time period
		replace `i' = `i'_i if (`i'_i==1 | `i'_i==0) & `i'==.
		drop `i'_i
	}

	// Clarify US citizenship indicators (naturalized, non-US permanent resident)
	gen USnatur = UScit if USnative==0
	replace USnatur = 0 if USnative==1
	
	gen USnupr = 1 if USpr==1 & UScit==0
	replace USnupr = 0.25 if USpr==1 & UScit==0.75	// transitioning from pr -> US cit
	replace USnupr = 0.75 if USpr==1 & UScit==0.25 // transitioning from US cit -> pr
	replace USnupr = 0 if USpr==0 | UScit==1

	foreach i in natur nupr {
		replace US`i' = . if UScit==.
	}

// Federal funding field to match funding data
gen fundField = ""
replace fundField = "Lifesciences" if phd_supField=="Agriculture"
replace fundField = "Lifesciences" if phd_supField=="Bio Sciences"
replace fundField = "Lifesciences" if phd_supField=="Health Sciences"
replace fundField = "Engineering" if phd_supField=="Engineering"
replace fundField = "CSMath" if phd_supField=="Comp Sci"
replace fundField = "CSMath" if phd_supField=="Math"
replace fundField = "Physicalsciences" if phd_supField=="Other Phys Sci"
replace fundField = "Physicalsciences" if phd_supField=="Chemistry"
replace fundField = "Physicalsciences" if phd_supField=="Physics"
replace fundField = "Psychology" if phd_supField=="Psychology"
replace fundField = "Socialsciences" if phd_supField=="Economics"
replace fundField = "Socialsciences" if phd_supField=="Other Social Sciences"

// Fill in pubs/patents rates

	// Reference year
	replace pp_refyr = 1990 if refyr>=1990 & refyr<1995
	replace pp_refyr = 1995 if refyr>1995 & refyr<2001
	replace pp_refyr = 1998 if refyr>=1998 & refyr<2003
	replace pp_refyr = 2003 if refyr>=2003 & refyr<2008

	// Reference year's rate
	foreach i in papers article book uspapp uspgrt uspcom {
		foreach yr in 1990 1995 1998 2003 {
			gen t_`i'`yr' = rt_`i' if pp_refyr==`yr'
			bys refid: egen max_`i'`yr' = max(t_`i'`yr')
		}
	}

	// Fill in from reference year
	foreach i in papers article book uspapp uspgrt uspcom {
		gen rt_`i'_f = .
		
		foreach yr in 1990 1995 1998 2003 {
			replace rt_`i'_f = max_`i'`yr' if pp_refyr==`yr'
		}
	}

// Drop unnecessary variables
drop sdrdrf_yr sdrdrf_fullYr byear_DRF byear_SDR max_* t_*

// Order by worker characteristics, then job characteristics
order refid refyr wtsurvy* DRForig SDRorig birthdate byear bplace* hsplace* male R_* age age2 married anyChild* under6Child yob_* USnative USnatur UScit USpr USnupr cntrycit ///
		bayear bafield ba_supField bainst* bacarn* mayear mafield ma_supField mainst* macarn* phdcy_min phdfield phd_supField gradYrs geyear phdentry togephd phdinst* phdcarn* profdeg profyear fundField prestat yrs* state1 instcod_n1 instcod_city1 /// 
		jobID jobyrID papers article books patent uspapp uspgrt uspcom pp_refyr rt_*

// Sort by refid refyr
sort refid refyr

// Generate indicator for STEM
gen STEM = (phd_supField!="" & phd_supField!="Economics" & phd_supField!="Education" & phd_supField!="Humanities" & phd_supField!="Other Social Sciences" & phd_supField!="Professional Fields")
		
	// Merge on buying power -> adjust salary for inflation
	merge m:1 refyr using "${LOOKUPS}/Inflation Calc.dta"
	drop if _merge==2
	drop _merge
	gen SALi_Adj = SALi*BP2015		
		
	// Add in estimated salary data (See "E3. Estimated Salary.do")
	merge 1:1 refid refyr using "${TEMP}/Salary PAI.dta", keepusing(SAL_pPAI)
	drop _merge
	
save "${DATA}/OOI_fullsample.dta", replace

*** 3. LIMIT SAMPLE TO OBSERVATIONS OF INTEREST ***
use "${DATA}/OOI_fullsample.dta", clear

// Drop if no refyr (not entirely sure how this occurred...)
drop if refyr==.

// Only enter dataset if after phdcy_min
drop if phdcy_min>refyr & SDRorig==. & DRForig==.

// Exit survey at age 76; only keep if it's a DRF or SDR original
drop if age>76 & age!=. & SDRorig==. & DRForig==.

// Keep only STEM
keep if STEM==1

/* This isn't working properly
// Exits survey at age 76
gen byear_BA = bayear - 20	// if no age, assume graduated from undergrad at 20 (likely underestimate) - just use to calculate whether to exit survey
gen age_BA = refyr - byear_BA

gen byear_PhD = phdcy_min - 25	// if *still* no age, assume received PhD at 25 (likely underestimate) - just use to calculate whether to exit survey
gen age_PhD = refyr - phdcy_min
drop if (byear!=. & age>=76) | (byear==. & ages_BA>=76) | (byear==. & bayear==. & age_PhD>=76)

// Drop if all job type indicators missing (indicated no response from here on out)
// drop if PDi==. & ACi==. & TEi==. & GVi==. & IDi==. & UNi==. & NLi==.
*/

save "${DATA}/OOI_workingsample.dta", replace

*** 3. CREATE WORKER CHARACTERISTICS, JOB CHARACTERISTICS FILES FOR SAMPLING

// Worker characteristics
use "${DATA}/OOI_workingsample.dta", clear
keep refid refyr wtsurvy* DRForig SDRorig birthdate byear bplace* hsplace* male R_* age age2 married anyChild under6Child yob_* USnative USnatur UScit USpr USnupr cntrycit ///
		bayear bafield ba_supField bainst* bacarn* mayear mafield ma_supField mainst* macarn* phdcy_min phdfield phd_supField fundField STEM phdinst* phdcarn* debtlevel prestat profdeg profyear gradYrs geyear phdentry togephd yrs* state1 instcod_n1 instcod_city1 	///
		sp* ch* nr* nw* pt* sat*
save "${DATA}/OOI_workerchar.dta", replace

// Job characteristics
use "${DATA}/OOI_workingsample.dta", clear
drop refid birthdate byear* bplace* hsplace* male R_* age* married anyChild under6Child yob_* USnatur UScit USpr USnupr cntrycit ///
		bayear bafield ba_supField bainst* bacarn* mayear mafield ma_supField mainst* macarn* phdcy_min phdfield phd_supField phdinst* phdcarn* prestat profdeg profyear gradYrs geyear phdentry togephd yrs* state1 instcod_n1 instcod_city1 ///
		sp* ch* nr* nw* pt* sat*
save "${DATA}/OOI_jobchar.dta", replace

*** 4. Add on transitions? ***
use "${TEMP}/DRF_SDR_All Job Transitions.dta", clear
keep refid GRt*s PDt*s ACt*s TEt*s IDt*s GVt*s NPt*s UNt*s NLt*s

merge 1:m refid using "${DATA}/OOI_workerchar.dta"
drop _merge

// Order by worker characteristics, then transitions
order refid refyr wtsurvy* DRForig SDRorig birthdate byear bplace* hsplace male R_* age age2 married anyChild under6Child yob_* USnative USnatur UScit USpr USnupr cntrycit ///
		bayear bafield ba_supField bainst* bacarn* mayear mafield ma_supField mainst* macarn* phdcy_min phdfield phd_supField gradYrs geyear phdentry phdinst* phdcarn* fundField prestat yrs* state1 instcod_n1 instcod_city1

save "${TEMP}/OOI_workerchar_transitions.dta", replace

*** 5. FULL data set with transitions ***
use "${TEMP}/DRF_SDR_All Job Transitions.dta", clear
keep refid GRt*s PDt*s ACt*s TEt*s IDt*s GVt*s NPt*s UNt*s NLt*s first* last*

merge 1:m refid using "${DATA}/OOI_workingsample.dta"
drop _merge

// Order by worker characteristics, then transitions
order refid refyr wtsurvy* DRForig SDRorig birthdate byear bplace* hsplace male R_* age age2 married anyChild under6Child yob_* USnative USnatur UScit USpr USnupr cntrycit ///
		bayear bafield ba_supField bainst* bacarn* mayear mafield ma_supField mainst* macarn* phdcy_min phdfield phd_supField gradYrs geyear phdentry phdinst* phdcarn* fundField prestat yrs* state1 instcod_n1 instcod_city1

save "${TEMP}/OOI_worksample_transitions.dta", replace