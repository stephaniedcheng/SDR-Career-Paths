/* 10. Clean Full DRF Data
Name: Stephanie D. Cheng
Date Created: 6-1-20
Date Updated: 6-1-20

This .do file cleans the full DRF file. 

*/

global FIELD "Bio Sciences"

global MAIN "H:/SDC_Postdocs"
global DATA "${MAIN}/Data"
global RESULTS_DRF "${MAIN}/Results/Full DRF"
global TEMP "${MAIN}/Temp"
global LOOKUPS "${MAIN}/Lookups"


*** 1. Clean DRF data ***
use "${DATA}/Stata/NEW_NOID2018.dta", clear

	// Make all variables lowercase
	rename *, lower
	rename phdcy phdcy_min
	
	// Gender Indicators
	gen male = (sex=="1")
	replace male = . if sex==""
	gen female = (sex=="2")
	replace female = . if sex==""	
	
		// Label variables
		label define female 1 "Female" 0 "Male",modify
		label val female female
	
	// Race indicators
	gen R_white = (race==10)
	gen R_hisp = (race>=6 & race<=9)
	gen R_black = (race==5)
	gen R_asian = (race>=2 & race<=4)
	gen R_namer = (race==1)
	gen R_other = (race==11 | race==12)

	foreach i in white hisp black asian namer other {
		replace R_`i' = . if race==. | race==-1	// missing race info
	}
			
	// US citizenship status
	gen USnative = (citiz=="0" | citiz=="P")	// will include naturalized prior to 1967, Puerto Ricans; doesn't include unspecified US citizens
	replace USnative = . if citiz==""
	
	gen USnatur = (citiz=="1")
	replace USnatur = . if citiz==""
	
	gen USpr = (citiz=="2" | citiz=="A")	// includes citizenship applied for
	replace USpr = . if citiz==""
	
	gen USnupr = (citiz=="3" | citiz=="4")		// includes visa status unknown
	replace USnupr = . if citiz==""
	
	// Marital Status
	gen married = (marital==1)
	replace married = . if marital==.

	// Any Children
	gen anyChild = (depends>0 & depends!=.)
	replace anyChild = 1 if depend5>0 & depend5!=.
	replace anyChild = 1 if depend18>0 & depend18!=.
	replace anyChild = . if depends==. & depend5==. & depend18==.	
	
	// Disabilities
	
	
	// Rough count of # children
	egen numChild = rowtotal(depend5 depend18 depend19)
	replace numChild = depends if depend5==. & depend18==. & depend19==.
	
	// Simplify fields
	foreach i in ba ma phd {
		gen `i'_supField = ""
			replace `i'_supField = "Agriculture" if `i'field<=99
			replace `i'_supField = "Bio Sciences" if `i'field>=100 & `i'field<=199
			replace `i'_supField = "Health Sciences" if `i'field>=200 & `i'field<=299
			replace `i'_supField = "Engineering" if `i'field>=300 & `i'field<=399
			replace `i'_supField = "Comp Sci" if `i'field>=400 & `i'field<=410
			replace `i'_supField = "Math" if `i'field>=420 & `i'field<=499
			replace `i'_supField = "Other Phys Sci" if (`i'field>=500 & `i'field<=519) | (`i'field>=540 & `i'field<=559) | (`i'field>=580 & `i'field<=599)
			replace `i'_supField = "Chemistry" if `i'field>=520 & `i'field<=539
			replace `i'_supField = "Physics" if `i'field>=560 & `i'field<=579
			replace `i'_supField = "Psychology" if `i'field>=600 & `i'field<=649
			replace `i'_supField = "Economics" if `i'field==667 | `i'field==668
			replace `i'_supField = "Other Social Sciences" if `i'_supField=="" & `i'field>=650 & `i'field<=699
			replace `i'_supField = "Humanities" if `i'field>=700 & `i'field<=799
			replace `i'_supField = "Education" if `i'field>=800 & `i'field<=899
			replace `i'_supField = "Professional Fields" if `i'field>=900 & `i'field<=989
	}
	
	// Age at doctorate
	gen agePhD = phdcy_min - birthyr // this is basically the same as how agedoc is created, yet there are some weird results in agedoc if don't have phdmonth or birthmo, so use this
	
	/* Time spent in PhD
		TTDGEPHD: 2004-present, time from grad school entry to doctorate (uses geyear)
		TTDDOC: 2014-present, time from PhD entry (or most recent master's, if same institution + field of study) to doctorate (uses MAYEAR, PHDEYEAR)
		
		GEYEAR: 1958-present
		PHDEYEAR: 1993-present
	
		TOGEPHD: 1958-2003, time out between start grad school and doctorate
		TOMAPHD: 1969-2003, time out between first master's degree and doctorate
		
	*/
	
	// Add in missing values from given formula
	replace ttdgephd = phdcy - geyear if ttdgephd==.	// can get back to 1957
	
	replace ttddoc = phdcy - phdeyear if ttddoc==.
	replace ttddoc = phdcy - mayear if ttddoc==. & mainst==phdinst & mafield==phdfield	// can also get to about 1957
	
	gen gradYrs = phdcy - geyear - cond(missing(togephd),0,togephd)	// basically same as ttdgephd - togephd, sometimes off by 1 since don't use months
	replace gradYrs = . if gradYrs<0	// 61 cases, especially in early days...
	
	// Clean sources of support
	rename srce1ed srce1ed_ORIG
	merge m:1 srce1ed_ORIG using "${LOOKUPS}/SED Funding Source SRCE1ED.dta"
	drop _merge
	
		// Break into indicators
		gen srce_TA = (srce1ed=="C")
		gen srce_RA = (srce1ed=="D" | srce1ed=="E" | srce1ed=="F" | srce1ed=="G")
		gen srce_FS = (srce1ed=="A" | srce1ed=="B")
		gen srce_OR = (srce1ed=="H" | srce1ed=="I" | srce1ed=="J" | srce1ed=="K")
		gen srce_FG = (srce1ed=="M")
		gen srce_ID = (srce1ed=="L")
		gen srce_OT = (srce1ed=="N")
		
		foreach i in TA RA FS OR FG ID OT {
			replace srce_`i' = . if srce1ed==""
		}
	
	// Indicate job commitment (using Ginther & Kahn's methodology: if returning to employment, signed contract, or in negotiations (or has postdoc fellowship for 1958-1968)
	gen pdoc_have = (pdocstat=="0" | pdocstat=="1" | pdocstat=="2" | pdocstat=="A")
	replace pdoc_have = . if pdocstat=="" | phdcy_min<1958
	
	/* Create post-graduation job type identifiers:
		PD: Postdoc (given by Ginther & Kahn's methodology)
		AC: Tenure-track academic
		TE: Teaching
		ID: For profit industry
		NP: Non-profit
		GV: Government
		NL: Not in labor force
	*/
	gen PD0i = max(pdoc_have==1 & (pdocplan==0 | pdocplan==1 | pdocplan==2 | pdocplan==3),pdoc_have==1 & (pdocplan==4 & phdcy_min>=2004),pdocstat=="A")
	gen AC0i = pdoc_have==1 & (PD==0 & (pdemploy=="A" | pdemploy=="B" | pdemploy=="C" | pdemploy=="4"))
	gen TE0i = pdoc_have==1 & (PD==0 & AC==0 & (pdemploy=="D" | pdemploy=="E" | pdemploy=="F"))
	gen ID0i = pdoc_have==1 & (pdemploy=="L" | pdemploy=="M")
	gen NP0i = pdoc_have==1 & (pdemploy=="K" | pdemploy=="N")
	gen GV0i = pdoc_have==1 & (pdemploy=="G" | pdemploy=="H" | pdemploy=="I" | pdemploy=="J" | pdemploy=="1" | pdemploy=="2" | pdemploy=="3")
	gen NL0i = ((pdocstat=="4" & phdcy_min<2008) | (pdocstat=="5" & phdcy_min>=2008))
	gen UN0i = .

	// pdocstat used to include "housewife, writing a book, no employment" in other, so include that as well
	replace NL0i = 1 if pdocstat=="6" & phdcy_min<2008
	
	// Set as missing if don't have job commitment
	foreach i in PD AC TE ID NP GV {
		replace `i'0i = . if pdoc_have==0 & NL0i==0
	}
	
	// Expected salary
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
	replace debtlevel = 1 if debtlevl=="Y"
	
	// Clean month filled out survey (1970-2006)
	tostring(questmon), gen(questmon_clean)
	replace questmon_clean = questmo if questmon==. & questyr>=1970 & questyr<=2006
	destring(questmon_clean), replace force
	
	//Indicator for surveyed after PhD graduation
	gen questdate = mdy(questmon_clean,1,questyr)
	gen phddate = mdy(phdmonth,1,phdcy)
	
	format questdate phddate %d
	
	gen questPPhD = (questdate>=phddate)
	replace questPPhD = . if questdate==. | phddate==.
	
	// Months between survey and PhD graduation
	gen diffQuestPhD = (questdate - phddate)/(365/12)
	
save "${DATA}/FULL DRF CLEAN.dta", replace