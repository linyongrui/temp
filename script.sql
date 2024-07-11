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
WITH appts AS (
SELECT aa.APPT_ID , 
aa.APPT_DATE ,
aa.PATIENT_KEY,
aa.CASE_NO,
aad.APPT_DETL_ID ,
cet.ENCNTR_TYPE_DESC AS encType
FROM ANA_APPT aa
INNER JOIN ANA_APPT_DETL aad ON aad.APPT_ID = aa.APPT_ID 
INNER JOIN CMN_SITE cs ON cs.SITE_ID = aa.SITE_ID 
INNER JOIN CLN_SESS sess ON sess.SESS_ID = aad.SESS_ID 
INNER JOIN CLN_ENCNTR_TYPE cet ON cet.ENCNTR_TYPE_ID = aad.ENCNTR_TYPE_ID
WHERE cs.SVC_CD ='TBC' AND cs.STATUS ='A' AND nvl(cs.IS_MOCK_UP,0) = 0
AND (cs.EFFT_DATE IS NULL OR trunc(cs.EFFT_DATE) <= TRUNC(SYSDATE)) AND (cs.EXPY_DATE IS NULL OR trunc(cs.EXPY_DATE) >= TRUNC(SYSDATE))
AND aa.APPT_TYPE_CD <> 'D' AND nvl(aad.IS_OBS,0) = 0
AND cs.SITE_ID = i_site_id
AND cet.ENCNTR_TYPE_ID =DECODE(i_encounter_type_id,'-',cet.ENCNTR_TYPE_ID,i_encounter_type_id)  
AND sess.SESS_ID = DECODE(i_sess_id,'-',sess.SESS_ID,i_sess_id)  
AND aa.APPT_DATE >= to_date( i_from_date,'yyyy-MM-dd')  AND aa.APPT_DATE < to_date(i_to_date,'yyyy-MM-dd')+1 
) 
,apptTime AS (
SELECT aa.APPT_DETL_ID, TO_CHAR(min(amat.SDTM),'hh24:mi') ||' - '||TO_CHAR(max(amat.EDTM),'hh24:mi') AS time FROM appts aa
INNER JOIN ANA_MAP_APPT_TMSLT amat ON amat.APPT_DETL_ID = aa.APPT_DETL_ID
WHERE nvl(amat.IS_OBS,0) = 0 GROUP BY aa.APPT_DETL_ID
)
,phn AS (
SELECT * FROM ( 
SELECT pp.patient_key, phn.dialing_cd, phn.area_cd, phn.phone_no ,phn.phone_type_cd,
      ROW_NUMBER()
       OVER(PARTITION BY pp.patient_key
            ORDER BY nvl(phn.sms_phone_ind, 0) DESC, phn.CREATE_DTM ASC ,phn.patient_phone_id ASC
       ) AS rn 
   FROM (SELECT DISTINCT PATIENT_KEY FROM appts ) pp 
   INNER JOIN pmi_patient_phone phn ON pp.patient_key = phn.patient_key
) WHERE rn = 1
),
dateRange AS (
SELECT to_date(i_from_date,'yyyy-MM-dd')+ROWNUM -1 AS REPORT_DATE FROM DUAL
CONNECT BY ROWNUM < =  (to_date(i_to_date,'yyyy-MM-dd')-to_date( i_from_date,'yyyy-MM-dd')) +1
)
SELECT to_char(dateRange.REPORT_DATE,'yyyy-MM-dd') AS reportDate, rs.* FROM dateRange
LEFT JOIN (
SELECT aa.APPT_ID AS apptId, 
aa.APPT_DATE,
amat.time, 
ctci.PATIENT_NO AS caseNo,
CASE WHEN aa.PATIENT_KEY > 0 THEN 
(CASE WHEN pp.ENG_SURNAME IS NOT NULL 
AND pp.ENG_GIVENAME IS NOT NULL 
THEN pp.ENG_SURNAME ||' '|| pp.ENG_GIVENAME
ELSE COALESCE(pp.ENG_SURNAME, pp.ENG_GIVENAME) END)||' '|| DECODE(pp.NAME_CHI ,NULL,'',pp.NAME_CHI)  
ELSE 
aap.ENG_SURNAME ||' '||aap.ENG_GIVENAME ||' '|| DECODE(aap.CHI_NAME ,NULL,'',aap.CHI_NAME)   
END AS patientName ,
CASE WHEN aa.PATIENT_KEY > 0 THEN 
CASE WHEN phn.PHONE_NO IS NOT NULL THEN 
'('||nvl(phn.DIALING_CD ,'  ')||') - ('||nvl(phn.AREA_CD,'  ')||') - '||nvl(phn.PHONE_NO ,'')
ELSE NULL END
ELSE
'('||nvl(aap.DIALING_CD ,'  ')||') - ('||nvl(aap.AREA_CD,'  ')||') - '||nvl(aap.CNTCT_PHN,'') END AS phone,
CASE WHEN pti.PN_NO1 IS NOT NULL 
AND pti.PN_NO2 IS NOT NULL 
THEN pti.PN_NO1 ||' /'||chr(10)|| pti.PN_NO2
ELSE COALESCE(pti.PN_NO1, pti.PN_NO2) END AS pnNo,
aa.encType, 
asrt.SPECIAL_RQST_DESC || DECODE(asr.REMARK,NULL,'',': '||asr.REMARK) AS specialRequest 
FROM appts aa
INNER JOIN apptTime amat ON amat.APPT_DETL_ID = aa.APPT_DETL_ID 
LEFT JOIN phn ON phn.PATIENT_KEY = aa.PATIENT_KEY 
LEFT JOIN PMI_PATIENT pp ON pp.PATIENT_KEY = aa.PATIENT_KEY 
LEFT JOIN ANA_ANON_PATIENT aap ON aap.ANON_PATIENT_ID = aa.PATIENT_KEY 
LEFT JOIN CLC_TBC_CASE_INFO ctci ON ctci.CASE_NO = aa.CASE_NO 
LEFT JOIN PMI_TBC_INFO pti ON pti.PATIENT_KEY = pp.PATIENT_KEY 
LEFT JOIN ANA_SPECIAL_RQST asr ON asr.APPT_ID = aa.APPT_ID 
LEFT JOIN ANA_SPECIAL_RQST_TYPE asrt ON asrt.SPECIAL_RQST_TYPE_ID = asr.SPECIAL_RQST_TYPE_ID
WHERE  nvl(pp.IS_MOCK_UP,0) = 0
) rs ON trunc(rs.appt_date) = dateRange.REPORT_DATE
ORDER BY dateRange.REPORT_DATE ASC, rs.caseNo ASC, rs.time ASC, rs.patientName ASC


--025 v3
WITH TBC_CMN_SITE AS (
	SELECT 
		cs.SITE_ID 
	FROM CMN_SITE cs 
	WHERE cs.SVC_CD ='TBC' 
	AND cs.STATUS ='A' 
	AND nvl(cs.IS_MOCK_UP,0) = 0
	AND (cs.EFFT_DATE IS NULL OR trunc(cs.EFFT_DATE) <= TRUNC(SYSDATE)) 
	AND (cs.EXPY_DATE IS NULL OR trunc(cs.EXPY_DATE) >= TRUNC(SYSDATE))
	AND cs.SITE_ID = :i_site_id
)
,TBC_ANA_APPT AS (
	SELECT 
		aa.APPT_ID,
		aa.APPT_DATE,
		aa.PATIENT_KEY,
		aa.CASE_NO,
		aa.SITE_ID
	FROM ANA_APPT aa
	WHERE aa.APPT_TYPE_CD <> 'D' 
	AND aa.SITE_ID = :i_site_id 
	AND aa.APPT_DATE >= to_date( :i_from_date,'yyyy-MM-dd')  
	AND aa.APPT_DATE < to_date(:i_to_date,'yyyy-MM-dd') + 1 
)
,TBC_appts AS (
	SELECT 
		aa.APPT_ID , 
		aa.APPT_DATE ,
		aa.PATIENT_KEY,
		aa.CASE_NO,
		aad.APPT_DETL_ID ,
		cet.ENCNTR_TYPE_DESC AS encType
	FROM TBC_ANA_APPT aa
	INNER JOIN TBC_CMN_SITE cs ON cs.SITE_ID = aa.SITE_ID 
	INNER JOIN ANA_APPT_DETL aad ON aad.APPT_ID = aa.APPT_ID 
	INNER JOIN CLN_SESS sess ON sess.SESS_ID = aad.SESS_ID 
	INNER JOIN CLN_ENCNTR_TYPE cet ON cet.ENCNTR_TYPE_ID = aad.ENCNTR_TYPE_ID
	WHERE nvl(aad.IS_OBS,0) = 0
	AND cet.ENCNTR_TYPE_ID =DECODE(:i_encounter_type_id,'-',cet.ENCNTR_TYPE_ID,:i_encounter_type_id)  
	AND sess.SESS_ID = DECODE(:i_sess_id,'-',sess.SESS_ID,:i_sess_id)
)
,TBC_apptTime AS (
	SELECT 
		aa.APPT_DETL_ID, 
		TO_CHAR(min(amat.SDTM),'hh24:mi') ||' - '||TO_CHAR(max(amat.EDTM),'hh24:mi') AS time 
	FROM TBC_appts aa
	INNER JOIN ANA_MAP_APPT_TMSLT amat ON amat.APPT_DETL_ID = aa.APPT_DETL_ID
	WHERE nvl(amat.IS_OBS,0) = 0 
	GROUP BY aa.APPT_DETL_ID
)
,TBC_phn AS (
	SELECT 
		* 
	FROM ( 
		SELECT 
			pp.patient_key, 
			phn.dialing_cd, 
			phn.area_cd, 
			phn.phone_no,
			phn.phone_type_cd,
			ROW_NUMBER() OVER(PARTITION BY pp.patient_key 
				ORDER BY nvl(phn.sms_phone_ind, 0) DESC, phn.CREATE_DTM ASC ,phn.patient_phone_id ASC ) AS rn 
		FROM (
			SELECT 
				DISTINCT PATIENT_KEY 
			FROM TBC_appts 
		) pp 
		INNER JOIN pmi_patient_phone phn ON pp.patient_key = phn.patient_key
	) WHERE rn = 1
)
,dateRange AS (
	SELECT 
		to_date(:i_from_date,'yyyy-MM-dd') + ROWNUM - 1 AS REPORT_DATE 
	FROM 
		DUAL
	CONNECT BY ROWNUM <= (to_date(:i_to_date,'yyyy-MM-dd')-to_date( :i_from_date,'yyyy-MM-dd')) + 1
)
SELECT 
	to_char(dateRange.REPORT_DATE,'yyyy-MM-dd') AS reportDate, 
	rs.* 
FROM dateRange
LEFT JOIN (
	SELECT 
		aa.APPT_ID AS apptId, 
		aa.APPT_DATE,
		amat.time, 
		ctci.PATIENT_NO AS caseNo,
		CASE WHEN aa.PATIENT_KEY > 0 
			THEN (
				CASE WHEN pp.ENG_SURNAME IS NOT NULL AND pp.ENG_GIVENAME IS NOT NULL 
					THEN pp.ENG_SURNAME ||' '|| pp.ENG_GIVENAME
					ELSE COALESCE(pp.ENG_SURNAME, pp.ENG_GIVENAME) END
			) ||' '|| DECODE(pp.NAME_CHI ,NULL,'',pp.NAME_CHI)  
			ELSE 
				aap.ENG_SURNAME ||' '||aap.ENG_GIVENAME ||' '|| DECODE(aap.CHI_NAME ,NULL,'',aap.CHI_NAME)   
		END AS patientName ,
		CASE WHEN aa.PATIENT_KEY > 0 
			THEN 
				CASE WHEN phn.PHONE_NO IS NOT NULL THEN '('||nvl(phn.DIALING_CD ,'  ')||') - ('||nvl(phn.AREA_CD,'  ')||') - '||nvl(phn.PHONE_NO ,'')
				ELSE NULL END
			ELSE
				'('||nvl(aap.DIALING_CD ,'  ')||') - ('||nvl(aap.AREA_CD,'  ')||') - '||nvl(aap.CNTCT_PHN,'') 
		END AS phone,
		CASE WHEN pti.PN_NO1 IS NOT NULL AND pti.PN_NO2 IS NOT NULL 
			THEN pti.PN_NO1 ||' /'||chr(10)|| pti.PN_NO2
			ELSE COALESCE(pti.PN_NO1, pti.PN_NO2) 
		END AS pnNo,
		aa.encType, 
		asrt.SPECIAL_RQST_DESC || DECODE(asr.REMARK,NULL,'',': '||asr.REMARK) AS specialRequest 
	FROM TBC_appts aa
	INNER JOIN TBC_apptTime amat ON amat.APPT_DETL_ID = aa.APPT_DETL_ID 
	LEFT JOIN TBC_phn phn ON phn.PATIENT_KEY = aa.PATIENT_KEY 
	LEFT JOIN PMI_PATIENT pp ON pp.PATIENT_KEY = aa.PATIENT_KEY 
	LEFT JOIN ANA_ANON_PATIENT aap ON aap.ANON_PATIENT_ID = aa.PATIENT_KEY 
	LEFT JOIN CLC_TBC_CASE_INFO ctci ON ctci.CASE_NO = aa.CASE_NO 
	LEFT JOIN PMI_TBC_INFO pti ON pti.PATIENT_KEY = pp.PATIENT_KEY 
	LEFT JOIN ANA_SPECIAL_RQST asr ON asr.APPT_ID = aa.APPT_ID 
	LEFT JOIN ANA_SPECIAL_RQST_TYPE asrt ON asrt.SPECIAL_RQST_TYPE_ID = asr.SPECIAL_RQST_TYPE_ID
	WHERE  nvl(pp.IS_MOCK_UP,0) = 0
) rs ON trunc(rs.appt_date) = dateRange.REPORT_DATE
ORDER BY dateRange.REPORT_DATE ASC, rs.caseNo ASC, rs.time ASC, rs.patientName ASC;
