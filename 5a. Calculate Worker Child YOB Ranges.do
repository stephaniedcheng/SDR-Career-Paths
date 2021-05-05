/* CALCULATE WORKER'S CHILD YOB RANGES
Name: Stephanie D. Cheng
Date Created: 4-27-20
Date Updated 4-27-20

This .do file calculates each refid's kids' year-of-birth ranges, 
to be merged back onto the SDR data.

THIS VERSION ONLY INCLUDES SDR DATA, NOT DRF
	Considered adding DRF data ("5b. Worker Child YOB Ranges with DRF.do" in DEFUNCT) but they only started asking
	questions in 2001, and the age ranges are very large (under 6, 6-18, over 19) so doesn't add much information
	but complicates algorithm

*/

global MAIN "H:/SDC_Postdocs"
global DATA "${MAIN}/Data"
global RESULTS "${MAIN}/Results"
global TEMP "${MAIN}/Temp"

*** 1. IDENTIFY # OF CHILDREN EACH REFID HAS ***
use "${TEMP}/SDR_ChangeWorkChar.dta", clear
keep refid phdcy_min refyr ch* yob_*

// Drop if no info about kids
drop if chu2==. & ch25==. & ch6==. & ch611==. & ch1217==. & ch1218==. & ch18==. & ch19==.

// Create a set of indicators that are filled in for every age range kids in the family have passed
// E.g. If they're in the 6-11 age range, they've passed <2, 2-5, 6, 6-11

	// Fill in missing with zero
	foreach i in chu2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 {
		rename `i' `i'_ORIG
		
		gen `i' = `i'_ORIG
		replace `i' = 0 if `i'==.
	}
	rename chu2 ch2

	// Create tickers
	foreach i in 2 25 6 611 1217 1218 18 19 {
		gen chTicker`i' = 0
	}
	replace chTicker19 = ch19
	replace chTicker18 = ch18
	replace chTicker1218 = ch19 + ch1218
	replace chTicker1217 = ch18 + ch1217
	replace chTicker611 = ch19 + ch18 + ch1218 + ch1217 + ch611
	replace chTicker6 = ch18 + ch1217 + ch611 + ch6	// should only be for 1993
	replace chTicker25 = ch19 + ch18 + ch1218 + ch1217 + ch611 + ch6 + ch25
	replace chTicker2 = ch19 + ch18 + ch1218 + ch1217 + ch611 + ch6 + ch25 + ch2

	// SDR: Missing tickers if not asked in that year
	replace chTicker19 = . if refyr<2003
	replace chTicker1218 = . if refyr<2003
	replace chTicker18 = . if refyr>=2003
	replace chTicker1217 = . if refyr>=2003
	replace chTicker6 = . if refyr>1993
	
	// Examine how tickers change from year to year
	foreach i in 2 25 6 611 1217 1218 18 19 {
	    bys refid (refyr): gen chTickCh`i' = chTicker`i' - chTicker`i'[_n-1]
	}
	
	// The only reason you should ever see the numbers go down is if a child leaves
	// Can catch all except if child who leaves replaced by child in same age range
	egen childLeave = rowmin(chTickCh*)
	replace childLeave = 0 if childLeave>0
	replace childLeave = abs(childLeave)
	
	// Keep running sum of kids who leave
	bys refid (refyr): gen childLeft = sum(childLeave)

	// Total # of kids given by max ch2 + childLeft (since all kids in the row had to pass ch2 ticker)
	egen totCh_t = rowtotal(chTicker2 childLeft)
	bys refid: egen totCh = max(totCh_t)
	
// Drop cases with no kids (1993; other years already dropped since indicators missing)
drop if totCh==0

	// Distribution of # kids
	preserve
		keep refid phdcy_min totCh
		duplicates drop
		tab totCh
		save "${TEMP}/NumOfKids.dta", replace
		
			// Actually dropped majority of observations before (no kids)
			// 36.48% have 1 kid
			// 43.56% have 2 kids
			// 13.63% have 3 kids
			// 4.02% have 4 kids
			// 1.29% have 5 kids -> >99% of sample
	restore

// For simplicity, let's actually now break it up into 1-4 kids; hopefully by the time I've done 4 kids, I can extrapolate to 5+ (but if not, that's a very small sample)
forvalues i=1(1)5 {
    preserve
		keep if totCh==`i'
		save "${TEMP}/NumChild`i'.dta", replace
	restore
}

*** 2. START WITH ONLY 1 KID ***
use "${TEMP}/NumChild1.dta", clear

	// Since it's only 1 kid, it has to fit all of the possible age ranges given by the refid
	bys refid: egen yob_c01n = min(yob_c0)
	bys refid: egen yob_c01m = max(yob_c1)
	bys refid: egen yob_c25n = min(yob_c2)
	bys refid: egen yob_c25m = max(yob_c5)
	bys refid: egen yob_c611n = min(yob_c6)
	bys refid: egen yob_c611m = max(yob_c11)
	bys refid: egen yob_c1217n = min(yob_c12)
	bys refid: egen yob_c1217m = max(yob_c17)
	bys refid: egen yob_c1218n = min(yob_c12)
	bys refid: egen yob_c1218m = max(yob_c18)
	bys refid: egen yob_cL18n = min(yob_cL18)
	bys refid: egen yob_cL19n = min(yob_cL19)
	
	// Take the latest of the m's, earliest of the n's
	egen yob_earlyt = rowmax(yob_c*m)
	egen yob_latet = rowmin(yob_c*n)

	bys refid: egen yob_1early = max(yob_earlyt)
	bys refid: egen yob_1late = min(yob_latet)
	
	// Keep one copy for each refid
	keep refid yob_1early yob_1late
	duplicates drop
	
	// Some issues (likely timing of when surveys done?)
	gen issue1 = (yob_1early > yob_1late & yob_1early!=.)
	tab issue1	// 2.30% of kids
	
	save "${TEMP}/NumChild1 YOB Ranges.dta", replace

*** 3. NOW LOOK AT 2 KIDS ***
use "${TEMP}/NumChild2.dta", clear
br refid refyr ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 chTicker* chTickCh*

	/* Need to consider 3 cases:
		- new birth => youngest kid, all years before that only oldest kid
		- all kids in house
		- kid leaves => oldest kid, all years after that only youngest kid
	
	*/
	
	// Determine last new birth => if ticker goes up (after accounting for children leaving)
	egen newBirth = rowtotal(chTickCh2 childLeave)
	gen newBirthYr_t = refyr if newBirth>0
	bys refid: egen newBirthYr = max(newBirthYr_t)
	
		// If no birth year, born before 1993 -> replace missing with 0
		replace newBirthYr = 0 if newBirthYr==.

	// Determine survey year 1st child left
	gen leftChYr_t = refyr if childLeave>0
	bys refid: egen leftChYr = min(leftChYr_t)
	
	// Create indicators for youngest child
	foreach i in ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 indTot {
		gen `i'_c2 = 0	// create younger child's indicators and indicator for year found
	}

		// Find the first child indicator for each year
		foreach i in ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 {
			replace `i'_c2 = 1 if (`i'==1 | `i'==2) & refyr>=newBirthYr & indTot_c2==0
			replace indTot_c2 = 1 if `i'_c2==1
		}

	// Create indicators for oldest child
	foreach i in ch19 ch18 ch1218 ch1217 ch611 ch6 ch25 ch2 indTot {	
		gen `i'_c1 = 0 // create older child's indicators and indicator for year found
	}
	
		// Find last child indicator for each year
		foreach i in ch19 ch18 ch1218 ch1217 ch611 ch6 ch25 ch2 {
			replace `i'_c1 = 1 if (`i'==1 | `i'==2) & refyr<leftChYr & indTot_c1==0
			replace indTot_c1 = 1 if `i'_c1==1
		}
	
			* Double check that sum adds up to original indicators
			foreach i in ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 {
				egen `i'_check = rowtotal(`i'_c1 `i'_c2)
				gen `i'_FILL = `i'
				replace `i'_FILL = 0 if `i'==.
				count if `i'_check!=`i'_FILL
			}
	
	// For each kid, determine year cutoffs
	forvalues c=1(1)2 {
	    
		// Determine child year-of-births cutoffs (given available data on ages)
		foreach i in 0 1 2 5 6 11 12 17 18 {
			gen yob_`c'c`i' = refyr - `i'
		}
		foreach i in 18 19 {
			gen yob_`c'cL`i' = refyr - `i'	// do lower limit for ch18, ch19 so no overlap
		}
			
			// Replace with missing if don't have kids in that range
			replace yob_`c'c0 = . if (ch2_c`c'==0 & refyr>1993) | (ch6_c`c'==0 & refyr==1993)
			replace yob_`c'c1 = . if ch2_c`c'==0
			replace yob_`c'c2 = . if ch25_c`c'==0
			replace yob_`c'c5 = . if (ch25_c`c'==0 & refyr>1993) | (ch6_c`c'==0 & refyr==1993)
			replace yob_`c'c6 = . if ch611_c`c'==0
			replace yob_`c'c11 = . if ch611_c`c'==0
			replace yob_`c'c12 = . if (ch1217_c`c'==0 & refyr<2003) | (ch1218_c`c'==0 & refyr>=2003)
			replace yob_`c'c17 = . if ch1217_c`c'==0 | refyr>=2003
			replace yob_`c'c18 = . if ch1218_c`c'==0 | refyr<2003
			replace yob_`c'cL18 = . if ch18_c`c'==0 | refyr>=2003
			replace yob_`c'cL19 = . if ch19_c`c'==0 | refyr<2003
			
			// Has to fit all of the possible age ranges given by the refid
			bys refid: egen yob_`c'c01n = min(yob_`c'c0)
			bys refid: egen yob_`c'c01m = max(yob_`c'c1)
			bys refid: egen yob_`c'c25n = min(yob_`c'c2)
			bys refid: egen yob_`c'c25m = max(yob_`c'c5)
			bys refid: egen yob_`c'c611n = min(yob_`c'c6)
			bys refid: egen yob_`c'c611m = max(yob_`c'c11)
			bys refid: egen yob_`c'c1217n = min(yob_`c'c12)
			bys refid: egen yob_`c'c1217m = max(yob_`c'c17)
			bys refid: egen yob_`c'c1218n = min(yob_`c'c12)
			bys refid: egen yob_`c'c1218m = max(yob_`c'c18)
			bys refid: egen yob_`c'cL18n = min(yob_`c'cL18)
			bys refid: egen yob_`c'cL19n = min(yob_`c'cL19)
			
			// Take the latest of the m's, earliest of the n's
			egen yob_`c'earlyt = rowmax(yob_`c'c*m)
			egen yob_`c'latet = rowmin(yob_`c'c*n)

			bys refid: egen yob_`c'early = max(yob_`c'earlyt)
			bys refid: egen yob_`c'late = min(yob_`c'latet)
	}
	
	// Other limitation we know is that oldest must be > youngest
	rename yob_1late yob_1lateORIG
	
	gen yob_1late = yob_1lateORIG
	replace yob_1late = yob_2early if yob_1late > yob_2early
	
	// Keep one copy for each refid
	keep refid yob_*early yob_*late yob_1lateORIG
	order refid yob_1early yob_1late yob_1lateORIG yob_2early yob_2late
	duplicates drop
	
	// Some issues (likely timing of when surveys done?)
	gen issue1 = (yob_1early > yob_1late & yob_1early!=.)	// 4.52% of cases
	gen issue2 = (yob_2early > yob_2late & yob_2early!=.)	// 4.95% of cases
	gen issue12 = (yob_1early > yob_2early & yob_1early!=.)	// 0.43% of cases
	
	sum issue*
	
	save "${TEMP}/NumChild2 YOB Ranges.dta", replace	

*** 4. NOW 3 KIDS ***
use "${TEMP}/NumChild3.dta", clear
br refid refyr ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 chTicker* chTickCh*
	
	/* 
		The youngest will be the first indicator on the left side
		The oldest will be the first indicator on the right side
		The middle child will be the indicator left over in the middle
	*/
	
	// Determine last new birth => if ticker goes up (after accounting for children leaving)
	egen newBirth = rowtotal(chTickCh2 childLeave)
	gen newBirthYr_t = refyr if newBirth>0
	bys refid: egen newBirthYr = max(newBirthYr_t)
	
		// If no birth year, born before 1993 -> replace missing with 0
		replace newBirthYr = 0 if newBirthYr==.

	// Determine survey year 1st child left
	gen leftChYr_t = refyr if childLeave>0
	bys refid: egen leftChYr = min(leftChYr_t)
	
	// Create indicators for youngest child
	foreach i in ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 indTot {
		gen `i'_c3 = 0	// create younger child's indicators and indicator for year found
	}

		// Find the first child indicator for each year
		foreach i in ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 {
			replace `i'_c3 = 1 if `i'>0 & refyr>=newBirthYr & indTot_c3==0
			replace indTot_c3 = 1 if `i'_c3==1
		}

	// Create indicators for oldest child
	foreach i in ch19 ch18 ch1218 ch1217 ch611 ch6 ch25 ch2 indTot {	
		gen `i'_c1 = 0 // create older child's indicators and indicator for year found
	}
	
		// Find last child indicator for each year
		foreach i in ch19 ch18 ch1218 ch1217 ch611 ch6 ch25 ch2 {
			replace `i'_c1 = 1 if `i'>0 & refyr<leftChYr & indTot_c1==0
			replace indTot_c1 = 1 if `i'_c1==1
		}
	
	// Indicators for middle child on the ones left over
	foreach i in ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 {
		gen `i'_c2 = `i' - `i'_c1 - `i'_c3
	}	
	egen indTot_c2 = rowtotal(ch*_c2)
	
	// For each kid, determine year cutoffs
	forvalues c=1(1)3 {
	   
		// Determine child year-of-bigiven available data on ages)
		foreach i in 0 1 2 5 6 11 12 17 18 {
			gen yob_`c'c`i' = refyr - `i'
		}
		foreach i in 18 19 {
			gen yob_`c'cL`i' = refyr - `i'	// do lower limit for ch18, ch19 so no overlap
		}
			
			// Replace with missing if don't have kids in that range
			replace yob_`c'c0 = . if (ch2_c`c'==0 & refyr>1993) | (ch6_c`c'==0 & refyr==1993)
			replace yob_`c'c1 = . if ch2_c`c'==0
			replace yob_`c'c2 = . if ch25_c`c'==0
			replace yob_`c'c5 = . if (ch25_c`c'==0 & refyr>1993) | (ch6_c`c'==0 & refyr==1993)
			replace yob_`c'c6 = . if ch611_c`c'==0
			replace yob_`c'c11 = . if ch611_c`c'==0
			replace yob_`c'c12 = . if (ch1217_c`c'==0 & refyr<2003) | (ch1218_c`c'==0 & refyr>=2003)
			replace yob_`c'c17 = . if ch1217_c`c'==0 | refyr>=2003
			replace yob_`c'c18 = . if ch1218_c`c'==0 | refyr<2003
			replace yob_`c'cL18 = . if ch18_c`c'==0 | refyr>=2003
			replace yob_`c'cL19 = . if ch19_c`c'==0 | refyr<2003
			
			// Has to fit all of the possible age ranges given by the refid
			bys refid: egen yob_`c'c01n = min(yob_`c'c0)
			bys refid: egen yob_`c'c01m = max(yob_`c'c1)
			bys refid: egen yob_`c'c25n = min(yob_`c'c2)
			bys refid: egen yob_`c'c25m = max(yob_`c'c5)
			bys refid: egen yob_`c'c611n = min(yob_`c'c6)
			bys refid: egen yob_`c'c611m = max(yob_`c'c11)
			bys refid: egen yob_`c'c1217n = min(yob_`c'c12)
			bys refid: egen yob_`c'c1217m = max(yob_`c'c17)
			bys refid: egen yob_`c'c1218n = min(yob_`c'c12)
			bys refid: egen yob_`c'c1218m = max(yob_`c'c18)
			bys refid: egen yob_`c'cL18n = min(yob_`c'cL18)
			bys refid: egen yob_`c'cL19n = min(yob_`c'cL19)
			
			// Take the latest of the m's, earliest of the n's
			egen yob_`c'earlyt = rowmax(yob_`c'c*m)
			egen yob_`c'latet = rowmin(yob_`c'c*n)

			bys refid: egen yob_`c'early = max(yob_`c'earlyt)
			bys refid: egen yob_`c'late = min(yob_`c'latet)
	}	
	
	// Other limitation we know is that oldest > middle > youngest
	rename yob_1late yob_1lateORIG
	rename yob_2late yob_2lateORIG
	
	gen yob_1late = yob_1lateORIG
	replace yob_1late = yob_2early if yob_1late > yob_2early
	
	gen yob_2late = yob_2lateORIG
	replace yob_2late = yob_3early if yob_2late > yob_3early
	
	// Keep one copy for each refid
	keep refid yob_*early yob_*late yob_*lateORIG
	order refid yob_1early yob_1late yob_1lateORIG yob_2early yob_2late yob_2lateORIG yob_3early yob_3late
	duplicates drop
	
	// Some issues (likely timing of when surveys done?)
	forvalues i=1(1)3 {
		gen issue`i' = (yob_`i'early > yob_`i'late & yob_`i'early!=.)	    
	}
	gen issue12 = (yob_1early > yob_2early & yob_1early!=.)
	gen issue23 = (yob_2early > yob_3early & yob_2early!=.)
	
	sum issue*	
	
		// 5.36% of oldest (1), 10.43% of middle (2), 6.01% of youngest (3), 0.56% oldest < middle (12), 0.25% of middle < youngest (23)
	
	save "${TEMP}/NumChild3 YOB Ranges.dta", replace		

*** 5. NOW 4 KIDS ***	
use "${TEMP}/NumChild4.dta", clear
br refid refyr ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 chTicker* chTickCh*
	
	// Determine last new birth => if ticker goes up (after accounting for children leaving)
	egen newBirth = rowtotal(chTickCh2 childLeave)
	gen newBirthYr_t = refyr if newBirth>0
	bys refid: egen newBirthYr = max(newBirthYr_t)
	
		// If no birth year, born before 1993 -> replace missing with 0
		replace newBirthYr = 0 if newBirthYr==.

	// Determine survey year 1st child left
	gen leftChYr_t = refyr if childLeave>0
	bys refid: egen leftChYr = min(leftChYr_t)
	
	// Create indicators for youngest child
	foreach i in ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 indTot {
		gen `i'_c4 = 0	// create younger child's indicators and indicator for year found
	}

		// Find the first child indicator for each year
		foreach i in ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 {
			replace `i'_c4 = 1 if `i'>0 & refyr>=newBirthYr & indTot_c4==0
			replace indTot_c4 = 1 if `i'_c4==1
		}

	// Create indicators for oldest child
	foreach i in ch19 ch18 ch1218 ch1217 ch611 ch6 ch25 ch2 indTot {	
		gen `i'_c1 = 0 // create older child's indicators and indicator for year found
	}
	
		// Find last child indicator for each year
		foreach i in ch19 ch18 ch1218 ch1217 ch611 ch6 ch25 ch2 {
			replace `i'_c1 = 1 if `i'>0 & refyr<leftChYr & indTot_c1==0
			replace indTot_c1 = 1 if `i'_c1==1
		}
	
	// Subtract out the oldest and youngest indicators, repeat process
	foreach i in ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 {
		gen `i'_ROUND2 = `i' - `i'_c1 - `i'_c4
	}		
	
			// Determine 2nd to last new birth year -> first time at least 3 kids observed in household
			gen newBirthYr2_t = refyr if totCh_t>=3
			bys refid: egen newBirthYr2 = min(newBirthYr2_t)
			
				// If no birth year, born before 1993 -> replace missing with 0
				replace newBirthYr2 = 0 if newBirthYr2==.

			// Determine survey year 2nd child left
			gen leftChYr2_t = refyr if childLeft>=2 & childLeft[_n-1]<2
			bys refid: egen leftChYr2 = min(leftChYr2_t)
	
		// Create indicators for second youngest child
		foreach i in ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 indTot {
			gen `i'_c3 = 0	// create younger child's indicators and indicator for year found
		}

			// Find the first child indicator for each year
			foreach i in ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 {
				replace `i'_c3 = 1 if `i'_ROUND2>0 & refyr>=newBirthYr2 & indTot_c3==0
				replace indTot_c3 = 1 if `i'_c3==1
			}

		// Create indicators for second oldest child
		foreach i in ch19 ch18 ch1218 ch1217 ch611 ch6 ch25 ch2 indTot {	
			gen `i'_c2 = 0 // create older child's indicators and indicator for year found
		}
		
			// Find second oldest child indicator for each year
			foreach i in ch19 ch18 ch1218 ch1217 ch611 ch6 ch25 ch2 {
				replace `i'_c2 = 1 if `i'_ROUND2>0 & refyr<leftChYr2 & indTot_c2==0
				replace indTot_c2 = 1 if `i'_c2==1
			}
	
	// For each kid, determine year cutoffs
	forvalues c=1(1)4 {
	   
		// Determine child year-of-bigiven available data on ages)
		foreach i in 0 1 2 5 6 11 12 17 18 {
			gen yob_`c'c`i' = refyr - `i'
		}
		foreach i in 18 19 {
			gen yob_`c'cL`i' = refyr - `i'	// do lower limit for ch18, ch19 so no overlap
		}
			
			// Replace with missing if don't have kids in that range
			replace yob_`c'c0 = . if (ch2_c`c'==0 & refyr>1993) | (ch6_c`c'==0 & refyr==1993)
			replace yob_`c'c1 = . if ch2_c`c'==0
			replace yob_`c'c2 = . if ch25_c`c'==0
			replace yob_`c'c5 = . if (ch25_c`c'==0 & refyr>1993) | (ch6_c`c'==0 & refyr==1993)
			replace yob_`c'c6 = . if ch611_c`c'==0
			replace yob_`c'c11 = . if ch611_c`c'==0
			replace yob_`c'c12 = . if (ch1217_c`c'==0 & refyr<2003) | (ch1218_c`c'==0 & refyr>=2003)
			replace yob_`c'c17 = . if ch1217_c`c'==0 | refyr>=2003
			replace yob_`c'c18 = . if ch1218_c`c'==0 | refyr<2003
			replace yob_`c'cL18 = . if ch18_c`c'==0 | refyr>=2003
			replace yob_`c'cL19 = . if ch19_c`c'==0 | refyr<2003
			
			// Has to fit all of the possible age ranges given by the refid
			bys refid: egen yob_`c'c01n = min(yob_`c'c0)
			bys refid: egen yob_`c'c01m = max(yob_`c'c1)
			bys refid: egen yob_`c'c25n = min(yob_`c'c2)
			bys refid: egen yob_`c'c25m = max(yob_`c'c5)
			bys refid: egen yob_`c'c611n = min(yob_`c'c6)
			bys refid: egen yob_`c'c611m = max(yob_`c'c11)
			bys refid: egen yob_`c'c1217n = min(yob_`c'c12)
			bys refid: egen yob_`c'c1217m = max(yob_`c'c17)
			bys refid: egen yob_`c'c1218n = min(yob_`c'c12)
			bys refid: egen yob_`c'c1218m = max(yob_`c'c18)
			bys refid: egen yob_`c'cL18n = min(yob_`c'cL18)
			bys refid: egen yob_`c'cL19n = min(yob_`c'cL19)
			
			// Take the latest of the m's, earliest of the n's
			egen yob_`c'earlyt = rowmax(yob_`c'c*m)
			egen yob_`c'latet = rowmin(yob_`c'c*n)

			bys refid: egen yob_`c'early = max(yob_`c'earlyt)
			bys refid: egen yob_`c'late = min(yob_`c'latet)
	}		
	
	// Other limitation we know is that oldest > middle > youngest
	forvalues i=1(1)3 {
	    local j = `i'+1
	    rename yob_`i'late yob_`i'lateORIG
		
		gen yob_`i'late = yob_`i'lateORIG
		replace yob_`i'late = yob_`j'early if yob_`i'late > yob_`j'early
	}
	
	// Keep one copy for each refid
	keep refid yob_*early yob_*late yob_*lateORIG
	order refid yob_1early yob_1late yob_1lateORIG yob_2early yob_2late yob_2lateORIG yob_3early yob_3late yob_3lateORIG yob_4early yob_4late
	duplicates drop
	
	// Some issues (likely timing of when surveys done?)
	forvalues i=1(1)4 {
		gen issue`i' = (yob_`i'early > yob_`i'late & yob_`i'early!=.)	    
	}
	forvalues i=1(1)3 {
	    local j = `i'+1
		gen issue`i'`j' = (yob_`i'early > yob_`j'early & yob_`i'early!=.)
	}

	sum issue*		
	
	save "${TEMP}/NumChild4 YOB Ranges.dta", replace		
	
*** 6. NOW 5 KIDS ***
use "${TEMP}/NumChild5.dta", clear
br refid refyr ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 chTicker* chTickCh*
	
	// Determine last new birth => if ticker goes up (after accounting for children leaving)
	egen newBirth = rowtotal(chTickCh2 childLeave)
	gen newBirthYr_t = refyr if newBirth>0
	bys refid: egen newBirthYr = max(newBirthYr_t)
	
		// If no birth year, born before 1993 -> replace missing with 0
		replace newBirthYr = 0 if newBirthYr==.

	// Determine survey year 1st child left
	gen leftChYr_t = refyr if childLeave>0
	bys refid: egen leftChYr = min(leftChYr_t)
	
	// Create indicators for youngest child
	foreach i in ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 indTot {
		gen `i'_c5 = 0	// create younger child's indicators and indicator for year found
	}

		// Find the first child indicator for each year
		foreach i in ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 {
			replace `i'_c5 = 1 if `i'>0 & refyr>=newBirthYr & indTot_c5==0
			replace indTot_c5 = 1 if `i'_c5==1
		}

	// Create indicators for oldest child
	foreach i in ch19 ch18 ch1218 ch1217 ch611 ch6 ch25 ch2 indTot {	
		gen `i'_c1 = 0 // create older child's indicators and indicator for year found
	}
	
		// Find last child indicator for each year
		foreach i in ch19 ch18 ch1218 ch1217 ch611 ch6 ch25 ch2 {
			replace `i'_c1 = 1 if `i'>0 & refyr<leftChYr & indTot_c1==0
			replace indTot_c1 = 1 if `i'_c1==1
		}
	
	// Subtract out the oldest and youngest indicators, repeat process
	foreach i in ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 {
		gen `i'_ROUND2 = `i' - `i'_c1 - `i'_c5
	}		
	
			// Determine 2nd to last new birth year -> first time at least 4 kids observed in household
			gen newBirthYr2_t = refyr if totCh_t>=4
			bys refid: egen newBirthYr2 = min(newBirthYr2_t)
			
				// If no birth year, born before 1993 -> replace missing with 0
				replace newBirthYr2 = 0 if newBirthYr2==.

			// Determine survey year 2nd child left
			gen leftChYr2_t = refyr if childLeft>=2 & childLeft[_n-1]<2
			bys refid: egen leftChYr2 = min(leftChYr2_t)
	
		// Create indicators for second youngest child
		foreach i in ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 indTot {
			gen `i'_c4 = 0	// create younger child's indicators and indicator for year found
		}

			// Find the first child indicator for each year
			foreach i in ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 {
				replace `i'_c4 = 1 if `i'_ROUND2>0 & refyr>=newBirthYr2 & indTot_c4==0
				replace indTot_c4 = 1 if `i'_c4==1
			}

		// Create indicators for second oldest child
		foreach i in ch19 ch18 ch1218 ch1217 ch611 ch6 ch25 ch2 indTot {	
			gen `i'_c2 = 0 // create older child's indicators and indicator for year found
		}
		
			// Find second oldest child indicator for each year
			foreach i in ch19 ch18 ch1218 ch1217 ch611 ch6 ch25 ch2 {
				replace `i'_c2 = 1 if `i'_ROUND2>0 & refyr<leftChYr2 & indTot_c2==0
				replace indTot_c2 = 1 if `i'_c2==1
			}	
	
		// Indicators for middle child on the ones left over
		foreach i in ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 {
			gen `i'_c3 = `i' - `i'_c1 - `i'_c2 - `i'_c4 - `i'_c5
		}	
		egen indTot_c3 = rowtotal(ch*_c3)
	
	// For each kid, determine year cutoffs
	forvalues c=1(1)5 {
	   
		// Determine child year-of-bigiven available data on ages)
		foreach i in 0 1 2 5 6 11 12 17 18 {
			gen yob_`c'c`i' = refyr - `i'
		}
		foreach i in 18 19 {
			gen yob_`c'cL`i' = refyr - `i'	// do lower limit for ch18, ch19 so no overlap
		}
			
			// Replace with missing if don't have kids in that range
			replace yob_`c'c0 = . if (ch2_c`c'==0 & refyr>1993) | (ch6_c`c'==0 & refyr==1993)
			replace yob_`c'c1 = . if ch2_c`c'==0
			replace yob_`c'c2 = . if ch25_c`c'==0
			replace yob_`c'c5 = . if (ch25_c`c'==0 & refyr>1993) | (ch6_c`c'==0 & refyr==1993)
			replace yob_`c'c6 = . if ch611_c`c'==0
			replace yob_`c'c11 = . if ch611_c`c'==0
			replace yob_`c'c12 = . if (ch1217_c`c'==0 & refyr<2003) | (ch1218_c`c'==0 & refyr>=2003)
			replace yob_`c'c17 = . if ch1217_c`c'==0 | refyr>=2003
			replace yob_`c'c18 = . if ch1218_c`c'==0 | refyr<2003
			replace yob_`c'cL18 = . if ch18_c`c'==0 | refyr>=2003
			replace yob_`c'cL19 = . if ch19_c`c'==0 | refyr<2003
			
			// Has to fit all of the possible age ranges given by the refid
			bys refid: egen yob_`c'c01n = min(yob_`c'c0)
			bys refid: egen yob_`c'c01m = max(yob_`c'c1)
			bys refid: egen yob_`c'c25n = min(yob_`c'c2)
			bys refid: egen yob_`c'c25m = max(yob_`c'c5)
			bys refid: egen yob_`c'c611n = min(yob_`c'c6)
			bys refid: egen yob_`c'c611m = max(yob_`c'c11)
			bys refid: egen yob_`c'c1217n = min(yob_`c'c12)
			bys refid: egen yob_`c'c1217m = max(yob_`c'c17)
			bys refid: egen yob_`c'c1218n = min(yob_`c'c12)
			bys refid: egen yob_`c'c1218m = max(yob_`c'c18)
			bys refid: egen yob_`c'cL18n = min(yob_`c'cL18)
			bys refid: egen yob_`c'cL19n = min(yob_`c'cL19)
			
			// Take the latest of the m's, earliest of the n's
			egen yob_`c'earlyt = rowmax(yob_`c'c*m)
			egen yob_`c'latet = rowmin(yob_`c'c*n)

			bys refid: egen yob_`c'early = max(yob_`c'earlyt)
			bys refid: egen yob_`c'late = min(yob_`c'latet)
	}		

	// Other limitation we know is that oldest > middle > youngest
	forvalues i=1(1)4 {
	    local j = `i'+1
	    rename yob_`i'late yob_`i'lateORIG
		
		gen yob_`i'late = yob_`i'lateORIG
		replace yob_`i'late = yob_`j'early if yob_`i'late > yob_`j'early
	}
	
	// Keep one copy for each refid
	keep refid yob_*early yob_*late yob_*lateORIG
	order refid yob_1early yob_1late yob_1lateORIG yob_2early yob_2late yob_2lateORIG yob_3early yob_3late yob_3lateORIG yob_4early yob_4late yob_4lateORIG yob_5early yob_5late
	duplicates drop
	
	// Some issues (likely timing of when surveys done?)
	forvalues i=1(1)5 {
		gen issue`i' = (yob_`i'early > yob_`i'late & yob_`i'early!=.)	    
	}
	forvalues i=1(1)4 {
	    local j = `i'+1
		gen issue`i'`j' = (yob_`i'early > yob_`j'early & yob_`i'early!=.)
	}

	sum issue*		

	save "${TEMP}/NumChild5 YOB Ranges.dta", replace		
	
*** 7. CREATE ONE DATA FILE WITH KID RANGES ***
use "${TEMP}/NumChild1 YOB Ranges.dta", clear

forvalues i=2(1)5 {
	append using "${TEMP}/NumChild`i' YOB Ranges.dta"
}	
	
order refid yob_1* yob_2* yob_3* yob_4* yob_5* issue*	
	
save "${DATA}/SDR Child YOB 1-5.dta", replace	
	
/* DEFUNCT	

	
	// Double check that sum adds up to original indicators
	foreach i in ch2 ch25 ch6 ch611 ch1217 ch1218 ch18 ch19 {
		gen `i'_check = `i'_c1 + `i'_c2 + `i'_c3 + `i'_c4
		gen `i'_FILL = `i'
		replace `i'_FILL = 0 if `i'==.
		count if `i'_check!=`i'_FILL
	}


// Count # of kids each year
egen totCh1993 = rowtotal(ch6 ch611 ch1217 ch18) if refyr==1993
egen totCh2001 = rowtotal(chu2 ch25 ch611 ch1217 ch1218 ch18) if refyr>1993 & refyr<=2001
egen totCh2003 = rowtotal(chu2 ch25 ch611 ch1218 ch19) if refyr>=2003

gen totCh = totCh1993
replace totCh = totCh2001 if totCh==.
replace totCh = totCh2003 if totCh==.

	// If total kids change, either birth (-) or child leave (+)
	sort refid refyr
	by refid: gen kidCh = totCh[_n-1] - totCh
	
	gen newBirth = abs(kidCh) if kidCh<0 & kidCh!=.
	replace newBirth = 0 if newBirth==.
	
	gen leaveCh = kidCh if kidCh>0 & kidCh!=.
	replace leaveCh = 0 if leaveCh==.

	// Actually, could have new birth offset child leave...
	
	
	// Keep running sum of how many kids leave (so accurate counts of kids)
	bys refid (refyr): gen leftCh = sum(leaveCh)
	
// Overall, how many kids observed
gen allCh = totCh + leftCh
bys refid: egen allCh_EO = max(allCh)


	// Determine first survey year with new birth
	sort refid refyr
	by refid: gen newBirth_t = refyr if totCh==totCh_EO & totCh[_n-1]<totCh_EO
	by refid: egen newBirth = max(newBirth_t)
	replace newBirth=1992 if newBirth==.	// just to make sure youngest is included if born before 1993
	
	// Determine first survey year with first kid leaving
	sort refid refyr
	by refid: gen childLeave_t = refyr if totCh[_n-1]==totCh_EO & totCh==1
	by refid: egen childLeave = max(childLeave_t)

	// Create indicators for youngest child
		foreach i in chu2 ch25 ch6 ch611 ch1217 ch1218 indTot {
			gen `i'_c2 = 0	// create younger child's indicators and indicator for year found
		}

		// Find the first child indicator for each year
		foreach i in chu2 ch25 ch6 ch611 ch1217 ch1218 {
			replace `i'_c2 = 1 if (`i'==1 | `i'==2) & refyr>=newBirth & indTot_c2==0
			replace indTot_c2 = 1 if `i'_c2==1
		}

	// Create indicators for oldest child
	foreach i in ch1218 ch1217 ch611 ch6 ch25 chu2 indTot {
	    gen `i'_c1 = 0 // create oldest child's indicators and indicator for year found
	}
	
	// Find the last child indicator for each year
	foreach i in ch1218 ch1217 ch611 ch6 ch25 chu2 {
			replace `i'_c1 = 1 if (`i'==1 | `i'==2) & refyr<childLeave & indTot_c1==0
			replace indTot_c1 = 1 if `i'_c1==1	    
	}
	
	// Double check that sum adds up to original indicators
	foreach i in chu2 ch25 ch6 ch611 ch1217 ch1218 {
		gen `i'_check = `i'_c1 + `i'_c2
		gen `i'_FILL = `i'
		replace `i'_FILL = 0 if `i'==.
		count if `i'_check!=`i'_FILL
	}
	
	

	

	

/* DEFUNCT
	// If value doesn't change from year to year, take max of earliest year + min of latest year
	foreach i in chu2 ch25 ch6 ch611 ch1217 ch1218 {
	   
	   gen NC_`i' = 0 if `i'[_n]!=.
	   
	   sort refid refyr
	   by refid: replace NC_`i' = 1 if `i'[_n]==`i'[_n-1] & `i'[_n]>0 & `i'[_n-1]!=.	// identify don't change down
	   gsort refid -refyr
	   by refid: replace NC_`i' = 1 if `i'[_n]==`i'[_n-1] & `i'[_n]>0 & `i'[_n-1]!=.	// identify don't change up
	   
	}
	
	bys refid: egen max_chu2 = min()
	
// Determine children year-of-birth range (min of earliest year from each range, max of latest year from each range)
	