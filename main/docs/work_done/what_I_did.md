# Things I did

## In powerpoint 06_18:
   - Simulink features
   - Test Procedure
   - Inner and outer loops tuning (we can cite Edwin here)
   - system identification added props (revise)
      -- frequency inverse weighting
      -- forcing zero at the beginning
      -- regulization
   - TSE KF with LSE fallback 
      -- LSE bias and underestimation of the stiffness
      -- Accurate ground truth are obtained from static tests
   - Varying inner loop gain to perform the stability analysis instead of breaking specimens
      -- damage can be mathimatically equivalent to adding gain (I can cite myself here)
      -- two signals are used one with high freq and one with low freq
      -- interlocks are used to set boundaries

## 1- Reference model choice (Should be reflected in the html)
   - % Goal: build a specimen-specific SAP2000 reference model that satisfies:
      1. The experimental specimen lateral stiffness matches the corresponding numerical part. This achieved by adjusting the base rotational stiffness
      2. The zero-bending-moment position is the control point. This is achieved by changing the numerical model floor height while keeping the experimental substructure matching the actual specimn (40 in)
      3. A copy of sap/template.sdb is named after the specimen and updated with the calculated base rotational stiffness and floor heights (first mode load pattern can be shown as verification).
      4. Note that we are optimizing for the first mode which creates minor errors (report). Minor errors are accepted especially with the fact that during nonlinearity this point is going to move anyway

## Scaaled TSE method improvemetns
   - maybe try smoothing, or median idea

## RTHS is performed perfectly for the linear range RTHS_02

## 2- The damage of the specimen:
   - The damage of the specimen, is shown to be equivalent to increaing the outer loop gain, which confirms our finding in the previous paper [two tfs function to compare the 7000 and the 5000]

## 3- OSI with branches and fast detection
## the feedthrogh issue

## 4- Tuninng parmeters with diagnostic gains, and synthatic simulaations

## 5- Addaptive authority

## 6- notch phasee lead to enhance robustness against specimen degradation

## Recommendations for GM PM and NCF margin

## 7- Conducting non-linear testing


