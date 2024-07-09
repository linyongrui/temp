WITH TBC_CLN_ENCNTR_TYPE AS (
	SELECT 
		ENCNTR_TYPE_ID, ENCNTR_TYPE_CD 
	FROM CLN_ENCNTR_TYPE cet 
	WHERE cet.SVC_CD ='TBC'
	AND cet.ENCNTR_TYPE_CD IN ('TBC_CONS','TBC_TREAT','TBC_IM_CONTACT','TBC_IM_REFERRAL',
		'TBC_IM_SPECIAL','TBC_IM_CHEST','TBC_SKIN','TBC_SPEC','TBC_VAC')
)
,TBC_SITE AS (
	SELECT 
		SITE_ID, SITE_ENG_NAME 
	FROM CMN_SITE cs 
	WHERE cs.SVC_CD ='TBC' 
	AND cs.STATUS ='A' 
	AND nvl(cs.IS_MOCK_UP, 0) = 0 
	AND (cs.EFFT_DATE IS NULL OR trunc(cs.EFFT_DATE) <= TRUNC(SYSDATE) ) 
	AND (cs.EXPY_DATE IS NULL OR trunc(cs.EXPY_DATE) >= TRUNC(SYSDATE))
)
,TBC_CLC_ENCNTR_period AS (
	SELECT 
		ce.SITE_ID, ce.CASE_NO, ce.SDT, ets.ENCNTR_TYPE_CD, ce.PATIENT_KEY 
	FROM CLC_ENCNTR ce
	INNER JOIN TBC_SITE cs ON cs.SITE_ID = ce.SITE_ID
	INNER JOIN TBC_CLN_ENCNTR_TYPE ets ON ets.ENCNTR_TYPE_ID = ce.ENCNTR_TYPE_ID
	WHERE ce.ENCNTR_STS <> 'D' 
	AND nvl(ce.IS_CANCEL,0) = 0 
	AND ce.SVC_CD='TBC' 
    AND SDT >= to_date('2023-06-10','yyyy-mm-dd') and SDT < to_date('2024-07-10','yyyy-mm-dd')+1 
    AND cs.SITE_ID = decode(:i_siteId,'-',cs.SITE_ID,:i_siteId)
)
,TBC_CLC_ENCNTR_cons AS (
	SELECT 
		ce.SITE_ID,ce.CASE_NO,ce.SDT, ets.ENCNTR_TYPE_CD, ce.PATIENT_KEY  
	FROM CLC_ENCNTR ce
	INNER JOIN TBC_SITE cs ON cs.SITE_ID = ce.SITE_ID
	INNER JOIN TBC_CLN_ENCNTR_TYPE ets ON ets.ENCNTR_TYPE_ID = ce.ENCNTR_TYPE_ID
	WHERE ce.ENCNTR_STS <> 'D' 
	AND nvl(ce.IS_CANCEL,0) = 0  
	AND ce.SVC_CD='TBC' 
	AND ce.CASE_NO IS NOT NULL 
	AND ets.ENCNTR_TYPE_CD ='TBC_CONS'
	AND EXISTS (SELECT 1 FROM TBC_CLC_ENCNTR_period pe WHERE ce.CASE_NO = pe.CASE_NO AND pe.CASE_NO IS NOT NULL AND pe.ENCNTR_TYPE_CD ='TBC_CONS') 
)
, TBC_CLC_ENCNTR_cons_firstVisit AS (
	SELECT 
		temp.SITE_ID, 
		count(1) AS FIRST_VISIT 
	FROM (
		SELECT 
			ce.SITE_ID, ce.SDT, ce.PATIENT_KEY,
			ROW_NUMBER() OVER (PARTITION BY ce.CASE_NO ORDER BY ce.SDT ASC) AS NUM
		FROM TBC_CLC_ENCNTR_cons ce 
	) temp 
	INNER JOIN PMI_PATIENT pp ON pp.PATIENT_KEY = temp.PATIENT_KEY AND nvl(pp.IS_MOCK_UP,0) = 0
	WHERE temp.NUM = 1 
    AND temp.SDT >= to_date('2023-06-10','yyyy-mm-dd') and temp.SDT < to_date('2024-06-10','yyyy-mm-dd')+1
	GROUP BY temp.SITE_ID
)
SELECT 
	cs.SITE_ENG_NAME AS CENTRE,
	nvl(firstVisit.FIRST_VISIT,0) AS FIRST_VISIT ,
	nvl(TOTAL_CONS-nvl(firstVisit.FIRST_VISIT,0),0) AS RETURN_CONS ,
	nvl(RETURN_TREATMENT,0) AS RETURN_TREATMENT,
	nvl(IMAGE_CONTACT,0) AS IMAGE_CONTACT,
	nvl(IMAGE_REFERRAL,0) AS IMAGE_REFERRAL,
	nvl(IMAGE_SPECIAL,0) AS IMAGE_SPECIAL,
	nvl(IMAGE_TBCS,0)  AS IMAGE_TBCS,
	nvl(SKIN_IGRA,0) AS SKIN_IGRA,
	nvl(SPECIMEN_COLL,0) AS SPECIMEN_COLL,
	nvl(VACC,0) AS VACC,
	nvl(TOTAL_CONS,0) + nvl(RETURN_TREATMENT,0) +  nvl(IMAGE_CONTACT,0) 
        + nvl(IMAGE_REFERRAL,0) + nvl(IMAGE_SPECIAL,0) + nvl(IMAGE_TBCS,0) 
        + nvl(SKIN_IGRA,0) + nvl(SPECIMEN_COLL,0) + nvl(VACC,0) AS GRAND_TOTAL
FROM TBC_SITE cs
LEFT JOIN TBC_CLC_ENCNTR_cons_firstVisit firstVisit ON firstVisit.SITE_ID = cs.SITE_ID
LEFT JOIN (
	SELECT 
		SITE_ID,
		SUM(CASE WHEN ENCNTR_TYPE_CD = 'TBC_CONS' AND CASE_NO IS NOT NULL THEN 1 ELSE 0 END) AS TOTAL_CONS,
		SUM(CASE WHEN ENCNTR_TYPE_CD = 'TBC_TREAT' THEN 1 ELSE 0 END) AS RETURN_TREATMENT,
		SUM(CASE WHEN ENCNTR_TYPE_CD = 'TBC_IM_CONTACT' THEN 1 ELSE 0 END) AS IMAGE_CONTACT,
		SUM(CASE WHEN ENCNTR_TYPE_CD = 'TBC_IM_REFERRAL' THEN 1 ELSE 0 END) AS IMAGE_REFERRAL,
		SUM(CASE WHEN ENCNTR_TYPE_CD = 'TBC_IM_SPECIAL' THEN 1 ELSE 0 END) AS IMAGE_SPECIAL,
		SUM(CASE WHEN ENCNTR_TYPE_CD = 'TBC_IM_CHEST' THEN 1 ELSE 0 END) AS IMAGE_TBCS,
		SUM(CASE WHEN ENCNTR_TYPE_CD = 'TBC_SKIN' THEN 1 ELSE 0 END) AS SKIN_IGRA,
		SUM(CASE WHEN ENCNTR_TYPE_CD = 'TBC_SPEC' THEN 1 ELSE 0 END) AS SPECIMEN_COLL,
		SUM(CASE WHEN ENCNTR_TYPE_CD = 'TBC_VAC' THEN 1 ELSE 0 END) AS VACC
	FROM 
		TBC_CLC_ENCNTR_period ce 
		INNER JOIN PMI_PATIENT pp ON pp.PATIENT_KEY = ce.PATIENT_KEY AND nvl(pp.IS_MOCK_UP,0) = 0
	WHERE 1=1 
    and SITE_ID = decode(:i_siteId,'-',SITE_ID,:i_siteId)
	GROUP BY SITE_ID
) TEMP ON TEMP.SITE_ID =  cs.SITE_ID
WHERE 1=1 
and cs.SITE_ID = decode(:i_siteId,'-',cs.SITE_ID,:i_siteId)
ORDER BY cs.SITE_ENG_NAME;




WITH TBC_CLN_ENCNTR_TYPE AS (
	SELECT 
		ENCNTR_TYPE_ID, ENCNTR_TYPE_CD 
	FROM CLN_ENCNTR_TYPE cet 
	WHERE cet.SVC_CD ='TBC'
	AND cet.ENCNTR_TYPE_CD IN ('TBC_CONS','TBC_TREAT','TBC_IM_CONTACT','TBC_IM_REFERRAL',
		'TBC_IM_SPECIAL','TBC_IM_CHEST','TBC_SKIN','TBC_SPEC','TBC_VAC')
)
,TBC_SITE AS (
	SELECT 
		SITE_ID, SITE_ENG_NAME 
	FROM CMN_SITE cs 
	WHERE cs.SVC_CD ='TBC' 
	AND cs.STATUS ='A' 
	AND nvl(cs.IS_MOCK_UP, 0) = 0 
	AND (cs.EFFT_DATE IS NULL OR trunc(cs.EFFT_DATE) <= TRUNC(SYSDATE) ) 
	AND (cs.EXPY_DATE IS NULL OR trunc(cs.EXPY_DATE) >= TRUNC(SYSDATE))
)
,TBC_CLC_ENCNTR_period AS (
	SELECT 
		ce.SITE_ID, ce.CASE_NO, ce.SDT, ets.ENCNTR_TYPE_CD, ce.PATIENT_KEY 
	FROM CLC_ENCNTR ce
	INNER JOIN TBC_SITE cs ON cs.SITE_ID = ce.SITE_ID
--	INNER JOIN PMI_PATIENT pp ON pp.PATIENT_KEY = ce.PATIENT_KEY AND nvl(pp.IS_MOCK_UP,0) = 0
	INNER JOIN TBC_CLN_ENCNTR_TYPE ets ON ets.ENCNTR_TYPE_ID = ce.ENCNTR_TYPE_ID
	WHERE ce.ENCNTR_STS <> 'D' 
--	AND nvl(ce.IS_CANCEL,0) <> 1 
	AND nvl(ce.IS_CANCEL,0) = 0 
	AND ce.SVC_CD='TBC' 
--	AND SDT >= to_date(:i_startDate,'yyyy-mm-dd') and SDT < to_date(:i_endDate,'yyyy-mm-dd')+1 
    AND SDT >= to_date('2023-06-10','yyyy-mm-dd') and SDT < to_date('2024-07-10','yyyy-mm-dd')+1 
    AND cs.SITE_ID = decode(:i_siteId,'-',cs.SITE_ID,:i_siteId)
--    AND ce.site_id in (904,909)
--    AND ce.site_id in (select cs1.site_id from CMN_SITE cs1 where cs1.SVC_CD ='TBC')
--    AND exists (select 1 from CMN_SITE cs1 where cs1.SVC_CD ='TBC' and cs1.site_id = ce.site_id)
--    AND exists (select 1 from TBC_SITE cs1 where cs1.site_id = ce.site_id)
)
,TBC_CLC_ENCNTR_period_caseNO AS (
    SELECT DISTINCT pe.CASE_NO FROM TBC_CLC_ENCNTR_period pe WHERE pe.CASE_NO IS NOT NULL AND pe.ENCNTR_TYPE_CD ='TBC_CONS'
)
,TBC_CLC_ENCNTR_cons AS (
	SELECT 
		ce.SITE_ID,ce.CASE_NO,ce.SDT, ets.ENCNTR_TYPE_CD, ce.PATIENT_KEY  
	FROM CLC_ENCNTR ce
	INNER JOIN TBC_SITE cs ON cs.SITE_ID = ce.SITE_ID
--	INNER JOIN PMI_PATIENT pp ON pp.PATIENT_KEY = ce.PATIENT_KEY AND nvl(pp.IS_MOCK_UP,0) = 0 
	INNER JOIN TBC_CLN_ENCNTR_TYPE ets ON ets.ENCNTR_TYPE_ID = ce.ENCNTR_TYPE_ID
--    INNER JOIN TBC_CLC_ENCNTR_period_caseNO pcaseNo ON pcaseNo.CASE_NO = ce.CASE_NO
	WHERE ce.ENCNTR_STS <> 'D' 
--	AND nvl(ce.IS_CANCEL,0) <> 1 
	AND nvl(ce.IS_CANCEL,0) = 0  
	AND ce.SVC_CD='TBC' 
	AND ce.CASE_NO IS NOT NULL 
	AND ets.ENCNTR_TYPE_CD ='TBC_CONS'
--    AND EXISTS (SELECT 1 FROM TBC_CLC_ENCNTR_period pe WHERE ce.CASE_NO = pe.CASE_NO AND pe.CASE_NO IS NOT NULL AND pe.ENCNTR_TYPE_CD ='TBC_CONS') 
--    AND ce.site_id in (904,909)
--    AND ce.site_id in (select cs1.site_id from CMN_SITE cs1 where cs1.SVC_CD ='TBC')
--    AND exists (select 1 from CMN_SITE cs1 where cs1.SVC_CD ='TBC' and cs1.site_id = ce.site_id)
--    AND exists (select 1 from TBC_SITE cs1 where cs1.site_id = ce.site_id)
)
--,TBC_CONS_PERIOD_CASE_NO AS (
--	SELECT 
--		DISTINCT ce.CASE_NO 
--	FROM TBC_CLC_ENCNTR_period ce 
--	WHERE ce.CASE_NO IS NOT NULL 
--	AND ce.ENCNTR_TYPE_CD ='TBC_CONS'
--)
, TBC_CLC_ENCNTR_cons_firstVisit AS (
	SELECT 
		temp.SITE_ID, 
		count(1) AS FIRST_VISIT 
	FROM (
		SELECT 
			ce.SITE_ID, ce.SDT, ce.PATIENT_KEY,
			ROW_NUMBER() OVER (PARTITION BY ce.CASE_NO ORDER BY ce.SDT ASC) AS NUM
		FROM TBC_CLC_ENCNTR_cons ce 
        INNER JOIN TBC_CLC_ENCNTR_period_caseNO pcaseNo ON pcaseNo.CASE_NO = ce.CASE_NO
--		WHERE EXISTS (SELECT 1 FROM TBC_CLC_ENCNTR_period pe WHERE ce.CASE_NO = pe.CASE_NO AND pe.ENCNTR_TYPE_CD ='TBC_CONS') 
	) temp 
	INNER JOIN PMI_PATIENT pp ON pp.PATIENT_KEY = temp.PATIENT_KEY AND nvl(pp.IS_MOCK_UP,0) = 0
	WHERE temp.NUM = 1 
    AND temp.SDT >= to_date('2023-06-10','yyyy-mm-dd') and temp.SDT < to_date('2024-06-10','yyyy-mm-dd')+1
	GROUP BY temp.SITE_ID
)
SELECT 
	cs.SITE_ENG_NAME AS CENTRE,
	nvl(firstVisit.FIRST_VISIT,0) AS FIRST_VISIT ,
	nvl(TOTAL_CONS-nvl(firstVisit.FIRST_VISIT,0),0) AS RETURN_CONS ,
	nvl(RETURN_TREATMENT,0) AS RETURN_TREATMENT,
	nvl(IMAGE_CONTACT,0) AS IMAGE_CONTACT,
	nvl(IMAGE_REFERRAL,0) AS IMAGE_REFERRAL,
	nvl(IMAGE_SPECIAL,0) AS IMAGE_SPECIAL,
	nvl(IMAGE_TBCS,0)  AS IMAGE_TBCS,
	nvl(SKIN_IGRA,0) AS SKIN_IGRA,
	nvl(SPECIMEN_COLL,0) AS SPECIMEN_COLL,
	nvl(VACC,0) AS VACC,
	nvl(TOTAL_CONS,0) + nvl(RETURN_TREATMENT,0) +  nvl(IMAGE_CONTACT,0) 
        + nvl(IMAGE_REFERRAL,0) + nvl(IMAGE_SPECIAL,0) + nvl(IMAGE_TBCS,0) 
        + nvl(SKIN_IGRA,0) + nvl(SPECIMEN_COLL,0) + nvl(VACC,0) AS GRAND_TOTAL
FROM TBC_SITE cs
LEFT JOIN TBC_CLC_ENCNTR_cons_firstVisit firstVisit ON firstVisit.SITE_ID = cs.SITE_ID
LEFT JOIN (
	SELECT 
		SITE_ID,
		SUM(CASE WHEN ENCNTR_TYPE_CD = 'TBC_CONS' AND CASE_NO IS NOT NULL THEN 1 ELSE 0 END) AS TOTAL_CONS,
		SUM(CASE WHEN ENCNTR_TYPE_CD = 'TBC_TREAT' THEN 1 ELSE 0 END) AS RETURN_TREATMENT,
		SUM(CASE WHEN ENCNTR_TYPE_CD = 'TBC_IM_CONTACT' THEN 1 ELSE 0 END) AS IMAGE_CONTACT,
		SUM(CASE WHEN ENCNTR_TYPE_CD = 'TBC_IM_REFERRAL' THEN 1 ELSE 0 END) AS IMAGE_REFERRAL,
		SUM(CASE WHEN ENCNTR_TYPE_CD = 'TBC_IM_SPECIAL' THEN 1 ELSE 0 END) AS IMAGE_SPECIAL,
		SUM(CASE WHEN ENCNTR_TYPE_CD = 'TBC_IM_CHEST' THEN 1 ELSE 0 END) AS IMAGE_TBCS,
		SUM(CASE WHEN ENCNTR_TYPE_CD = 'TBC_SKIN' THEN 1 ELSE 0 END) AS SKIN_IGRA,
		SUM(CASE WHEN ENCNTR_TYPE_CD = 'TBC_SPEC' THEN 1 ELSE 0 END) AS SPECIMEN_COLL,
		SUM(CASE WHEN ENCNTR_TYPE_CD = 'TBC_VAC' THEN 1 ELSE 0 END) AS VACC
	FROM 
		TBC_CLC_ENCNTR_period ce 
		INNER JOIN PMI_PATIENT pp ON pp.PATIENT_KEY = ce.PATIENT_KEY AND nvl(pp.IS_MOCK_UP,0) = 0
	WHERE 1=1 
    and SITE_ID = decode(:i_siteId,'-',SITE_ID,:i_siteId)
	GROUP BY SITE_ID
) TEMP ON TEMP.SITE_ID =  cs.SITE_ID
WHERE 1=1 
and cs.SITE_ID = decode(:i_siteId,'-',cs.SITE_ID,:i_siteId)
ORDER BY cs.SITE_ENG_NAME;