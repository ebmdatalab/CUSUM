# CUSUM
### Detecting changes in prescribing over time in relation to other CCGs/practices

## Method

1. The percentiles for all practices specific practice/percentile are imported
2. The mean/standard deviation are calculated for the first 12 months
3. The cumulative deviation from the mean is calculated for positive and negative changes for each month
    - with a 0 baseline
    - only change above 0.5 * standard deviation is included in the CUSUM (this filters out some of the noise and helps later, taken from Montgomery DC. Introduction to Statistical Quality Control. Wiley 2009)
4. The threshold value is calculated as 5 * standard deviation
5. An alert is triggered when the CUSUM value exceeds the threshold, then:
    - The reference mean is reset to the preceding 12 months
    - If the CUSUM value continues to increase by more than 0.5 * standard deviation in relation to the new reference mean, another alert is triggered
    - Otherwise, the CUSUM value is reset, along with the reference mean and standard deviation, which is set to the preceding 12 months

## Notes/known issues

Theres are two different methods used to get data and calculate alerts:
1. The data are requested from the API on an individual CCG/practice and measure level, and then alerts are calculated seperately
    - As submitted in the paper
    - This is fine for individual locations, but takes far too long to do ~8000 practices across ~33 measures
    - This method is robust to some missing percentile data, though not necessarily meaningful, depending on the number of missing values
2. The data are taken as one and calculated using pandas all at once
    - Takes 2 mins to calculate all measures/practices vs 4 hours at best for above method
    - Not yet robust to missing data, will simply return no alerts e.g. if there are no data in the first 12 months
