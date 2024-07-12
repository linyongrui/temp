--21-v1
WITH cons_rm AS (
	select cr.RM_ID from CLN_RM cr where cr.SITE_ID =V_SITE_ID and cr.RM_CD='CONS'
),
sess_timslot AS (
    SELECT cs.SESS_ID,cs.SESS_DESC, ct.STIME,cs.SESS_DESC||' '||ct.STIME AS sess_time,
        nvl(ct.QT1_BOOKED,0) AS bookedQuota,
        CASE WHEN nvl(ct.overall_qt,0)>0 and cmupt.TMSLT_ID IS NULL THEN ct.qt1 ELSE 0 END AS quota,
         ct.TMSLT_ID, ct.TMSLT_DATE
    FROM (select * from CLN_TMSLT where EXTRACT(YEAR FROM TMSLT_DATE) = V_YEAR_NO AND EXTRACT(MONTH FROM TMSLT_DATE) =V_MONTH_NO AND RM_ID IN (SELECT * FROM cons_rm)) ct
    INNER JOIN CLN_SESS cs ON cs.SESS_ID = ct.SESS_ID AND cs.SVC_CD ='TBC' AND cs.STATUS ='A'
    INNER JOIN CMN_SITE site ON site.SITE_ID = cs.SITE_ID AND site.SVC_CD ='TBC' AND nvl(site.IS_MOCK_UP,0) = 0
    LEFT JOIN CLN_MAP_UNAVAIL_PERD_TMSLT cmupt ON cmupt.TMSLT_ID = ct.TMSLT_ID
)
,appts AS (
    SELECT aa.APPT_ID , aa.PATIENT_KEY ,aa.CASE_NO ,aa.TBC_ON_TX, amat.TMSLT_ID
    FROM (select * from ANA_APPT where APPT_TYPE_CD <> 'D' and SITE_ID = V_SITE_ID ) aa
    INNER JOIN ANA_APPT_DETL aad ON aad.APPT_ID = aa.APPT_ID AND nvl(aad.IS_OBS,0) = 0 AND aad.RM_ID IN (SELECT * FROM cons_rm)
    INNER JOIN ANA_MAP_APPT_TMSLT amat ON amat.APPT_DETL_ID = aad.APPT_DETL_ID AND nvl(amat.IS_OBS ,0) = 0 AND amat.QT_TYPE ='QT1'
    INNER JOIN sess_timslot st ON st.TMSLT_ID = amat.TMSLT_ID
    INNER JOIN CMN_SITE site ON site.SITE_ID = aa.SITE_ID AND site.SVC_CD ='TBC' AND nvl(site.IS_MOCK_UP,0) = 0
    LEFT JOIN PMI_PATIENT pp ON pp.PATIENT_KEY = aa.PATIENT_KEY
    where aa.PATIENT_KEY<0 or nvl(pp.IS_MOCK_UP ,0) = 0
)
, t AS (
    SELECT count(APPT_ID) AS t,TMSLT_ID FROM appts
    LEFT JOIN PMI_CASE pc ON pc.PATIENT_KEY = appts.PATIENT_KEY AND pc.CASE_NO = appts.CASE_NO
    WHERE NOT EXISTS (select 1 from ANA_ATND atnd where atnd.APPT_ID = appts.APPT_ID and (atnd.IS_CANCEL is null or atnd.IS_CANCEL <> 1))
    AND (appts.CASE_NO IS NULL OR pc.STATUS_CD <> 'A')
    GROUP BY TMSLT_ID
)
, tx AS (
    SELECT sum( CASE WHEN appts.TBC_ON_TX = 1 THEN 1 ELSE 0 END ) AS tx, TMSLT_ID FROM appts GROUP BY TMSLT_ID
)
SELECT * FROM (
    SELECT  to_char(st.TMSLT_DATE,'DD') as day,st.sess_desc, st.stime,st.sess_time,st.bookedQuota, st.quota,nvl(t.t,0) AS t_val,nvl(tx.tx,0) AS tx_val
    FROM sess_timslot st
    LEFT JOIN t ON t.TMSLT_ID = st.TMSLT_ID
    LEFT JOIN tx ON tx.TMSLT_ID = st.TMSLT_ID
) temp
PIVOT (
  max(bookedQuota) AS bookedQuota,
  max(quota) AS quota,
  max(t_val) AS t_val,
  max(tx_val) AS tx_val
  FOR day
  IN (
    '01' AS DAY_01, '02' AS DAY_02, '03' AS DAY_03, '04' AS DAY_04, '05' AS DAY_05, '06' AS DAY_06, '07' AS DAY_07, '08' AS DAY_08, '09' AS DAY_09, '10' AS DAY_10,
    '11' AS DAY_11, '12' AS DAY_12, '13' AS DAY_13, '14' AS DAY_14, '15' AS DAY_15, '16' AS DAY_16, '17' AS DAY_17, '18' AS DAY_18, '19' AS DAY_19, '20' AS DAY_20,
    '21' AS DAY_21, '22' AS DAY_22, '23' AS DAY_23, '24' AS DAY_24, '25' AS DAY_25,'26' AS DAY_26, '27' AS DAY_27, '28' AS DAY_28, '29' AS DAY_29, '30' AS DAY_30, '31' AS DAY_31
  )
)
ORDER BY sess_time;

--22-v2
WITH cons_rm AS (
	select 
		cr.RM_ID 
	from CLN_RM cr where cr.RM_CD='CONS'
	AND cr.SITE_ID =:V_SITE_ID 
)
,sess_timslot AS (
    SELECT 
    	cs.SESS_ID,
    	cs.SESS_DESC, 
    	ct.STIME,
    	cs.SESS_DESC||' '||ct.STIME AS sess_time,
        nvl(ct.QT1_BOOKED,0) AS bookedQuota,
        CASE WHEN nvl(ct.overall_qt,0)>0 and cmupt.TMSLT_ID IS NULL THEN ct.qt1 ELSE 0 END AS quota,
         ct.TMSLT_ID, 
         ct.TMSLT_DATE
    FROM (
    	select 
    		t.* 
    	from CLN_TMSLT t 
    	where t.RM_ID IN (SELECT * FROM cons_rm)
--    	AND EXTRACT(YEAR FROM TMSLT_DATE) = :V_YEAR_NO 
--    	AND EXTRACT(MONTH FROM TMSLT_DATE) =:V_MONTH_NO 
    	AND t.TMSLT_DATE >= TO_DATE(TO_CHAR(:V_YEAR_NO ) || '-' || TO_CHAR(:V_MONTH_NO) || '-01', 'YYYY-MM-DD')
    	AND t.TMSLT_DATE < ADD_MONTHS(TO_DATE(TO_CHAR(:V_YEAR_NO ) || '-' || TO_CHAR(:V_MONTH_NO) || '-01', 'YYYY-MM-DD'), 1)
    ) ct
    INNER JOIN CLN_SESS cs ON cs.SESS_ID = ct.SESS_ID AND cs.SVC_CD ='TBC' AND cs.STATUS ='A'
    INNER JOIN CMN_SITE site ON site.SITE_ID = cs.SITE_ID AND site.SVC_CD ='TBC' 
--    	AND nvl(site.IS_MOCK_UP,0) = 0
    LEFT JOIN CLN_MAP_UNAVAIL_PERD_TMSLT cmupt ON cmupt.TMSLT_ID = ct.TMSLT_ID
)
,appts AS (
    SELECT 
    	aa.APPT_ID , aa.PATIENT_KEY ,aa.CASE_NO ,aa.TBC_ON_TX, amat.TMSLT_ID
    FROM (
    	select * from ANA_APPT where APPT_TYPE_CD <> 'D' and SITE_ID = :V_SITE_ID 
    ) aa
    INNER JOIN ANA_APPT_DETL aad ON aad.APPT_ID = aa.APPT_ID 
    	AND nvl(aad.IS_OBS,0) = 0 AND aad.RM_ID IN (SELECT * FROM cons_rm)
    INNER JOIN ANA_MAP_APPT_TMSLT amat ON amat.APPT_DETL_ID = aad.APPT_DETL_ID 
    	AND nvl(amat.IS_OBS ,0) = 0 AND amat.QT_TYPE ='QT1'
    INNER JOIN sess_timslot st ON st.TMSLT_ID = amat.TMSLT_ID
    INNER JOIN CMN_SITE site ON site.SITE_ID = aa.SITE_ID 
    	AND site.SVC_CD ='TBC' AND nvl(site.IS_MOCK_UP,0) = 0
    LEFT JOIN PMI_PATIENT pp ON pp.PATIENT_KEY = aa.PATIENT_KEY
    where aa.PATIENT_KEY<0 or nvl(pp.IS_MOCK_UP ,0) = 0
)
, t AS (
    SELECT 
    	count(APPT_ID) AS t,
    	TMSLT_ID 
    FROM appts
    LEFT JOIN PMI_CASE pc ON pc.PATIENT_KEY = appts.PATIENT_KEY AND pc.CASE_NO = appts.CASE_NO
    WHERE NOT EXISTS (
    	select 1 from ANA_ATND atnd where atnd.APPT_ID = appts.APPT_ID 
    		and (atnd.IS_CANCEL is null or atnd.IS_CANCEL <> 1)
    )
    AND (appts.CASE_NO IS NULL OR pc.STATUS_CD <> 'A')
    GROUP BY TMSLT_ID
)
, tx AS (
    SELECT sum( CASE WHEN appts.TBC_ON_TX = 1 THEN 1 ELSE 0 END ) AS tx, TMSLT_ID FROM appts GROUP BY TMSLT_ID
)
SELECT * FROM (
    SELECT 
    	to_char(st.TMSLT_DATE,'DD') as day,
    	st.sess_desc, 
    	st.stime,
    	st.sess_time,
    	st.bookedQuota, 
    	st.quota,
    	nvl(t.t,0) AS t_val,
    	nvl(tx.tx,0) AS tx_val
    FROM sess_timslot st
    LEFT JOIN t ON t.TMSLT_ID = st.TMSLT_ID
    LEFT JOIN tx ON tx.TMSLT_ID = st.TMSLT_ID
) temp
PIVOT (
  max(bookedQuota) AS bookedQuota,
  max(quota) AS quota,
  max(t_val) AS t_val,
  max(tx_val) AS tx_val
  FOR day
  IN (
    '01' AS DAY_01, '02' AS DAY_02, '03' AS DAY_03, '04' AS DAY_04, '05' AS DAY_05, '06' AS DAY_06, '07' AS DAY_07, '08' AS DAY_08, '09' AS DAY_09, '10' AS DAY_10,
    '11' AS DAY_11, '12' AS DAY_12, '13' AS DAY_13, '14' AS DAY_14, '15' AS DAY_15, '16' AS DAY_16, '17' AS DAY_17, '18' AS DAY_18, '19' AS DAY_19, '20' AS DAY_20,
    '21' AS DAY_21, '22' AS DAY_22, '23' AS DAY_23, '24' AS DAY_24, '25' AS DAY_25,'26' AS DAY_26, '27' AS DAY_27, '28' AS DAY_28, '29' AS DAY_29, '30' AS DAY_30, '31' AS DAY_31
  )
)
ORDER BY sess_time;

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
