/* 7. JOB CHARACTERISTICS
Name: Stephanie D. Cheng
Date Created: 1-8-19
Date Updated: 3-19-19

This .do file gives the job characteristics in each survey year, to be matched
onto the jobs given in each year of "4. Job Type Indicators.do."

*/

global MAIN "H:/SDC_Postdocs"
global DATA "${MAIN}/Data"
global RESULTS "${MAIN}/Results"
global TEMP "${MAIN}/Temp"
global LOOKUPS "${MAIN}/Lookups"

*** 1. IDENTIFY CHARACTERISTICS FROM DRF ***
use "${DATA}/sdrdrf_refIDs.dta", clear

foreach yr in 93 95 97 99 01 03 06 08 10 13 15 {
	preserve
		
		keep if sdrdrf_yr=="`yr'"
		
		if inlist(`yr', 93) {
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(drfsup* drfpct* drfpdfld drfpdsup drfpwa drfswa drfempfd drfempl drfempty drfpdpl drfpdst)
			
			// Rename to better match years
			rename drfpdfld pdstdfld
			rename drfpdsup pdstdsup
			rename drfpwa pdwkprim
			rename drfswa pdwksec
			rename drfempfd pdempfld
			rename drfempl pdaffil
			
			// Destring drfsup*, drfpct* to better match other years
			destring drfsup* drfpct*, replace
			
			// Following other years, pdwk1ed and pdwk2ed are equal to pdwkprim and pdwksec but randomly chooses for combo codes (6,7,8)
			gen pdwk1ed = pdwkprim
			replace pdwk1ed = "0" if (pdwkprim=="6" & mod(_n,2)) | (pdwkprim=="7" & mod(_n,2))	// assign to R&D
			replace pdwk1ed = "1" if (pdwkprim=="6" & !mod(_n,2)) | (pdwkprim=="8" & mod(_n,2)) 	// assign to teaching
			replace pdwk1ed = "2" if (pdwkprim=="7" & !mod(_n,2)) | (pdwkprim=="8" & !mod(_n,2))	// assign to administration
			
			gen pdwk2ed = pdwksec
			replace pdwk2ed = "0" if (pdwksec=="6" & mod(_n,2)) | (pdwksec=="7" & mod(_n,2))	// assign to R&D
			replace pdwk2ed = "1" if (pdwksec=="6" & !mod(_n,2)) | (pdwksec=="8" & mod(_n,2)) 	// assign to teaching
			replace pdwk2ed = "2" if (pdwksec=="7" & !mod(_n,2)) | (pdwksec=="8" & !mod(_n,2))	// assign to administration
	
			// As a check, copying data from 2. and 3. on job type indicators
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
		if inlist(`yr', 95, 97) {
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(pdaffil pdempfld pdstdfld pdstdsup pdwkprim pdwksec pdwk1ed pdwk2ed srce* pdemploy pdocplan pdocstat)
			
			// Rename srcec* to match drfsup* since have same coding (and coding changes in 1999)
			rename srce1ed drfsup1e
			rename srceprim drfsup1
			rename srceprmp drfpct1
			rename srcesec drfsup2
			rename srcesecp drfpct2
			rename srcea drfsup3
			rename srceap drfpct3
			rename srceb drfsup4
			rename srcebp drfpct4
			rename srcec drfsup5
			rename srcecp drfpct5
			rename srced drfsup6
			rename srcedp drfpct6
			rename srcee drfsup7
			rename srceep drfpct7
			rename srcef drfsup8
			rename srcefp drfpct8
			rename srceg drfsup9
			rename srcegp drfpct9
			rename srceh drfsup10
			rename srcehp drfpct10
			rename srcei drfsup11
			rename srceip drfpct11
			rename srcej drfsup12
			rename srcejp drfpct12
			rename srcek drfsup13
			rename srcekp drfpct13
			rename srcel drfsup14
			rename srcelp drfpct14
			rename srcem drfsup15
			rename srcemp drfpct15

			// Destring drfsup*, drfpct* to better match other years
			destring drfsup* drfpct*, replace
	
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
		if inlist(`yr', 99, 01) {
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(pdoccode pdloc pdempfld pdstdfld pdstdsup pdwkprim pdwksec pdwk1ed pdwk2ed srce* pdemploy pdocplan pdocstat)

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
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(pdoccode pdloc pdempfld pdstdfld pdstdsup pdwkprim pdwksec pdwk1ed pdwk2ed srce* pdemploy pdocplan pdocstat)
			
			// Adjust variables to match later years
			tostring pdocplan pdocstat, replace		
		}
		if inlist(`yr', 10, 13, 15) {
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(pdoccode pdloc pdempfld pdstdfld pdstdsup pdwkprim pdwksec PDWK1ED PDWK2ED srce* pdemploy pdocplan pdocstat salary*)
		
			// Rename PDWK* to lowercase to match other years
			rename PDWK1ED pdwk1ed
			rename PDWK2ED pdwk2ed

			// Adjust variables to match later years
			tostring pdocplan pdocstat, replace			
		}
		
		// Destring for all years to match
		destring pdstdfld pdstdsup pdwk* pdempfld, replace
		
		keep if _merge==3
		drop _merge
		
		save "${TEMP}/sdrdrf`yr'_JobChar.dta", replace	
	restore
}

// Append together
use "${TEMP}/sdrdrf93_JobChar.dta", clear
foreach yr in 95 97 99 01 03 06 08 10 13 15 {
	append using "${TEMP}/sdrdrf`yr'_JobChar.dta"
}

	// Principal Job Type (also known as PD0i in "4. Job Type Indicators.do")
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
	gen pjPD = max(pdoc_have==1 & (pdocplan=="0" | pdocplan=="1" | pdocplan=="2" | pdocplan=="3"),pdoc_have==1 & (pdocplan=="4" & phdcy_min>=2004))
	gen pjAC = pdoc_have==1 & (pjPD==0 & (pdemploy=="A" | pdemploy=="B" | pdemploy=="C" | pdemploy=="4"))
	gen pjTE = pdoc_have==1 & (pjPD==0 & pjAC==0 & (pdemploy=="D" | pdemploy=="E" | pdemploy=="F"))
	gen pjID = pdoc_have==1 & (pdemploy=="L" | pdemploy=="M")
	gen pjNP = pdoc_have==1 & (pdemploy=="K" | pdemploy=="N")
	gen pjGV = pdoc_have==1 & (pdemploy=="G" | pdemploy=="H" | pdemploy=="I" | pdemploy=="J" | pdemploy=="1" | pdemploy=="2" | pdemploy=="3")
	gen pjNL = ((pdocstat=="4" & sdrdrf_fullYr<2008) | (pdocstat=="5" & sdrdrf_fullYr>=2008))
	gen pjUN = .

	// Job field of work
	foreach i in pdstd pdemp {
		gen `i'_supField = ""
		replace `i'_supField = "Agriculture" if `i'fld<=99
		replace `i'_supField = "Bio Sciences" if `i'fld>=100 & `i'fld<=199
		replace `i'_supField = "Health Sciences" if `i'fld>=200 & `i'fld<=299
		replace `i'_supField = "Engineering" if `i'fld>=300 & `i'fld<=399
		replace `i'_supField = "Comp Sci" if `i'fld>=400 & `i'fld<=410
		replace `i'_supField = "Math" if `i'fld>=420 & `i'fld<=499
		replace `i'_supField = "Other Phys Sci" if (`i'fld>=500 & `i'fld<=519) | (`i'fld>=540 & `i'fld<=559) | (`i'fld>=580 & `i'fld<=599)
		replace `i'_supField = "Chemistry" if `i'fld>=520 & `i'fld<=539
		replace `i'_supField = "Physics" if `i'fld>=560 & `i'fld<=579
		replace `i'_supField = "Psychology" if `i'fld>=600 & `i'fld<=649
		replace `i'_supField = "Economics" if `i'fld==667 & `i'fld==668
		replace `i'_supField = "Other Social Sciences" if `i'_supField=="" & `i'fld>=650 & `i'fld<=699
		replace `i'_supField = "Humanities" if `i'fld>=700 & `i'fld<=799
		replace `i'_supField = "Education" if `i'fld>=800 & `i'fld<=899
		replace `i'_supField = "Professional Fields" if `i'fld>=900 & `i'fld<=989
	}
	gen emp_supField = pdemp_supField
	replace emp_supField = pdstd_supField if emp_supField==""

	// Give expected salary -> really seems like should be in job characteristics...
	replace salaryr = salary if salaryr==. & salary!=.	// combine 2010 variables into 2013/2015 variables

	gen SALi = salaryv
	replace SALi = 15000 if salaryr==0 & SALi==.
	replace SALi = 33000 if salaryr==1 & SALi==.
	replace SALi = 38000 if salaryr==2 & SALi==.
	replace SALi = 45000 if salaryr==3 & SALi==.
	replace SALi = 55000 if salaryr==4 & SALi==.
	replace SALi = 65000 if salaryr==5 & SALi==.
	replace SALi = 75000 if salaryr==6 & SALi==.
	replace SALi = 85000 if salaryr==7 & SALi==.
	replace SALi = 95000 if salaryr==8 & SALi==.
	replace SALi = 105000 if salaryr==9 & SALi==.
	replace SALi = 110000 if salaryr==10 & SALi==.
	replace SALi = . if salaryr==11 | salaryr==99 | salaryv==999998	
	
	// Work activity
	gen actrd = (pdwk1ed==0 | pdwk2ed==0)
	gen acttch = (pdwk1ed==1 | pdwk2ed==1)
		//gen actadm = (pdwk1ed==2 | pdwk2ed==2)
		//gen actprof = (pdwk1ed==3 | pdwk2ed==3)
		
	gen ward = (pdwk1ed==0 | pdwk2ed==0)
	gen watea = (pdwk1ed==1 | pdwk2ed==1)
	gen waadm = (pdwk1ed==2 | pdwk2ed==2)
	gen wasvc = (pdwk1ed==3 | pdwk2ed==3)
	
	// Federal support indicators pre-1999 - for now, don't worry about percentages (in future might consider just prim/sec)
	foreach i in fsagr fsdoe fshhs fsnasa fsnih fsnsf fsot {
		gen `i' = 0
	}
	forvalues i = 1(1)15 {
		replace fsagr = 1 if drfsup`i'==52 | drfsup`i'==53
		replace fsdoe = 1 if drfsup`i'==40 | drfsup`i'==43 | drfsup`i'==44 | drfsup`i'==49 | drfsup`i'==64
		replace fshhs = 1 if drfsup`i'==29
		replace fsnasa = 1 if drfsup`i'==65
		replace fsnih = 1 if drfsup`i'>=21 & drfsup`i'<=25
		replace fsnsf = 1 if (drfsup`i'>=31 & drfsup`i'<=33) | (drfsup`i'==93)
		replace fsot = 1 if drfsup`i'==60 | drfsup`i'==62 | drfsup`i'==69	
	}
	
	// Any federal support
	egen govsup = rowmax(fs*)
	replace govsup = 1 if pdstdsup==5	// postdoc study support indicated gov support

	// Clean location (pdaffil, pdloc)
	gen pdaffil2 = substr(pdaffil, 1,2)	// take first two letters
	merge m:1 pdaffil2 using "${LOOKUPS}/DRF pdaffil.dta", keepusing(StAbb_pdaffil)
	keep if _merge!=2
	drop _merge
	
	merge m:1 pdloc using "${LOOKUPS}/DRF pdloc.dta", keepusing(StAbb_pdloc)
	drop _merge
	
	gen state = StAbb_pdaffil
	replace state = StAbb_pdloc if StAbb_pdloc!=""
	
	// Merge education institution
	rename pdaffil pdaffil_nrc
	merge m:1 pdaffil_nrc using "${LOOKUPS}/DRF pdaffil_inst.dta", gen(_merpda)
	keep if _merpda!=2
	
	merge m:1 pdoccode using "${LOOKUPS}/DRF pdoccode.dta", gen(_merpdoc)
	keep if _merpdoc!=2
	
	// Create 1 variable for education institution that can be merged onto SDR
	gen instcod = pdaffil
	replace instcod = pdoccode if instcod==""
	
	gen instcod_n = pdaffil_n
	replace instcod_n = pdoccode_n if instcod_n==""
	
	gen instcod_city = pdaffil_city
	replace instcod_city = pdoccode_city if instcod_city==""
	
// Refyr is graduation year
gen refyr = phdcy_min
	
// Order by most important
order refid refyr pj* emp_supField SALi state instcod* pdloc act* wa* fs* govsup

// Create indicator for original DRF data
gen DRForig = 1

save "${TEMP}/DRF_JobChar.dta", replace

*** 2. IDENTIFY CHARACTERISTICS FROM SDR ***
foreach yr in 93 95 97 99 01 03 06 08 10 13 15 {

	use "${DATA}/Stata/esdr`yr'.dta", clear
	if inlist(`yr', 93) {
		keep refid refyr oco ocpr oclst instcod emst mgrind facrank facten tensta govsup emsecsm emsecdt pdix lfstat ///
			act* wa* sup* mgr* fs* ocedrlp salary nr* nw* pt* chchg chcon chfam chlay chloc chot chpay chret chsch ///
			slfti sp* 	// no hours worked, so use salary based on full-time indicator: if Y, then full-time
	
		// Note that pre 1997 inst codes are in NRC
		rename instcod instcod_nrc
		
		// Merge on institution data
		merge m:1 instcod_nrc using "${LOOKUPS}/DRF instcod_nrc pre1997.dta", gen(_merinst)
		keep if _merinst!=2
		
	}
	if inlist(`yr', 95) {
		keep refid refyr ocpr oclst instcod emst mgrind facrank facten tensta govsup emsize hrswk strtmn strtyr emsecsm emsecdt lfstat ///
			strtmn strtyr pd*sm95 pd*em95 pd*sy95 pd*ey95	/// use to calculate pdix
			act* wa* sup* mgr* fs* hrswk ocedrlp salary nr* nw* pt* chchg chcon chfam chlay chloc chot chpay chret chsch ///
			sp*

		// Turn postdoc indicators into binary
		gen pdix = "N"
		forvalues i = 1(1)3 {
			replace pdix = "Y" if strtmn==pd`i'sm95 & strtyr==pd`i'sy95 & pd`i'em95>=98 & pd`i'ey95>=9998
		}
		
		// Note that pre 1997 inst codes are in NRC
		rename instcod instcod_nrc
		
		// Merge on institution data
		merge m:1 instcod_nrc using "${LOOKUPS}/DRF instcod_nrc pre1997.dta", gen(_merinst)
		keep if _merinst!=2
	}
	if inlist(`yr', 97) {
		keep refid refyr ocpr oclst instcod emst mgrind facrank facten tensta govsup emsize hrswk strtmn strtyr emsecsm emsecdt pdix lfstat ///
			act* wa* sup* mgr* fs* jobins jobpens jobproft jobvac hrswk ocedrlp salary nr* nw* pt* chchg chcon chfam chlay chloc chot chpay chret chsch ///
			spnat spot spowk spsoc 

		// Merge on institution data
		merge m:1 instcod using "${LOOKUPS}/DRF instcod 1997 on.dta", gen(_merinst)
		keep if _merinst!=2
		
	}
	if inlist(`yr', 99) {
		keep refid refyr ocpr oclst instcod emst facrank facten tensta govsup newbus emsize hrswk strtmn strtyr emsecsm emsecdt pdix lfstat ///
			act* wa* sup* mgr* fs* hrswk ocedrlp salary nr* nw* pt* chchg chcon chfam chlay chloc chot chpay chret chsch ///
			spnat spot spowk spsoc 

		// Merge on institution data
		merge m:1 instcod using "${LOOKUPS}/DRF instcod 1997 on.dta", gen(_merinst)
		keep if _merinst!=2
				
	}
	if inlist(`yr', 01) {
		keep refid refyr ocpr oclst instcod emst facrank facten tensta govsup newbus emsize hrswk strtmn strtyr emsecsm emsecdt pdix lfstat ///
			act* wa* sup* mgr* fs* hrswk ocedrlp salary nr* nw* pt* chchg chcon chfam chlay chloc chot chpay chret chsch ///
			spnat spot spowk spsoc sat*

		// Merge on institution data
		merge m:1 instcod using "${LOOKUPS}/DRF instcod 1997 on.dta", gen(_merinst)
		keep if _merinst!=2
						
	}
	if inlist(`yr', 03) {
		keep refid refyr nocpr noclst instcod emst facrank facten tensta govsup newbus emsize hrswk strtmn strtyr emsecsm emsecdt pdix lfstat ///
			act* wa* sup* mgr* fs* hrswk ocedrlp salary nr* nw* pt* chchg chcon chfam chlay chloc chot chpay chret chsch ///
			spnat spot spowk spsoc sat*

		// Merge on institution data
		merge m:1 instcod using "${LOOKUPS}/DRF instcod 1997 on.dta", gen(_merinst)
		keep if _merinst!=2
	
	}
	if inlist(`yr', 06) {
		keep refid refyr nocpr noclst instcod emst facrank tensta govsup emsize hrswk strtmn strtyr emsecsm emsecdt lfstat ///
			act* wa* sup* hrswk ocedrlp salary nr* nw* chchg chcon chfam chlay chloc chot chpay chret chsch ///
			spowk

		// Merge on institution data
		merge m:1 instcod using "${LOOKUPS}/DRF instcod 1997 on.dta", gen(_merinst)
		keep if _merinst!=2
				
	}
	if inlist(`yr', 08) {
		keep refid refyr nocpr noclst instcod emst facrank tensta govsup emsize hrswk strtmn strtyr emsecsm emsecdt lfstat ///
			act* wa* sup* mgr* hrswk ocedrlp salary nr* nw* chchg chcon chfam chlay chloc chot chpay chret chsch ///
			spnat spot spowk spsoc

		// Merge on institution data
		merge m:1 instcod using "${LOOKUPS}/DRF instcod 1997 on.dta", gen(_merinst)
		keep if _merinst!=2
				
	}
	if inlist(`yr', 10, 13, 15) {
		keep refid refyr N2OCPR N2OCLST instcod emst facrank tensta govsup newbus emsize hrswk strtmn strtyr emsecsm emsecdt lfstat ///
			act* wa* sup* mgr* fs* jobins jobpens jobproft jobvac hrswk	ocedrlp salary nr* nw* chchg chcon chfam chlay chloc chot chpay chret chsch ///
			spnat spot spowk spsoc sat*
	
		// Merge on institution data
		merge m:1 instcod using "${LOOKUPS}/DRF instcod 1997 on.dta", gen(_merinst)
		keep if _merinst!=2
		
	}
	
	save "${TEMP}/sdr`yr'_JobChar.dta", replace
}

// Append together
use "${TEMP}/sdr93_JobChar.dta", clear
foreach yr in 95 97 99 01 03 06 08 10 13 15 {
	append using "${TEMP}/sdr`yr'_JobChar.dta"
}

	// Principal Job Type -> this should be the principal job's type that's connected to salary 
	//(whereas the *i vars give whether in a job of that type in that year)
	gen pjPD = (pdix=="Y")
	gen pjAC = (pjPD==0 & (facten=="1" | facten=="2" | facten=="3" | tensta=="3" | tensta=="4"))	// tenure-track
	gen pjTE = (pjPD==0 & pjAC==0 & emsecsm=="1")
	gen pjID = (emsecdt=="21" | emsecdt=="22")
	gen pjNP = (emsecdt=="23")
	gen pjGV = (emsecsm=="2")
	gen pjUN = (lfstat=="2")
	gen pjNL = (lfstat=="3")

	// Job start date
	gen job_start = mdy(strtmn, 1, strtyr)
	format job_start %td

	// Job field of work
		// Merge three vars (ocpr, nocpr, N2OCPR) into one, since different from different years
		gen ocpr_FULL = ocpr
		replace ocpr_FULL = nocpr if ocpr_FULL==""
		replace ocpr_FULL = N2OCPR if ocpr_FULL==""
		destring ocpr_FULL, replace
		
		// Clean OCPR's missing values
		replace ocpr_FULL = . if ocpr_FULL>=999989
		
		gen emp_supField = ""

		// Not including postsecondary teachers
		replace emp_supField = "Comp Sci" if (ocpr_FULL>=110000 & ocpr_FULL<=119999)
		replace emp_supField = "Math" if (ocpr_FULL>=120000 & ocpr_FULL<=129999)
		replace emp_supField = "Agriculture" if (ocpr_FULL>=210000 & ocpr_FULL<=219999)
		replace emp_supField = "Bio Sciences" if (ocpr_FULL>=220000 & ocpr_FULL<=229999)
		replace emp_supField = "Other Phys Sci" if (ocpr_FULL>=320000 & ocpr_FULL<=329999) | ocpr_FULL==341980
		replace emp_supField = "Chemistry" if (ocpr_FULL>=310000 & ocpr_FULL<=319999)
		replace emp_supField = "Physics" if (ocpr_FULL>=330000 & ocpr_FULL<=339999)
		replace emp_supField = "Health Sciences" if (ocpr_FULL>=610000 & ocpr_FULL<=611140)
		replace emp_supField = "Engineering" if ocpr_FULL>=510000 & ocpr_FULL<=579999
		
		replace emp_supField = "Economics" if ocpr_FULL==412320
		replace emp_supField = "Psychology" if ocpr_FULL==432360
		replace emp_supField = "Other Social Sciences" if emp_supField=="" & (ocpr_FULL>=420000 & ocpr_FULL<=452380)
		
		// Including postsecondary teachers
		replace emp_supField = "Math" if ocpr_FULL==182760 | ocpr_FULL==182860	
		replace emp_supField = "Agriculture" if ocpr_FULL==282710
		replace emp_supField = "Bio Sciences" if ocpr_FULL==282730
		replace emp_supField = "Other Phys Sci" if ocpr_FULL==282970 | ocpr_FULL==382770
		replace emp_supField = "Chemistry" if ocpr_FULL==382750
		replace emp_supField = "Physics" if ocpr_FULL==382890
		replace emp_supField = "Engineering" if ocpr_FULL==582800
		replace emp_supField = "Health Sciences" if ocpr_FULL==612870
		
		replace emp_supField = "Economics" if ocpr_FULL==482780
		replace emp_supField = "Psychology" if ocpr_FULL==482910
		replace emp_supField = "Other Social Sciences" if ocpr_FULL==482900 | (ocpr_FULL>=482900 & ocpr_FULL<=482980)
		
		// Other fields
		replace emp_supField = "Education" if (ocpr_FULL>=632530 & ocpr_FULL<=632540) | (ocpr_FULL>=732510 & ocpr_FULL<=742990)
		replace emp_supField = "Professional Fields" if (ocpr_FULL>=711410 & ocpr_FULL<=721530) | ocpr_FULL==781200

		// Extent to which related to highest degree
		replace ocedrlp = "" if ocedrlp=="L"
		destring ocedrlp, gen(ocedrlp_n)
		replace ocedrlp_n = 3-ocedrlp_n	// now more related have higher #
		
		// Replace missing salary with .
		replace salary = . if salary>=999998
		rename salary SALi
		
	// Clean empty hrswk
	replace hrswk = . if hrswk==98
	
	// Full Time Principal Job
	gen fullTimeP = (hrswk>=35)
	replace fullTimeP = 1 if slfti=="Y"	// for 1993, since no hours worked data
	replace fullTimeP = . if hrswk==.
	
	// Work activity
		// Convert to 1,0,.
		foreach i in cap ded mgt rd rdt res tch {
			replace act`i' = "" if act`i'=="L"
			replace act`i' = "1" if act`i'=="Y"
			replace act`i' = "0" if act`i'=="N"
			destring act`i', replace
		}
		
		foreach i in acc aprsh brsh com dev dsn emrl mgmt ot prod qm sale svc tea {
			replace wa`i' = "" if wa`i'=="L"
			replace wa`i' = "1" if wa`i'=="Y"
			replace wa`i' = "0" if wa`i'=="N"
			destring wa`i', replace			
		}
		
		// Make consistent applied research = 2, basic research = 3, management = 8, teaching = 13 (switch happened in 2003)
		rename wapri wapri_ORIG
		gen wapri = wapri_ORIG
		replace wapri = "02" if wapri_ORIG=="03" & refyr>=2003
		replace wapri = "03" if wapri_ORIG=="02" & refyr>=2003
		
		// Technical expertise
			// Convert to 1,0,.
			foreach i in ind nat oth soc {
				replace mgr`i' = "" if mgr`i'=="L" | mgr`i'=="M"
				replace mgr`i' = "1" if mgr`i'=="Y"
				replace mgr`i' = "0" if mgr`i'=="N"
				destring mgr`i', replace
			}
		
		// Spousal Work
			// Convert to 1,0, . (and 0.5 for part-time)
		foreach i in nat ot soc {
			replace sp`i' = "" if sp`i'=="L"
			replace sp`i' = "1" if sp`i'=="Y"
			replace sp`i' = "0" if sp`i'=="N"
			destring sp`i', replace
		}

		replace spowk = "0.5" if spowk=="2"
		replace spowk = "0" if spowk=="3"
		replace spowk = "" if spowk=="L"
		destring spowk, replace
		
		// Supervised others
		replace supwk = "" if supwk=="L"
		replace supwk = "1" if supwk=="Y"
		replace supwk = "0" if supwk=="N"
		destring supwk, replace
		
		replace supdir = . if supdir==9998
		replace supind = . if supind==99998
	
	// Job ranks
		
		// Faculty rank
		rename facrank facrank_ORIG
		gen facrank = facrank_ORIG
		replace facrank = "" if facrank_ORIG=="L" | facrank_ORIG=="1" | facrank_ORIG=="2"
		destring facrank, replace
		
		// Tenure status
		gen tenured = .
		replace tenured = 1 if tensta=="3"
		replace tenured = 0.5 if tensta=="4"	// tenure-track
		replace tenured = 0 if tensta=="5"		// not on tenure-track
		
	// Federal support indicator
		// Convert to 1,0,.
		foreach i in agr aid com ded dod doe dot dk epa hhs hud int jus lab nasa nih nrc nsf ot st va {
			replace fs`i' = "" if fs`i'=="L"
			replace fs`i' = "1" if fs`i'=="Y"
			replace fs`i' = "0" if fs`i'=="N"	
			destring fs`i', replace
		}
	
	// Any federal support
		// Convert to 1,0,.
			replace govsup = "" if govsup=="L"
			replace govsup = "1" if govsup=="Y"
			replace govsup = "0" if govsup=="N"
			destring govsup, replace
	
	// Employer sector: use as check
	replace emsecsm="" if emsecsm=="L"
	replace emsecdt="" if emsecdt=="L"
	destring emsecsm emsecdt, replace
	
	// Employer Size: Use midpoint
	rename emsize emsize_ORIG
	gen emsize = .
	replace emsize = 5 if emsize_ORIG=="1"
	replace emsize = 17 if emsize_ORIG=="2"
	replace emsize = 62 if emsize_ORIG=="3"
	replace emsize = 300 if emsize_ORIG=="4"
	replace emsize = 750 if emsize_ORIG=="5"
	replace emsize = 3000 if emsize_ORIG=="6"
	replace emsize = 15000 if emsize_ORIG=="7"
	replace emsize = 25000 if emsize_ORIG=="8"
	
	// Job Benefits
		// Convert to 1,0,.
		foreach i in ins pens proft vac {
			replace job`i' = "" if job`i'=="L"
			replace job`i' = "1" if job`i'=="Y"
			replace job`i' = "0" if job`i'=="N"	
			destring job`i', replace
		}
	
	// New business
		// Convert to 1,0,.
			replace newbus = "" if newbus=="L"
			replace newbus = "1" if newbus=="Y"
			replace newbus = "0" if newbus=="N"
			destring newbus, replace	
	
	// Clean location (emst, instcod)
	merge m:1 emst using "${LOOKUPS}/SDR emst.dta", keepusing(State_Abb)
	drop _merge
	
	rename State_Abb state
	
	// Clean change jobs / outside of field vars
	foreach var of varlist chchg chcon chfam chlay chloc chot chpay chret chsch nr* nwfam nwill nwlay nwnond nwocna nwot nwret nwstu ptfam ptill ptnond ptocna ptot ptret ptstu ptwtft ptlay {
		replace `var' = "" if `var'=="L"
		replace `var' = "1" if `var'=="Y"
		replace `var' = "0" if `var'=="N"
		
		destring `var', replace
	}
	
	// Retirement years for nw/pt
		replace nwrtyr = . if nwrtyr==9998
		replace ptretyr = . if ptretyr==9998
		replace ptretyp = . if ptretyr==9998
	
	// Job Satisfaction -> reorder so most satisfied highest
	foreach i in adv ben chal ind loc resp sal sec soc {
		replace sat`i' = "" if sat`i'=="L"
		destring sat`i', gen(sat`i'_n)
		replace sat`i'_n = 4-sat`i'_n
	}
	
// Order by most important
order refid refyr job_start pj* emp_supField ocpr_FULL ocedrlp_n state emsecsm emsecdt emst instcod instcod_n instcod_city fullTimeP hrswk SALi act* wa* sat* mgr* sp* sup* facrank tenured emsize job* newbus nr* chchg chcon chfam chlay chloc chot chpay chret chsch nw* pt* fs* govsup 

// Format so easier to read
format %ty refyr
format %8.0g hrswk

// Create indicator for SDR original data
gen SDRorig = 1

save "${TEMP}/SDR_JobChar.dta", replace

*** 3. APPEND DRF, SDR ***
use "${TEMP}/DRF_JobChar.dta", clear
append using "${TEMP}/SDR_JobChar.dta"

// Keep only variables of interest
keep refid refyr DRForig SDRorig job_start emp_supField ocpr_FULL ocedrlp* emsecsm emsecdt SALi state pdaffil pdloc pdoccode emst instcod instcod_n instcod_city fullTimeP hrswk act* wa* sat* mgr* sp* sup* facrank tenured emsize job* newbus pj* nr* chchg chcon chfam chlay chloc chot chpay chret chsch nw* pt* fs* govsup 
drop waprsm wascsm fsdk
 
order refid refyr job_start pj* emp_supField ocpr_FULL ocedrlp_n emsecsm emsecdt SALi state instcod* fullTimeP hrswk act* wa* sat* mgr* sp* sup* facrank tenured emsize job* newbus emst nr* chchg chcon chfam chlay chloc chot chpay chret chsch nw* pt* fs* govsup
sort refid refyr 

save "${DATA}/DRF_SDR_JobChar.dta", replace
