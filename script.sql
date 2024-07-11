WITH eform AS (
SELECT eform.CREATE_DTM,eform.LAST_TRIGGER_DTM,eform.SEND_STATUS,eform.EFORM_RESULT_ID FROM CLC_PRE_SEND_EFORM eform
WHERE eform.INTERFACE_CD = 'CDIS_FORM1' AND eform.CREATE_DTM >= to_date( $P{START_DATE},'yyyy-MM-dd')  AND eform.CREATE_DTM < to_date($P{END_DATE},'yyyy-MM-dd')+1
 AND (eform.ACTION_CD ='C' OR eform.ACTION_CD ='U') AND eform.SEND_STATUS <> 'WITHDRAW')
SELECT rownum , temp.* FROM (
SELECT cs.SITE_CD AS siteCd, TO_char(eform.CREATE_DTM,'dd/MM/yyyy HH24:mi:ss')  AS submissionTime, TO_char(eform.LAST_TRIGGER_DTM,'dd/MM/yyyy HH24:mi:ss')  AS exportTime, 
	CASE WHEN eform.SEND_STATUS ='SUCCESS' THEN 'Accepted'
	WHEN eform.SEND_STATUS ='PENDING' THEN 'Pending'
	WHEN eform.SEND_STATUS ='FAIL' THEN 'Rejected'
END AS STATUS , 
json_value(rs.FORM_DATA,'$.personalInfo.patientName') AS patientName,
json_value(rs.FORM_DATA,'$.tbisInfo.chestClinicNo') AS caseNo
FROM eform
	INNER JOIN CLC_EFORM_RESULT rs ON rs.EFORM_RESULT_ID  = eform.EFORM_RESULT_ID 
	INNER JOIN CMN_SITE cs ON cs.SITE_ID = rs.SITE_ID 
	INNER JOIN PMI_PATIENT pp ON pp.PATIENT_KEY = rs.PATIENT_KEY 
WHERE 
cs.SVC_CD ='TBC' AND nvl(cs.IS_MOCK_UP,0) = 0 AND rs.SVC_CD ='TBC' AND rs.SITE_ID = decode($P{SITE_ID},'-',rs.SITE_ID,$P{SITE_ID}) AND nvl(pp.IS_MOCK_UP,0) =0
ORDER BY eform.CREATE_DTM ASC
) temp