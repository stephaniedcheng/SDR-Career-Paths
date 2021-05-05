/* 0. CREATING LOOKUPS
Name: Stephanie D. Cheng
Date Created: 3-29-19
Date Updated: 3-29-19

This .do file creates the following lookups to be used in this project:

Location lookups:
	Gives state for DRF post-grad affiliation, SDR job

Educational institutions lookup, used to merge the institution names with the SDR data:
	1993 & 1995 use NRC 6-character code
	1997+ use IPEDS => 1997 SDR_DRF has a lookup between the two

Carnegie Classification: changes in 1976, 1987, 1994, 2000, 2005, 2010, 2015
	Yeah, need to clean up things individually...
	
Inflation lookup

Federal Funding lookup
	
*/

global MAIN "H:/SDC_Postdocs"
global DATA "${MAIN}/Data"
global RESULTS "${MAIN}/Results"
global TEMP "${MAIN}/Temp"
global LOOKUPS "${MAIN}/Lookups"

*** LOCATION LOOKUPS ***

	// pdaffil2
	import excel "${LOOKUPS}/Location Codes.xlsx", sheet("pdaffil") firstrow allstring clear
	save "${LOOKUPS}/DRF pdaffil.dta", replace

	// pdloc
	import excel "${LOOKUPS}/Location Codes.xlsx", sheet("pdloc") firstrow allstring clear
	save "${LOOKUPS}/DRF pdloc.dta", replace

	// emst
	import excel "${LOOKUPS}/Location Codes.xlsx", sheet("emst") firstrow allstring clear
	save "${LOOKUPS}/SDR emst.dta", replace

	// Birth place: same coding as pdaffil
	use "${LOOKUPS}/DRF pdaffil.dta", clear
	rename pdaffil2 bplace
	rename StAbb_pdaffil bplace_ST
	save "${LOOKUPS}/DRF bplace_ST pre2003.dta", replace

	// Birth place: FIPS starting 2003
	use "${LOOKUPS}/DRF pdloc.dta", clear
	rename pdloc bplace
	rename StAbb_pdloc bplace_ST
	save "${LOOKUPS}/DRF bplace_ST 2003 on.dta", replace
	
	// High school: same coding as pdaffil
	use "${LOOKUPS}/DRF pdaffil.dta", clear
	rename pdaffil2 hsplace
	rename StAbb_pdaffil hsplace_ST
	save "${LOOKUPS}/DRF hsplace_ST pre2003.dta", replace	
	
	// High school: FIPS starting 2003
	use "${LOOKUPS}/DRF pdloc.dta", clear
	rename pdloc hsplace
	rename StAbb_pdloc hsplace_ST
	save "${LOOKUPS}/DRF hsplace_ST 2003 on.dta", replace	

*** EDUCATION LOOKUPS ***

	// NRC->IPEDS lookup for 1993, 1995
	foreach i in ba ma phd {
		import excel "${LOOKUPS}/Institution Codes.xlsx", firstrow allstring clear
		keep if nrc!=""
		
		rename * `i'*
		save "${LOOKUPS}/DRF `i'nrc.dta", replace
	}

	// IPEDS lookup for 1997+
	foreach i in ba ma phd {
		import excel "${LOOKUPS}/Institution Codes.xlsx", firstrow allstring clear
		drop nrc
		duplicates drop
		
		rename * `i'*
		save "${LOOKUPS}/DRF `i'inst.dta", replace
	}

	// pdaffil gives NRC code (before 1997)
	import excel "${LOOKUPS}/Institution Codes.xlsx", firstrow allstring clear
	keep if nrc!=""

	rename nrc pdaffil_nrc
	rename inst* pdaffil*

	save "${LOOKUPS}/DRF pdaffil_inst.dta", replace

	// pdoccode has IPEDS lookup
	import excel "${LOOKUPS}/Institution Codes.xlsx", firstrow allstring clear
	drop nrc	// Only has IPEDS codes
	duplicates drop

	rename inst* pdoccode*

	save "${LOOKUPS}/DRF pdoccode.dta", replace

	// instcod has NRC for 1993, 1995
	import excel "${LOOKUPS}/Institution Codes.xlsx", firstrow allstring clear
	keep if nrc!=""

	rename inst* instcod*
	rename nrc instcod_nrc
	save "${LOOKUPS}/DRF instcod_nrc pre1997.dta", replace
		
	// instcod has IPEDS for 1997+
	import excel "${LOOKUPS}/Institution Codes.xlsx", firstrow allstring clear
	drop nrc	// Only has IPEDS codes
	duplicates drop

	rename inst* instcod*
	save "${LOOKUPS}/DRF instcod 1997 on.dta", replace
	
*** CARNEGIE CLASSIFICATION ***
foreach yr in 1994 2000 2005 2010 2015 {
	import excel "${LOOKUPS}/CarnegieClassification_FullYears.xlsx", sheet("CC`yr'") firstrow clear
	save "${LOOKUPS}/CC`yr'.dta", replace
}

	// Clean UNITIDs
	use "${LOOKUPS}/CC1994.dta", clear
		gen ref1994 = 1
		foreach yr in 2000 2005 2010 2015 {
			append using "${LOOKUPS}/CC`yr'.dta", gen(ref`yr')
		}
		keep UNITID NAME STABBR CITY ref*
		sort NAME STABBR UNITID ref*

		// Fill in names (both up and down)
		egen numID = group(NAME STABBR)
		sort numID ref*
		
		by numID: replace UNITID = UNITID[_n+1] if UNITID==.
		by numID: replace UNITID = UNITID[_n-1] if UNITID==.
		
		by numID: replace CITY = CITY[_n+1] if CITY==""
		by numID: replace CITY = CITY[_n-1] if CITY==""

		keep UNITID NAME STABBR CITY
		duplicates drop
		
	save "${LOOKUPS}/University IDs.dta", replace	
	
	// CORRECT 1994, 2000 DATA
	use "${LOOKUPS}/CC1994.dta", clear
	merge 1:m NAME STABBR using "${LOOKUPS}/University IDs.dta", update
	drop if _merge==2
	drop _merge
	duplicates drop
	save "${LOOKUPS}/CC1994_u.dta", replace
	
	use "${LOOKUPS}/CC2000.dta", clear
	merge 1:m NAME STABBR CITY using "${LOOKUPS}/University IDs.dta", update
	drop if _merge==2
	drop _merge
	duplicates drop	
	save "${LOOKUPS}/CC2000_u.dta", replace	
	
// Create full Carnegie Classification by years
use "${LOOKUPS}/CC1994_u.dta", clear
	merge 1:1 UNITID NAME STABBR CITY using "${LOOKUPS}/CC2000_u.dta"
	drop _merge
	
	foreach yr in 2005 2010 2015 {
		merge 1:1 UNITID NAME STABBR CITY using "${LOOKUPS}/CC`yr'.dta"
		drop _merge
	}

	// Determine Carnegie indicators in each year

		// 1987, 1994
		foreach yr in 1987 1994 {
			gen R1_`yr' = (CC`yr'==11)
			gen R2_`yr' = (CC`yr'==12)
			gen D1_`yr' = (CC`yr'==13)
			gen D2_`yr' = (CC`yr'==14)
		}
		
		// 2000
		gen R1_2000 = (CC2000==15 | BASIC2000==15)
		gen R2_2000 = (CC2000==16 | BASIC2000==16)
		gen D1_2000 = (CC2000==21)
		gen D2_2000 = (CC2000==22)	
		
		// 2005, 2010, 2015
		foreach yr in 2005 2010 2015 {
			gen R1_`yr' = (BASIC`yr'==15)
			gen R2_`yr' = (BASIC`yr'==16)
			gen D1_`yr' = (BASIC`yr'==17)
		}

order UNITID NAME CITY STABBR CC1987 CC1994 CC2000 BASIC2000 BASIC2005 BASIC2010 BASIC2015

save "${LOOKUPS}/CC_FULL.dta", replace
	
// Long version - to merge to full data set
use "${LOOKUPS}/CC_FULL.dta", clear
keep UNITID NAME CITY STABBR CC1987 CC1994 CC2000 BASIC2000 BASIC2005 BASIC2010 BASIC2015 R1_* R2_* D1_* D2_*

reshape long CC BASIC R1_ R2_ D1_ D2_, i(UNITID NAME CITY STABBR) j(refyr)

	// Clean up to match SDR data
	rename UNITID instcod
	rename NAME instcod_n
	rename CITY instcod_city
	rename STABBR state
	rename *_ *
	
	order refyr instcod* state CC BASIC R* D*
	
	// Create group IDs
	gen instNM = instcod
	replace instNM = 0 if instcod==.
	
	gen inst_cityNM = instcod_city
	replace inst_cityNM = "NA" if instcod_city==""
	
	egen numID_inst = group(instNM instcod_n inst_cityNM state)
	sort numID_inst instcod instcod_n instcod_city state refyr
	
	// Fill in missing years
	tsset numID_inst refyr
	tsfill
	
	foreach i in instcod instcod_n instcod_city state CC BASIC R1 R2 D1 D2 {
		bys numID_inst: carryforward `i', gen(`i'_F)
	}

	// Clean up
	keep refyr *_F
	rename *_F *
	save "${LOOKUPS}/CCbyYear.dta", replace
	
/* So this is kind of annoying, but basically different campuses with the same instcod can have different ratings...
   It's a bit hard to merge onto *everything* (institution name, location), so instead, I'll make a instcod-refyr
   one that takes the max value in a year
*/
	use "${LOOKUPS}/CCbyYear.dta", clear
	keep instcod refyr R* D*
	
	foreach i in R1 R2 D1 D2 {
		rename `i' `i'_t
		bys instcod refyr: egen `i' = max(`i'_t)
	}

	keep instcod refyr R1 R2 D1 D2
	duplicates drop
	drop if instcod==.
	
	save "${LOOKUPS}/CCbyYear_max.dta", replace
	
/*** CARNEGIE CLASSIFICATION ***
	foreach i in ba ma {
		use "${DATA}/sdrdrf_FULL.dta", clear
		keep `i'year `i'inst `i'inst_n `i'carn*
		
		rename `i'* *
		gen source = "`i'"
		save "${TEMP}/`i' Carnegie.dta", replace
	}
	
		use "${DATA}/sdrdrf_FULL.dta", clear
		keep phdcy_min phdinst phdinst_n phdcarn*
		
		rename phdcy_min phdyear
		rename phd* *
		gen source = "phd"
		save "${TEMP}/phd Carnegie.dta", replace

	use "${TEMP}/ba Carnegie.dta", clear
	append using "${TEMP}/ma Carnegie.dta"
	append using "${TEMP}/phd Carnegie.dta"
	
	duplicates drop *year *inst *inst_n *carn*, force
	
	sort year inst
	
	duplicates tag year inst, gen(dup)
	tab dup
*/
	
*** INFLATION LOOKUP ***
	import excel "${LOOKUPS}/Inflation Calc.xlsx", sheet("Sheet1") firstrow clear
	save "${LOOKUPS}/Inflation Calc.dta", replace

*** FEDERAL FUNDING LOOKUP ***
	foreach i in Total Agriculture Defense Energy NIH HHS Homeland NASA NSF {
		import excel "${DATA}/Federal Funding/Acad Funding readyforstata.xlsx", sheet("`i'") firstrow clear
		keep refyr Total Lifesciences Psychology Physicalsciences Environmental CSMath Engineering Socialsciences	
		drop if refyr==.
		
		// Reshape so can merge other datasets
		foreach j in Total Lifesciences Psychology Physicalsciences Environmental CSMath Engineering Socialsciences {
			rename `j' fund`j'
		}
		
		reshape long fund, i(refyr) j(field) string
		
		rename fund fund`i'
		rename field fundField
		
		save "${TEMP}/`i' Acad Funding.dta", replace
	}

	// As one file
	use "${TEMP}/Total Acad Funding.dta", clear
	foreach i in Agriculture Defense Energy NIH HHS Homeland NASA NSF {
		merge 1:1 refyr fundField using "${TEMP}/`i' Acad Funding.dta"
		drop _merge
	}
	save "${DATA}/Federal Funding/Academic Funding.dta", replace
