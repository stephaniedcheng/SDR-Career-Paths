/* 1. SDR Individuals
Name: Stephanie D. Cheng
Date Created: 12-3-18
Date Updated: 3-29-19

This .do file creates the basic demographic information of 
individuals in the SDR data.

*/

global MAIN "H:/SDC_Postdocs"
global DATA "${MAIN}/Data"
global RESULTS "${MAIN}/Results"
global TEMP "${MAIN}/Temp"

*** IDENTIFY ALL SDR INDIVIDUALS ***

* 1. All IDs and graduation year
foreach yr in 93 95 97 99 01 03 06 08 10 13 15 {
	use "${DATA}/Stata/sdrdrf`yr'.dta", clear
	keep *id* phdcy
	destring phdcy, replace
	
	replace phdcy = phdcy + 1900 if phdcy<100
	
	gen sdrdrf_yr = "`yr'"
	
	save "${TEMP}/sdrdrf`yr'_IDs.dta", replace
}

// Append together
use "${TEMP}/sdrdrf93_IDs.dta", clear
foreach yr in 95 97 99 01 03 06 08 10 13 15 {
	append using "${TEMP}/sdrdrf`yr'_IDs.dta"
}

// Consolidate IDs
gen mailer_id = mailerid
replace mailer_id = idcf if mailerid=="" & idcf!=""
replace mailer_id = mler_id if mailerid=="" & mler_id!=""
replace mailer_id = substr(refid, 3,.) if mailer_id=="" & refid!=""

gen DRF_ID = sdrdrfid
replace DRF_ID = idnumber if sdrdrfid=="" & idnumber!=""
replace DRF_ID = drf_id if sdrdrfid=="" & drf_id!=""

// Fill in missing data
gsort refid mailer_id -DRF_ID
by refid mailer_id: replace DRF_ID = DRF_ID[_n-1] if DRF_ID==""

bys refid mailer_id: egen phdcy_min = min(phdcy)
replace phdcy = phdcy_min if phdcy==.

// Clean up
br phdcy phdcy_min if phdcy!=phdcy_min // 12 instances, all off by 1 year (but unique for the refid), so don't worry about it too much
keep refid mailer_id DRF_ID phdcy_min sdrdrf_yr

save "${TEMP}/sdrdrf_IDs.dta", replace

* 2. Refid, keep latest drf (probably most accurate)
use "${TEMP}/sdrdrf_IDs.dta", clear
keep refid phdcy_min sdrdrf_yr

gen sdrdrf_fullYr = ""
replace sdrdrf_fullYr = "19" + sdrdrf_yr if sdrdrf_yr=="93" | sdrdrf_yr=="95" | sdrdrf_yr=="97" | sdrdrf_yr=="99"
replace sdrdrf_fullYr = "20" + sdrdrf_yr if sdrdrf_yr=="01" | sdrdrf_yr=="03" | sdrdrf_yr=="06" | sdrdrf_yr=="08" | sdrdrf_yr=="10" | sdrdrf_yr=="13" | sdrdrf_yr=="15"
destring sdrdrf_fullYr, replace

gsort refid -sdrdrf_fullYr
by refid: gen num = _n
keep if num==1
drop num

save "${DATA}/sdrdrf_refIDs.dta", replace

* 3. Add on, can add more demographics
use "${DATA}/sdrdrf_refIDs.dta", clear

// Add back other information from sdrdrf
foreach yr in 93 95 97 99 01 03 06 08 10 13 15 {
	preserve
		keep if sdrdrf_yr=="`yr'"
		
		if inlist(`yr', 93) {
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(gender bmonth bday byear bplace drfhsloc race hispind bayear bainst bafield mayear mainst mafield phdinst phdfield drfcit)
			rename gender sex
			
			// Note that 1993 inst codes are in NRC
			foreach i in ba ma phd {
				rename `i'inst `i'nrc
			}
			
			// Merge on institution data
			foreach i in ba ma phd {
				merge m:1 `i'nrc using "${LOOKUPS}/DRF `i'nrc.dta", gen(_mer`i')	// only 1 PhD not matched
				keep if _mer`i'!=2
			}
			
			// Create race indicators
			gen R_white = (race=="1")
			gen R_hisp = (hispind=="1")
			gen R_black = (race=="2")
			gen R_asian = (race=="3")
			gen R_namer = (race=="4")
			gen R_other = (race=="5")

			// If none of those, then replace ind with missing
			gen R_miss = (race=="")
			foreach i in white hisp black asian namer other {
				replace R_`i' = . if R_miss==1
			}
			
			// Add 1900 to birth year, bayear, mayear
			foreach i in byear bayear mayear {
				replace `i' = 1900+`i'
			}
			
			// Merge on birth state
			merge m:1 bplace using "${LOOKUPS}/DRF bplace_ST pre2003.dta", gen(_merbp)
			keep if _merbp!=2
			
			// Merge on high school state
			rename drfhsloc hsplace
			merge m:1 hsplace using "${LOOKUPS}/DRF hsplace_ST pre2003.dta", gen(_merhsp)
			keep if _merhsp!=2
					
			// Drop hispind (only keep indicators)
			drop hispind
			
			// Rename citizenship vars to match others
			rename drfcit citiz
		}
		if inlist(`yr', 95) {
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(sex birthmo birthyr birthpl hsplace race bayear bainst bafield bacarn mayear mainst mafield macarn phdinst phdfield phdcarn citiz phdentry geyear togephd profdeg profyear)
	
			// Note that 1995 inst codes are in NRC
			foreach i in ba ma phd {
				rename `i'inst `i'nrc
			}	

			// Merge on institution data
			foreach i in ba ma phd {
				merge m:1 `i'nrc using "${LOOKUPS}/DRF `i'nrc.dta", gen(_mer`i')
				keep if _mer`i'!=2
			}
			
			// Create race indicators
			gen R_white = (race=="7")
			gen R_hisp = (race=="4" | race=="5" | race=="6")
			gen R_black = (race=="3")
			gen R_asian = (race=="2")
			gen R_namer = (race=="1")
			gen R_other = (race=="8" | race=="9")

			// If none of those, then replace ind with missing
			gen R_miss = (race=="")
			foreach i in white hisp black asian namer other {
				replace R_`i' = . if R_miss==1
			}
			
			// Correct birth month
			replace birthmo = "10" if birthmo=="0"
			replace birthmo = "11" if birthmo=="-"
			replace birthmo = "12" if birthmo=="&"
			
			// Correct birth year
			replace birthyr = "" if birthyr=="R"
	
			rename birthmo bmonth
			rename birthyr byear
			destring bmonth byear, replace
			replace byear = 1900 + byear
			
			gen bday = 1
			
			// Rename birthplace
			rename birthpl bplace

			// Merge on birth state
			merge m:1 bplace using "${LOOKUPS}/DRF bplace_ST pre2003.dta", gen(_merbp)
			keep if _merbp!=2
			
			// Merge on high school state
			merge m:1 hsplace using "${LOOKUPS}/DRF hsplace_ST pre2003.dta", gen(_merhsp)
			keep if _merhsp!=2
			
			// Destring + add 1900 to bayear, mayear
			foreach i in bayear mayear {
				replace `i' = "" if `i'=="R"	// replace with missing
				destring `i', replace
				replace `i' = 1900 + `i'
			}
			
			// Destring Carnegie classification
			destring *carn, replace
			
			// Create Carnegie indicators
			foreach i in ba ma phd {
				gen `i'carn_R1 = (`i'carn==11)
				gen `i'carn_R2 = (`i'carn==12)
				gen `i'carn_D1 = (`i'carn==13)
				gen `i'carn_D2 = (`i'carn==14)
				
				foreach j in R1 R2 D1 D2 {
					replace `i'carn_`j' = . if `i'carn==. | `i'carn>=98 | `i'carn<=0
				}
			}
			
			// Destring years, make 4-digit calendar years
			destring geyear phdentry togephd, replace
			replace geyear = 1900 + geyear
			replace phdentry = 1900 + phdentry
			
			// Destring professional degree, add 1900 to year
			destring profdeg profyear, replace
			replace profyear = profyear+1900
			
		}
		if inlist(`yr', 97) {
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(sex birthmo birthyr birthpl hsplace race bayear bainst baiped bafield bacarn mayear mainst maiped mafield macarn phdinst phdiped phdfield phdcarn citiz phdentry geyear togephd profdeg profyear)
			
			// Rename inst codes so inst are IPEDS data and original are NRC
			foreach i in ba ma phd {
				rename `i'inst `i'nrc	// NRC codes
				rename `i'iped `i'inst	// IPEDS codes
			}
			
			// Merge on institution data
			foreach i in ba ma phd {
				merge m:1 `i'inst using "${LOOKUPS}/DRF `i'inst.dta", gen(_mer`i')
				keep if _mer`i'!=2
			}
			
			// Create race indicators
			gen R_white = (race==7)
			gen R_hisp = (race>=4 & race<=6)
			gen R_black = (race==3)
			gen R_asian = (race==2)
			gen R_namer = (race==1)
			gen R_other = (race==8 | race==9)
			
			// If none of those, then replace with missing
			gen R_miss = (race==.)
			foreach i in white hisp black asian namer other {
				replace R_`i' = . if R_miss==1
			}
			
			// Rename birthdate/place variables
			rename birthmo bmonth
			rename birthyr byear
			destring bmonth byear, replace
			gen bday = 1

			rename birthpl bplace

			// Merge on birth state
			merge m:1 bplace using "${LOOKUPS}/DRF bplace_ST pre2003.dta", gen(_merbp)
			keep if _merbp!=2
	
			// Merge on high school state
			merge m:1 hsplace using "${LOOKUPS}/DRF hsplace_ST pre2003.dta", gen(_merhsp)
			keep if _merhsp!=2
			
			// Create Carnegie indicators			
			foreach i in ba ma phd {
				gen `i'carn_R1 = (`i'carn==11)
				gen `i'carn_R2 = (`i'carn==12)
				gen `i'carn_D1 = (`i'carn==13)
				gen `i'carn_D2 = (`i'carn==14)
				
				foreach j in R1 R2 D1 D2 {
					replace `i'carn_`j' = . if `i'carn==. | `i'carn>=98 | `i'carn<=0
				}
			}			
			
		}		
		if inlist(`yr', 99) {
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(sex birthmo birthyr birthpl hsplace race bayear bainst bafield mayear mainst mafield phdinst phdfield citiz phdentry geyear togephd profdeg profyear)

			// Create race indicators
			gen R_white = (race==7)
			gen R_hisp = (race>=4 & race<=6)
			gen R_black = (race==3)
			gen R_asian = (race==2)
			gen R_namer = (race==1)
			gen R_other = (race==8 | race==9)
			
			// If none of those, then replace with missing
			gen R_miss = (race==.)
			foreach i in white hisp black asian namer other {
				replace R_`i' = . if R_miss==1
			}
			
			// Rename birthdate, place variables
			rename birthmo bmonth
			rename birthyr byear
			destring bmonth byear, replace
			gen bday = 1
				
			rename birthpl bplace
	
			// Merge on birth state
			merge m:1 bplace using "${LOOKUPS}/DRF bplace_ST pre2003.dta", gen(_merbp)
			keep if _merbp!=2
			
			// Merge on high school state
			merge m:1 hsplace using "${LOOKUPS}/DRF hsplace_ST pre2003.dta", gen(_merhsp)
			keep if _merhsp!=2
			
			// Merge on institution data
			foreach i in ba ma phd {
				merge m:1 `i'inst using "${LOOKUPS}/DRF `i'inst.dta", gen(_mer`i')
				keep if _mer`i'!=2
			}
			
		}
		if inlist(`yr', 01) {
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(sex birthmo birthyr birthpl hsplace race bayear bainst bafield bacarn mayear mainst mafield macarn phdinst phdfield phdcarn citiz phdentry geyear togephd profdeg profyear)
			
			// Create race indicators
			gen R_white = (race==10)
			gen R_hisp = (race>=6 & race<=9)
			gen R_black = (race==5)
			gen R_asian = (race>=2 & race<=4)
			gen R_namer = (race==1)
			gen R_other = (race==11 | race==12)
			
			// If none of those, then replace with missing
			gen R_miss = (race==. | race==-1)
			foreach i in white hisp black asian namer other {
				replace R_`i' = . if R_miss==1
			}
			
			// Rename birthdate variables
			rename birthmo bmonth
			rename birthyr byear
			destring bmonth byear, replace
			gen bday = 1
			
			rename birthpl bplace

			// Merge on birth state
			merge m:1 bplace using "${LOOKUPS}/DRF bplace_ST pre2003.dta", gen(_merbp)
			keep if _merbp!=2
			
			// Merge on high school state
			merge m:1 hsplace using "${LOOKUPS}/DRF hsplace_ST pre2003.dta", gen(_merhsp)
			keep if _merhsp!=2			
			
			// Merge on institution data
			foreach i in ba ma phd {
				merge m:1 `i'inst using "${LOOKUPS}/DRF `i'inst.dta", gen(_mer`i')
				keep if _mer`i'!=2
			}
			
			// Destring Carnegie classification
			destring *carn, replace		
			
			foreach i in ba ma phd {
				gen `i'carn_R1 = (`i'carn==11)
				gen `i'carn_R2 = (`i'carn==12)
				gen `i'carn_D1 = (`i'carn==13)
				gen `i'carn_D2 = (`i'carn==14)
				
				foreach j in R1 R2 D1 D2 {
					replace `i'carn_`j' = . if `i'carn==. | `i'carn>=98 | `i'carn<=0
				}
			}		
		}
		if inlist(`yr', 03, 06, 08, 10, 13, 15) {
			merge 1:1 refid using "${DATA}/Stata/sdrdrf`yr'.dta",keepusing(sex birthmo birthyr birthpl hsplace race bayear bainst bafield bacarn mayear mainst mafield macarn phdinst phdfield phdcarn citiz phdentry geyear togephd profdeg profyear)
			
			// Create race indicators
			gen R_white = (race==10)
			gen R_hisp = (race>=6 & race<=9)
			gen R_black = (race==5)
			gen R_asian = (race>=2 & race<=4)
			gen R_namer = (race==1)
			gen R_other = (race==11 | race==12)
			
			// If none of those, then replace with missing
			gen R_miss = (race==. | race==-1)
			foreach i in white hisp black asian namer other {
				replace R_`i' = . if R_miss==1
			}
			
			// Rename birthdate variables
			rename birthmo bmonth
			rename birthyr byear
			destring bmonth byear, replace
			gen bday = 1
			
			rename birthpl bplace

			// Merge on birth state
			merge m:1 bplace using "${LOOKUPS}/DRF bplace_ST 2003 on.dta", gen(_merbp)
			keep if _merbp!=2
			
			// Merge on high school state
			merge m:1 hsplace using "${LOOKUPS}/DRF hsplace_ST 2003 on.dta", gen(_merhsp)
			keep if _merhsp!=2			
			
			// Merge on institution data
			foreach i in ba ma phd {
				merge m:1 `i'inst using "${LOOKUPS}/DRF `i'inst.dta", gen(_mer`i')
				keep if _mer`i'!=2
			}
			
			// Destring Carnegie classification
			destring *carn, replace
			
			// Create Carnegie classification
			if inlist(`yr', 03, 06) {
				foreach i in ba ma phd {
					gen `i'carn_R1 = (`i'carn==15)
					gen `i'carn_D1 = (`i'carn==16)
					
					foreach j in R1 D1 {
						replace `i'carn_`j' = . if `i'carn==. | `i'carn>=98 | `i'carn<=0
					}
				}			
			}
			if inlist(`yr', 08, 10, 13, 15) {
				foreach i in ba ma phd {
					gen `i'carn_R1 = (`i'carn==15)
					gen `i'carn_R2 = (`i'carn==16)
					gen `i'carn_D1 = (`i'carn==17)
					
					foreach j in R1 R2 D1 {
						replace `i'carn_`j' = . if `i'carn==. | `i'carn>=98 | `i'carn<=0
					}
				}				
			}
		}

		
		keep if _merge==3
		drop _merge
		
		destring bafield mafield phdfield, replace
		drop race	// just keep indicators
		
		save "${TEMP}/sdrdrf_fields`yr'.dta", replace
	restore
}

// Append together
use "${TEMP}/sdrdrf_fields93.dta", clear
foreach yr in 95 97 99 01 03 06 08 10 13 15 {
	append using "${TEMP}/sdrdrf_fields`yr'.dta"
}

// Male indicator
gen male = (sex=="1")
drop sex

// Birthdate
gen birthdate = mdy(bmonth, bday, byear)
format %td birthdate
drop bmonth bday	// keep byear, since might be useful

// Native US citizenship
gen USnative = (citiz=="0" | citiz=="P")	// will include naturalized prior to 1967, Puerto Ricans; doesn't include unspecified US citizens
replace USnative = . if citiz==""
drop citiz // will re-add in "Worker Characteristics.do" since can change from year to year

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

// Calculate time spent in PhD - use geyear (since has more data than phdentry), account for time out
gen gradYrs = phdcy_min - geyear - cond(missing(togephd),0,togephd)
replace gradYrs = 0 if gradYrs<0	// 2 cases of -1

// Clean up
drop _mer* *nrc State	// drop unnecessary vars

save "${DATA}/sdrdrf_FULL.dta", replace

