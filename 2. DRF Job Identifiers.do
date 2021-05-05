/* 2. Identify Job via DRF
Name: Stephanie D. Cheng
Date Created: 12-3-18
Date Updated: 3-19-19

This .do file identifies job plans after graduation from the DRF. It uses
this information to create identifiers for whether an individual goes into
a postdoc (using Ginther & Kahn methodology), tenure-track academia, gov,
industry, unemployment, or not in labor force.

*/

global MAIN "H:/SDC_Postdocs"
global DATA "${MAIN}/Data"
global RESULTS "${MAIN}/Results"
global TEMP "${MAIN}/Temp"

*** 1. IDENTIFY JOB PLANS IMMEDIATELY AFTER GRADUATION ***
use "${DATA}/sdrdrf_FULL.dta", clear

// Add back other information from sdrdrf
foreach yr in 93 95 97 99 01 03 06 08 10 13 15 {
	preserve
		keep if sdrdrf_yr=="`yr'"
		
		if inlist(`yr', 93) {
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(drfempty drfpdpl drfpdst)
			
			// Adjust variables to match later years
			rename drfpdpl pdocplan	
			rename drfpdst pdocstat
		
			gen pdemploy = drfempty
			replace pdemploy = "F" if drfempty=="B"
			replace pdemploy = "G" if drfempty=="F"
			replace pdemploy = "H" if drfempty=="G"
			replace pdemploy = "I" if drfempty=="H"
			replace pdemploy = "J" if drfempty=="I"
			replace pdemploy = "K" if drfempty=="J"
			replace pdemploy = "L" if drfempty=="K"
			replace pdemploy = "M" if drfempty=="L"
			replace pdemploy = "N" if drfempty=="M"
		}
		if inlist(`yr', 95, 97, 99, 01) {
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(pdemploy pdocplan pdocstat)
			
			// Adjust variables to match later years
			tostring pdocplan pdocstat, replace
			
			rename pdemploy pdemployORIG
			gen pdemploy = pdemployORIG
			replace pdemploy = "F" if pdemployORIG=="B"
			replace pdemploy = "G" if pdemployORIG=="F"
			replace pdemploy = "H" if pdemployORIG=="G"
			replace pdemploy = "I" if pdemployORIG=="H"
			replace pdemploy = "J" if pdemployORIG=="I"
			replace pdemploy = "K" if pdemployORIG=="J"
			replace pdemploy = "L" if pdemployORIG=="K"
			replace pdemploy = "M" if pdemployORIG=="L"
			replace pdemploy = "N" if pdemployORIG=="M"			
		}
		if inlist(`yr', 03, 06, 08) {
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(pdemploy pdocplan pdocstat)
			
			// Adjust variables to match later years
			tostring pdocplan pdocstat, replace
		}
		if inlist(`yr', 10, 13, 15) {
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(pdemploy pdocplan pdocstat salary*)	
			
			// Adjust variables to match later years
			tostring pdocplan pdocstat, replace
		}
		keep if _merge==3
		drop _merge
		
		save "${TEMP}/sdrdrf`yr'_JobPlan.dta", replace
	restore
}

// Append together
use "${TEMP}/sdrdrf93_JobPlan.dta", clear
foreach yr in 95 97 99 01 03 06 08 10 13 15 {
	append using "${TEMP}/sdrdrf`yr'_JobPlan.dta"
}

	// Indicate job commitment (using Ginther & Kahn's methodology: if returning to employment, signed contract, or in negotiations
	gen pdoc_have = (pdocstat=="0" | pdocstat=="1" | pdocstat=="2")
	replace pdoc_have = . if pdocstat==""

	/* Create post-graduation job type identifiers:
		PD: Postdoc (given by Ginther & Kahn's methodology)
		AC: Tenure-track academic
		TE: Teaching
		ID: For profit industry
		NP: Non-profit
		GV: Government
		NL: Not in labor force
	*/
	gen PD0i = max(pdoc_have==1 & (pdocplan=="0" | pdocplan=="1" | pdocplan=="2" | pdocplan=="3"),pdoc_have==1 & (pdocplan=="4" & phdcy_min>=2004))
	gen AC0i = pdoc_have==1 & (PD==0 & (pdemploy=="A" | pdemploy=="B" | pdemploy=="C" | pdemploy=="4"))
	gen TE0i = pdoc_have==1 & (PD==0 & AC==0 & (pdemploy=="D" | pdemploy=="E" | pdemploy=="F"))
	gen ID0i = pdoc_have==1 & (pdemploy=="L" | pdemploy=="M")
	gen NP0i = pdoc_have==1 & (pdemploy=="K" | pdemploy=="N")
	gen GV0i = pdoc_have==1 & (pdemploy=="G" | pdemploy=="H" | pdemploy=="I" | pdemploy=="J" | pdemploy=="1" | pdemploy=="2" | pdemploy=="3")
	gen NL0i = ((pdocstat=="4" & sdrdrf_fullYr<2008) | (pdocstat=="5" & sdrdrf_fullYr>=2008))
	gen UN0i = .

	// Set as missing if don't have job commitment
	foreach i in PD AC TE ID NP GV NL UN {
		replace `i'0i = . if pdoc_have==0
	}
	
// Give expected salary -> really seems like should be in job characteristics...
replace salaryr = salary if salaryr==. & salary!=.	// combine 2010 variables into 2013/2015 variables

gen salary0i = salaryv
replace salary0i = 15000 if salaryr==0 & salary0i==.
replace salary0i = 33000 if salaryr==1 & salary0i==.
replace salary0i = 38000 if salaryr==2 & salary0i==.
replace salary0i = 45000 if salaryr==3 & salary0i==.
replace salary0i = 55000 if salaryr==4 & salary0i==.
replace salary0i = 65000 if salaryr==5 & salary0i==.
replace salary0i = 75000 if salaryr==6 & salary0i==.
replace salary0i = 85000 if salaryr==7 & salary0i==.
replace salary0i = 95000 if salaryr==8 & salary0i==.
replace salary0i = 105000 if salaryr==9 & salary0i==.
replace salary0i = 110000 if salaryr==10 & salary0i==.
replace salary0i = . if salaryr==11 | salaryr==99 | salaryv==999998

save "${DATA}/DRF_JobTypes.dta", replace
