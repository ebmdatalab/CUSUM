cd H:\Stata
clear
**define file to use
*local csv lipid_lowering_drugs
local csv diabetes_insulin

import delimited `csv'.csv
gen month2=substr(month,1,10)
gen month3=date(month2, "YMD")
drop month month2 numerator denominator
format month3 %d
sort practice
destring calc_value, force replace

compress
save `csv',replace
*********************

use `csv',clear
drop ccg_id
***calc how many months there are
preserve
keep month3
duplicates drop
local nummonths=_N
restore

***change from absolute dates to month numbers
xtile month=month3,nq(`nummonths') 
drop month3
compress
/*
**TEMP while testing to reduce iterations
drop if month>4 //TEMP!
local nummonths=4 //TEMP!
**********************/

***reshape
reshape wide calc_value,i(practice_id) j(month)

sort practice
drop if practice_id==""
save `csv'2,replace
******************
use `csv'2,clear
*export delimited using "H:\Stata/`csv'_reshaped.csv", replace

***Calc percentiles
forval n= 1/100 {
	cap confirm variable calc_value`n'
	if !_rc {
		di in white "Calculating percentiles for month `n'..."
		qui xtile percentile`n'= calc_value`n',nq(100) //gen percentiles
		drop calc_value`n'
	}
}

save `csv'3,replace
******************/
use `csv'3,clear

***********CUSUM************
gen alertmax = 0
gen alertmin = 0
gen Smax1 = 0
gen Smin1 = 0
forval n= 1/150 {
	cap confirm variable percentile`n'
	if !_rc {
		
		di in white "Calculating CUSUM for month `n'..."
		local nprev = `n'-1
		local npost1 = `n'+1
		local npost2 = `n'+2
		local npost3 = `n'+3
		local npost4 = `n'+4
		local npost5 = `n'+5
		
		cap confirm variable percentile`npost5'
		if !_rc {
			//threshold calc sample standard deviation 
			//(done manually as it seemed easier/more transparent):
			bysort practice_id:gen mean=(percentile`n' + percentile`npost1' + ///
			percentile`npost2' + percentile`npost3' + percentile`npost4' + percentile`npost5')/6
			
			bysort practice_id:gen threshold`n' = sqrt( ( (percentile`n'-mean)^2 ///
			+ (percentile`npost1'-mean)^2 + (percentile`npost2'-mean)^2 ///
			+ (percentile`npost3'-mean)^2 + (percentile`npost4'-mean)^2 + ///
			(percentile`npost5'-mean)^2)/5) * 10 //adjust multiplierto change sensitivity
			
			drop mean
			
			
			//reference percentile 
			gen reference_percentile`n'  = (percentile`n' + percentile`npost1' ///
			+ percentile`npost2' + percentile`npost3' + percentile`npost4' + percentile`npost5')/6
			
			//replace with previous if threshold not reached
			if `n' != 1 {
				replace reference_percentile`n' = reference_percentile`nprev' if Smax`nprev' < threshold`nprev' & Smin`nprev' > -threshold`nprev'
				replace threshold`n' = threshold`nprev' if Smax`nprev' < threshold`nprev' & Smin`nprev' > -threshold`nprev'
			}
		}
		else {
			gen threshold`n' = threshold`nprev'
			if `n' != 1 {
				gen reference_percentile`n' = reference_percentile`nprev'
			}
		}
		if `n' != 1 {
			replace Smax`nprev' = 0 if Smax`nprev' >= threshold`nprev'|Smin`nprev' <= -threshold`nprev'
			replace Smin`nprev' = 0 if Smin`nprev' <= -threshold`nprev'|Smax`nprev' >= threshold`nprev'
			gen Smax`n' = max(0, Smax`nprev'+(percentile`n'-reference_percentile`n')) //calc S value
			gen Smin`n' = min(0, Smin`nprev'+(percentile`n'-reference_percentile`n')) //calc S value
		}
		replace alertmax = alertmax+1 if Smax`n' >= threshold`n'
		replace alertmin = alertmin+1 if Smin`n' <= -threshold`n'
	}
}
*drop  percentile* reference_percentile* threshold*
sort practice
drop if practice_id==""
order practice_id  alertmax alertmin Smax* Smin* percentile* reference_percentile* threshold*
save `csv'_finished,replace
