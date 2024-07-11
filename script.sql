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

---22
SELECT
	rownum,
	temp.SOURCE_OF_REFERRAL AS sourceOfReferral,
	TO_CHAR(temp.CREATE_DTM,'dd/MM/yyyy HH24:mi:ss') AS importTime,
	trim(temp.ENG_SURNAME ||' '|| temp.ENG_GIVENAME) AS nameEng,
	temp.ALIAS AS caseNo,
	temp.CASE_REFERENCE_NO AS caseReferenceNo,
	LPAD(PATIENT_KEY, 10, '0') AS patientKey
FROM (
SELECT
	pcti.SOURCE_OF_REFERRAL,
	pcti.CREATE_DTM,
	pcti.ENG_SURNAME,
	pcti.ENG_GIVENAME,
	pc.ALIAS,
	pcti.CASE_REFERENCE_NO,
	pcti.PATIENT_KEY
FROM 
	PMI_CDIS_TB_INVESTIGATION pcti 
	INNER JOIN PMI_PATIENT pp ON pp.PATIENT_KEY = pcti.PATIENT_KEY 
	LEFT JOIN (
		SELECT 
			ROW_NUMBER() OVER(PARTITION BY t.PATIENT_KEY ORDER BY t.CREATE_DTM DESC) AS RN,
			t.PATIENT_KEY, t.ALIAS, t.SVC_CD         	
		FROM PMI_CASE t WHERE t.STATUS_CD = 'A' AND t.SVC_CD = 'TBC'
	) pc ON pcti.PATIENT_KEY = pc.PATIENT_KEY AND pc.RN = 1
WHERE pcti.STATUS = 'A' 
AND nvl(pp.IS_MOCK_UP, 0) = 0
AND pcti.CREATE_DTM BETWEEN TO_DATE(:i_from_date,'yyyy-MM-dd') AND TO_DATE(:i_to_date,'yyyy-MM-dd') + 1
ORDER BY pcti.CREATE_DTM ASC,pcti.PATIENT_KEY ASC
) temp;

--23
WITH eform AS (
	SELECT 
		eform.CREATE_DTM,
		eform.LAST_TRIGGER_DTM,
		eform.SEND_STATUS,
		eform.EFORM_RESULT_ID 
	FROM CLC_PRE_SEND_EFORM eform
	WHERE eform.INTERFACE_CD = 'CDIS_FORM1' 
		AND eform.CREATE_DTM >= to_date( :i_from_date,'yyyy-MM-dd')  
		AND eform.CREATE_DTM < to_date(:i_to_date,'yyyy-MM-dd')+1
		AND (eform.ACTION_CD ='C' OR eform.ACTION_CD ='U') 
		AND eform.SEND_STATUS <> 'WITHDRAW'
)
SELECT 
	rownum, 
	temp.* 
FROM (
	SELECT 
		cs.SITE_CD AS siteCd, 
		TO_char(eform.CREATE_DTM,'dd/MM/yyyy HH24:mi:ss')  AS submissionTime, 
		TO_char(eform.LAST_TRIGGER_DTM,'dd/MM/yyyy HH24:mi:ss')  AS exportTime, 
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
WHERE cs.SVC_CD ='TBC' 
	AND nvl(cs.IS_MOCK_UP,0) = 0 
	AND rs.SVC_CD ='TBC' 
	AND rs.SITE_ID = decode(:i_site_id,'-',rs.SITE_ID,:i_site_id) 
	AND nvl(pp.IS_MOCK_UP,0) =0
ORDER BY eform.CREATE_DTM ASC
) temp;

--25
SELECT SITE_ENG_NAME,ENCNTR_TYPE,"SESSION" FROM CIMS.CMN_SITE
LEFT JOIN (
	SELECT cet.ENCNTR_TYPE_DESC AS ENCNTR_TYPE FROM CLN_ENCNTR_TYPE cet 
	WHERE decode($P{ENCOUNTER_TYPE_ID},'-',NULL,$P{ENCOUNTER_TYPE_ID}) IS NOT NULL AND cet.ENCNTR_TYPE_ID = $P{ENCOUNTER_TYPE_ID}
	UNION
	SELECT 'All' AS ENCNTR_TYPE FROM DUAL
	WHERE decode($P{ENCOUNTER_TYPE_ID},'-',NULL,$P{ENCOUNTER_TYPE_ID}) IS NULL ) ON 1=1
LEFT JOIN (
	SELECT cs.SESS_DESC||' ('||cs.STIME ||'-'|| cs.ETIME||')' AS "SESSION" FROM CLN_SESS cs
	WHERE decode($P{SESS_ID},'-',NULL,$P{SESS_ID}) IS NOT NULL AND cs.SESS_ID = $P{SESS_ID}
	UNION
	SELECT 'All' AS "SESSION" FROM DUAL
	WHERE decode($P{SESS_ID},'-',NULL,$P{SESS_ID}) IS NULL )  ON 1=1
 WHERE SITE_ID = $P{SITE_ID}