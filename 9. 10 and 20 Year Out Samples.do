/* 9. 10 AND 20 YEAR OUT SAMPLES
Name: Stephanie D. Cheng
Date Created: 5-29-20
Date Updated: 5-29-20

This .do file cuts the sample down to:
	1) The first 10 years after the PhD
	2) The first 20 years since starting grad school / PhD
	
This is meant to standardize the amount of time that individuals have to transition to jobs.

*/

global MAIN "H:/SDC_Postdocs"
global DATA "${MAIN}/Data"
global RESULTS "${MAIN}/Results"
global TEMP "${MAIN}/Temp"

*** 1a. 10 YEARS AFTER PHD GRADUATION - OOI ***
use "${DATA}/OOI_workingsample.dta", clear

	// Calculate years out from PhD grad
	gen yrsOut = refyr - phdcy_min
	
	// Only keep first 10 years
	drop if yrsOut>10
	
	// Only keep if have been at least 10 years
	bys refid: egen maxYrsOut = max(yrsOut)
	drop if maxYrsOut<10

		// Count how many in each cohort left
		preserve
			keep refid phdcy_min
			duplicates drop
			tab phdcy_min	// can do 1947-2005
		restore
	
	// Only keep if have some job info besides year graduated (because that's from DRF) in the first 10 years after PhD
	gen NIiNGY = NIi if yrsOut!=0
	bys refid: egen minNIiNGY = min(NIiNGY)
	
	drop if minNIiNGY!=0
	
		// Count how many in each cohort left
		preserve
			keep refid phdcy_min
			duplicates drop
			tab phdcy_min	// can do 1954-2005 -> pretty happy with this
		restore
	
save "${TEMP}/10YearsOut_NoJobTransitions.dta", replace

*** 1b. 10 YEARS AFTER PHD GRADUATION - TRANSITIONS ***
use "${DATA}/DRF_SDR_JobTypeInd_FULL.dta", clear

	// Don't need salary and weights
	drop salary0i SALi* WTi* 
	
	// Identify 10 years after PhD graduation
	gen out10 = phdcy_min + 10
	
	// For anything 10 years after PhD graduation, replace with missing
	forvalues yr=1942(1)2015 {
	    foreach i in PDi ACi TEi GVi IDi NPi UNi NLi NIi {
			replace `i'`yr' = . if `yr'>out10
		}
	}
	
	// CODE FOR NEW JOBS - from "4. Job Type Indicators.do"
	foreach i in PD AC TE GV ID NP UN NL {

		// First job start
		gen `i's1 = .
		forvalues yr=1942(1)2015 {
			replace `i's1 = `yr' if `i's1==. & (`i'i`yr'==6 | (`i'i`yr'==1 & `yr'-phdcy_min<=1 & `yr'-phdcy_min>=0))	// either 1st job or from DRF
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

	// CODE FOR JOB TRANSITIONS - from "4. Job Type Indicators.do"
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
	
	save "${TEMP}/10YearsOut_AddJobTransitions.dta", replace
	
*** 1c. 10 YEARS AFTER PHD GRADUATION - FULL ***
use "${TEMP}/10YearsOut_AddJobTransitions.dta", clear
keep refid PDt*s ACt*s TEt*s IDt*s GVt*s NPt*s UNt*s NLt*s

merge 1:m refid using "${TEMP}/10YearsOut_NoJobTransitions.dta"
keep if _merge==3	// should drop people who don't have enough info in first 10 years after PhD
drop _merge

// Order by worker characteristics, then transitions
order refid refyr wtsurvy* DRForig SDRorig birthdate byear bplace* male R_* age age2 married anyChild under6Child yob_* USnative USnatur UScit USpr USnupr cntrycit ///
		bayear bafield ba_supField bainst* bacarn* mayear mafield ma_supField mainst* macarn* phdcy_min phdfield phd_supField gradYrs geyear phdentry phdinst* phdcarn* fundField prestat yrs* state1 instcod_n1 instcod_city1

save "${DATA}/OOI_10YearsOut_transitions.dta", replace

*** 1d. Identify the individuals who have 10 years of data - can drop others from data ***
use "${DATA}/OOI_10YearsOut_transitions.dta", clear
keep refid
duplicates drop
save "${TEMP}/OOI_10YearsRefids.dta", replace