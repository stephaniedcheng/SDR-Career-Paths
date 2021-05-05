/* 6. WORKER CHARACTERISTICS
Name: Stephanie D. Cheng
Date Created: 1-7-19
Date Updated: 2-8-19

This .do file creates worker characteristics that change from year to year and
aren't attached to the worker's job. It does not include worker characteristics
in "1. SDR Individuals.do" (that do not change over time); that will be merged on
at the last step in "8. Full SDR Sample.do."

*/

global MAIN "H:/SDC_Postdocs"
global DATA "${MAIN}/Data"
global RESULTS "${MAIN}/Results"
global TEMP "${MAIN}/Temp"

*** 1. IDENTIFY CHARACTERISTICS FROM DRF ***
use "${DATA}/sdrdrf_refIDs.dta", clear

foreach yr in 93 95 97 99 01 03 06 08 10 13 15 {
	preserve
		keep if sdrdrf_yr=="`yr'"

		if inlist(`yr', 93) {
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(drfmarst drfdepen drfcit drfcntry)
			
			// Rename to better match years
			rename drfmarst marital
			rename drfdepen depends
			rename drfcit citiz
			rename drfcntry cntrycit
			
		}
		if inlist(`yr', 95) {
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(marital depends citiz cntrycit prestat)
			
			// Adjust prestat to be same as other years
			rename prestat prestat_ORIG
			gen prestat = prestat_ORIG
			replace prestat = "10" if prestat_ORIG=="-"
			replace prestat = "11" if prestat_ORIG=="&"
			replace prestat = "12" if prestat_ORIG=="A"
			replace prestat = "13" if prestat_ORIG=="B"
			
		}
		if inlist(`yr', 97) {
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(marital depends citiz cntrycit)
		}
		if inlist(`yr', 99, 01) {
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(marital depends citiz cntrycit prestat debtlevl)
		}
		if inlist(`yr', 03, 06, 08) {
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(marital depend* citiz cntrycit prestat debtlevl)
			
			// Clean depends to incorporate depend5, depend18, depend19
			replace depends = depend5 + depend18 + depend19 if depends==.
			
			// Create indicator for under 6 kids
			gen under6Child = (depend5>0)
			replace under6Child = . if depend5==.
		}
		if inlist(`yr', 10, 13, 15) {
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(marital depends DEPEND* citiz cntrycit prestat debtlevl)
			
			// Rename DEPENDS so it appends better
			rename DEPEND5 DEPEND18 DEPEND19, lower
			
			// Clean depends to incorporate depend5, depend18, depend19
			replace depends = depend5 + depend18 + depend19 if depends==.
			
			// Create indicator for under 6 kids
			gen under6Child = (depend5>0)
			replace under6Child = . if depend5==.
		}

		// Destring marital, depends
		destring marital depends, replace
			
		// Married status
		gen married = (marital==1)
		replace married = . if marital==.
		
		// Children indicator
		gen anyChild = (depends!=0)
		replace anyChild = . if depends==.

		// US Citizenship indicator
		gen UScit = (citiz=="1" | citiz=="U" | citiz=="0" | citiz=="P")
		replace UScit = . if citiz==""
			
		// Permanent resident indicator
		gen USpr = (UScit == 1 | citiz=="2")
		replace USpr = . if citiz==""
		
		keep if _merge==3
		drop _merge
		
		save "${TEMP}/sdrdrf`yr'_ChangeWorkChar.dta", replace
	restore
}

// Append together
use "${TEMP}/sdrdrf93_ChangeWorkChar.dta", clear
foreach yr in 95 97 99 01 03 06 08 10 13 15 {
	append using "${TEMP}/sdrdrf`yr'_ChangeWorkChar.dta"
}

// Refyr is graduation year
gen refyr = phdcy_min

// Destring prestat
destring prestat, replace

// Create indicator for original DRF data
gen DRForig = 1

// Debt level
gen debtlevel = .
replace debtlevel = 0 if debtlevl=="0"
replace debtlevel = 2500 if debtlevl=="1"
replace debtlevel = 7500 if debtlevl=="2"
replace debtlevel = 12500 if debtlevl=="3"
replace debtlevel = 17500 if debtlevl=="4"
replace debtlevel = 22500 if debtlevl=="5"
replace debtlevel = 27500 if debtlevl=="6"
replace debtlevel = 30000 if debtlevl=="7"
replace debtlevel = 15000 if debtlevl=="A"
replace debtlevel = 25000 if debtlevl=="B"
replace debtlevel = 15000 if debtlevl=="C"

// Determine child year-of-births cutoffs (given available data on ages)
foreach i in 0 5 6 18 19 {
	gen yob_c`i' = refyr - `i'
}
	
	// Replace with missing if don't have kids in that range
	replace yob_c0 = . if depend5==0 | depend5==.
	replace yob_c5 = . if depend5==0 | depend5==.
	replace yob_c6 = . if depend18==0 | depend18==.
	replace yob_c18 = . if depend18==0 | depend18==.
	replace yob_c19 = . if depend19==0 | depend19==.

save "${TEMP}/DRF_ChangeWorkChar.dta", replace

*** 2. IDENTIFY CHARACTERISTICS FROM SDR ***
foreach yr in 93 95 97 99 01 03 06 08 10 13 15 {

	use "${DATA}/Stata/esdr`yr'.dta", clear
	if inlist(`yr', 93) {
		keep refid refyr marind marsta ch18 ch1217 ch6 ch611 chun12 chlvin ctzn fnccd age wtsurvy
	}
	if inlist(`yr', 95) {
		keep refid refyr marind marsta ch18 ch1217 ch25 ch6 ch611 chu2 chun12 chlvin ctzn fnccd age papers article uspapp uspgrt uspcom patent wtsurvy
		
		// Publication, patent reference year
		gen pp_refyr = 1990
	}
	if inlist(`yr', 97, 99) {
		keep refid refyr marind marsta ch18 ch1217 ch25 ch6 ch611 chu2 chun12 chlvin ctzn fnccd age wtsurvy
	}
	if inlist(`yr', 01) {
		keep refid refyr marind marsta ch18 ch1217 ch25 ch6 ch611 chu2 chun12 chlvin ctzn fnccd age papers article books uspapp uspgrt uspcom patent wtsurvy
		
		// Publication, patent reference year
		gen pp_refyr = 1995
	}
	if inlist(`yr', 03) {
		keep refid refyr marind marsta ch19 ch1218 ch25 ch6 ch611 chu2 chun12 chlvin ctzn fnccd age papers article books uspapp uspgrt uspcom patent wtsurvy	

		// Publication, patent reference year
		gen pp_refyr = 1998		
	}
	if inlist(`yr', 06) {
		keep refid refyr marind marsta ch19 ch1218 ch25 ch6 ch611 chu2 chun12 chlvin ctzn fnccd age wtsurvy
	}
	if inlist(`yr', 08) {
		keep refid refyr marind marsta ch19 ch1218 ch25 ch6 ch611 chu2 chun12 chlvin ctzn fnccd age papers article books uspapp uspgrt uspcom patent wtsurvy	

		// Publication, patent reference year
		gen pp_refyr = 2003	
	
	}
	if inlist(`yr', 10, 13, 15) {
		keep refid refyr marind marsta CH19 CH1218 CH25 CH6 CH611 CHU2 CHUN12 chlvin ctzn fnccd age wtsurvy
		
		// Make variables match other years
		rename CH19 CH1218 CH25 CH6 CH611 CHU2 CHUN12, lower
	}
	
	// Married status
	gen married = (marind=="Y")
	replace married = . if marind==""
	
	// Children indicator
	gen anyChild = (chlvin=="Y")
	replace anyChild = . if chlvin==""
	
	// US Citizenship indicator
	gen UScit = (ctzn=="1" | ctzn=="2" | ctzn=="7")
	replace UScit = . if ctzn==""
	
	// Permanent Resident indicator
	gen USpr = (UScit == 1 | ctzn=="3")
	replace USpr = . if ctzn==""
	
	// Rename foreign country citizenship var
	rename fnccd cntrycit
	
	save "${TEMP}/sdr`yr'_ChangeWorkChar.dta", replace
}

// Append together
use "${TEMP}/sdr93_ChangeWorkChar.dta", clear
foreach yr in 95 97 99 01 03 06 08 10 13 15 {
	append using "${TEMP}/sdr`yr'_ChangeWorkChar.dta"
}

// Generate first weight (wtsurvy when first enter SDR)
bys refid: egen refyr1 = min(refyr)
gen tempWt = wtsurvy if refyr==refyr1
bys refid: egen wtsurvy1 = max(tempWt)
drop  refyr1

// Generate average weight
bys refid: egen wtsurvyAvg = mean(wtsurvy)

// Birth year from age
	// depending on timing of survey response, may have multiple byears from this calculation; take most common
gen byear_t = refyr - age
bys refid byear_t: gen byear_tc = _N	// # of times byear comes up
bys refid: egen byear_tmc = max(byear_tc)	// most frequent times shows up N times
gen byear_t2 = byear_t if byear_tc==byear_tmc	// find most frequent year
bys refid: egen byear_SDR = min(byear_t2)	// if tie, take min (seems to be closer to DRF)

drop byear_t*
rename age ageORIG

// Clean children variables
foreach i in chu2 ch6 ch611 ch25 ch1217 ch1218 ch18 ch19 {
	replace `i' = . if `i'==98
}

// Children under 6 indicator
gen under6Child = ((chu2>0 & chu2!=.) | (ch25>0 & ch25!=.) | (ch6>0 & ch6!=.))
replace under6Child = . if chu2==. & ch25==. & ch6==.

// Determine child year-of-births cutoffs (given available data on ages)
foreach i in 0 1 2 5 6 11 12 17 18 {
	gen yob_c`i' = refyr - `i' if anyChild>0
}
foreach i in 18 19 {
	gen yob_cL`i' = refyr - `i' if anyChild>0	// do lower limit for ch18, ch19 so no overlap
}
	
	// Replace with missing if don't have kids in that range => may want to do this later, since will need to do for each kid
	replace yob_c0 = . if chu2==0 | (ch6==0 & refyr==1993)
	replace yob_c1 = . if chu2==0 | refyr==1993
	replace yob_c2 = . if ch25==0 | refyr==1993
	replace yob_c5 = . if ch25==0 | (ch6==0 & refyr==1993)
	replace yob_c6 = . if ch611==0
	replace yob_c11 = . if ch611==0
	replace yob_c12 = . if ch1217==0 | ch1218==0
	replace yob_c17 = . if ch1217==0 | refyr>=2003
	replace yob_c18 = . if ch1218==0 | refyr<2003
	replace yob_cL18 = . if ch18==0 | refyr>=2003
	replace yob_cL19 = . if ch19==0 | refyr<2003
	
	// Ch6 only needed in 1993, so replace with . otherwise
	replace ch6 = . if refyr!=1993
	
// Correct for logical skip of papers, articles, books
foreach i in papers article books {
	replace `i' = . if `i'==98
}

// Incorporate patents = 0 into uspapp, uspgrt, uspcom
foreach i in uspapp uspgrt uspcom {
	replace `i' = . if `i'==98
	replace `i' = 0 if `i'==. & patent=="N"
}

// Create pub/patent rate
foreach i in papers article book uspapp uspgrt uspcom {
	gen rt_`i' = `i'/(refyr-pp_refyr)	
}

// Order + format so easier to read
order refid refyr married anyChild under6Child UScit USpr marind marsta ctzn chu2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19

format %ty refyr byear_SDR
format %9.0g ch1217 ch6 ch611 ch25 chu2 ch1218 ch18 ch19 age papers article books uspapp uspgrt uspcom

sort refid refyr

save "${TEMP}/SDR_ChangeWorkChar.dta", replace

	// USE THIS DATA FILE TO CREATE CHILD YOB RANGES IN "5a. Calculate Worker Child YOB Ranges.do"

*** 3. INTERPOLATE SDR ***
use "${TEMP}/SDR_ChangeWorkChar.dta", clear

// Create indicator for original SDR data
gen SDRorig = 1

// Fillin missing IN-BETWEEN years (don't make full panel! otherwise will make lots of empties!)
egen numID_refid = group(refid)	// use to format as panel
sort numID_refid refid refyr

tsset numID_refid refyr
tsfill

// Fill in missing info
sort numID_refid refid refyr
foreach i in refid byear_SDR {
	rename `i' `i'_ORIG
	by numID_refid: gen `i' = `i'_ORIG[_N]
}

// Interpolate age	// use as a check
by numID_refid: ipolate ageORIG refyr, gen(ageORIG_i)

// Interpolate marital status, children indicator, US citizenship between years: mostly to fill in 0's and 1's
foreach i in married anyChild under6Child UScit USpr {
	by numID_refid: ipolate `i' refyr, gen(`i'_i)
}

sort refid refyr
foreach i in married anyChild under6Child UScit USpr {

	// If transition, see whether positive or negative
	by refid: gen `i'_c = `i'_i - `i'_i[_n-1]

	// Rename variables "ORIG" so will append better with DRF
	rename `i' `i'_ORIG
	rename `i'_i `i'
}

// Replace non-0's and non-1's with +/- 0.5 to signify a transition
foreach i in married anyChild under6Child UScit USpr {
	replace `i' = 0.75 if `i'>0 & `i'<1 & `i'_c>0	// positive transition (closer to 1)
	replace `i' = 0.25 if `i'>0 & `i'<1 & `i'_c<0	// negative transition (closer to 0)
}

	// How often transition?
	tab married, m		// 1.80% unmarry, 2.44% get married
	tab anyChild, m		// 4.77% no longer children living with them, 3.35% have children
	tab under6Child, m	// 3.69% no longer children under 6 living with them, 0.4% have a new children under 6
	tab UScit, m			// 0.11% lose US citizenship, 1.33% gain US citizenship (seems mostly from permanent resident)
	tab USpr, m			// 0.11% lose US residency, 0.83% gain US residency

// Order by most important info
order refid refyr married anyChild under6Child UScit USpr

// Drop unnecessary and not original variables
drop *_c numID_refid refid_ORIG

save "${TEMP}/SDR_ChangeWorkChar_Int.dta", replace
	
*** 3. APPEND DRF, SDR (will interpolate for select vars in "8. Full SDR Sample.do" ***
use "${TEMP}/DRF_ChangeWorkChar.dta", clear
append using "${TEMP}/SDR_ChangeWorkChar_Int.dta"

// Keep only variables of interest
keep refid refyr wtsurvy* DRForig SDRorig phdcy_min prestat debtlevel married anyChild under6Child UScit USpr cntrycit byear_SDR ageORIG* papers article books uspapp uspgrt uspcom patent pp_refyr rt_*

// Sort by refid and refyr
sort refid refyr

save "${DATA}/DRF_SDR_ChangeWorkChar.dta", replace

/* DEFUNCT

*** 4. ADD IN NON-CHANGING WORKER CHARACTERISTICS FROM "1.SDR INDIVIDUALS.DO"
merge m:1 refid using "${DATA}/sdrdrf_FULL.dta"
drop _merge

// Fillin SDR birth year
bys refid: replace byear_SDR = byear_SDR[_N] // Fillin SDR birth year

// Add in SDR birth year if missing in DRF
rename byear byear_DRF
gen byear = byear_DRF
replace byear = byear_SDR if byear==.

/* Turns out better to do this calculation once have full range of years
// Age, quadratic age in each year
gen age = refyr - byear
gen age2 = age^2
*/

// Keep only variables of interest
keep refid refyr birthdate byear male R_* ///
		bayear bafield ba_supField bainst bacarn mayear mafield ma_supField mainst macarn phdcy_min phdfield phd_supField phdinst phdcarn ///
		prestat /*age age2*/ married anyChild under6Child UScit USpr 
order refid refyr birthdate byear male R_*  /*age age2*/ married anyChild under6Child UScit USpr ///
		bayear bafield ba_supField bainst bacarn mayear mafield ma_supField mainst macarn phdcy_min phdfield phd_supField phdinst phdcarn prestat
sort refid refyr

save "${DATA}/DRF_SDR_ChangeWorkChar.dta", replace
