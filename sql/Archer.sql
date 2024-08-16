-------------------------------------------------------------------------------------------------------------------
-- CIMST-32939 : (StdHS) RPT-STH-R034 Check Paid Student
-------------------------------------------------------------------------------------------------------------------
WITH STH_SITES AS (
	SELECT 
		SITE_ID
	FROM CMN_SITE cs
	WHERE cs.SVC_CD ='STH' 
	AND NVL(cs.IS_MOCK_UP,0) = 0
	AND cs.SITE_ID = TO_NUMBER(:i_site_id)
)
, STH_ENCNTR_TYPES AS (
	SELECT
		cet.ENCNTR_TYPE_ID
	FROM CLN_ENCNTR_TYPE cet
	WHERE cet.SVC_CD = 'STH' 
	AND cet.ENCNTR_TYPE_CATGRY IN ('SAC', 'SHSC')
	AND cet.ENCNTR_TYPE_CD <> 'F'
	AND (cet.SITE_ID IS NULL OR NVL(cet.SITE_ID , 0) = TO_NUMBER(:i_site_id))
)
, STH_ANA_ATTENDS AS (
	SELECT
		aa.ATND_ID, aa.PATIENT_KEY, aa.ARRIVAL_TIME, aa.UPDATE_BY, aa.SITE_ID 
	FROM ANA_ATND aa
	WHERE NVL(aa.IS_CANCEL, 0) = 0 
	AND aa.SITE_ID = TO_NUMBER(:i_site_id)
	AND aa.ARRIVAL_TIME >= TO_DATE(:i_from_date,'yyyy-MM-dd') AND aa.ARRIVAL_TIME < (TO_DATE(:i_to_date,'yyyy-MM-dd') + 1)
	AND NVL(aa.IS_NEP, 0) = 1
)
, sth_attend_list AS (
	SELECT 
		aa.ATND_ID, aa.PATIENT_KEY, aa.ARRIVAL_TIME, aa.UPDATE_BY 
	FROM STH_ANA_ATTENDS aa 
	INNER JOIN STH_SITES cs ON cs.SITE_ID = aa.SITE_ID 
	INNER JOIN CLC_ENCNTR ce ON aa.ATND_ID = ce.ATND_ID 
	INNER JOIN STH_ENCNTR_TYPES cet ON ce.ENCNTR_TYPE_ID = cet.ENCNTR_TYPE_ID
	WHERE NVL(ce.IS_CANCEL, 0) = 0 
	AND (ce.ENCNTR_STS IS NULL OR ce.ENCNTR_STS > 'D' OR ce.ENCNTR_STS < 'D')
)
, sth_patient_key AS (
	SELECT DISTINCT PATIENT_KEY FROM sth_attend_list
)
, sth_patient AS (
	SELECT
		aa.PATIENT_KEY,
		psi.ELIGIBILITY_CD, 
		cdt.ENG_DESC,
	    ppd.DOC_TYPE_CD,
	    ppd.DOC_NO,
	    pp.ENG_SURNAME,
	    pp.ENG_GIVENAME,
	    pp.NAME_CHI
	FROM sth_patient_key aa
	INNER JOIN PMI_STH_INFO psi ON psi.PATIENT_KEY = aa.PATIENT_KEY
	INNER JOIN PMI_PATIENT pp ON pp.PATIENT_KEY = aa.PATIENT_KEY
	INNER JOIN PMI_PATIENT_DOCUMENT_PAIR ppd ON pp.PATIENT_KEY = ppd.PATIENT_KEY
	INNER JOIN COD_DOC_TYPE cdt ON cdt.TYPE_CD = ppd.DOC_TYPE_CD
	WHERE NVL(pp.IS_MOCK_UP, 0) = 0 AND ppd.IS_PRIMARY = 1
)
SELECT 
	ROWNUM AS NUM,
	t.PATIENT_KEY AS PMI,
	t.ENG_NAME,
	t.CHI_NAME,
	t.DOC_TYPE,
	t.DOC_NO,
	t.STUDENT_TYPE,
	t.CHECKED_BY_STH_STAFF,
	t.ATTENDANCE_DATE
FROM (
	SELECT 
		TO_CHAR(aa.PATIENT_KEY, 'fm0000000000') AS PATIENT_KEY,
		TO_CHAR(aa.ARRIVAL_TIME, 'DD/MON/YYYY', 'nls_date_language=american') AS ATTENDANCE_DATE,
		TRIM(uu.ENG_GIV_NAME || ' ' || uu.ENG_SURNAME) AS CHECKED_BY_STH_STAFF,
		pp.ELIGIBILITY_CD AS STUDENT_TYPE,
		pp.ENG_DESC AS DOC_TYPE,
	    TRIM(CASE WHEN pp.DOC_TYPE_CD IN ('ID','BC') AND pp.DOC_NO IS NOT NULL
	        THEN SUBSTR(pp.DOC_NO, 1, LENGTH(pp.DOC_NO) - 1) || '(' || SUBSTR(pp.DOC_NO, -1) || ')'
	        ELSE pp.DOC_NO END) AS DOC_NO,
	    TRIM(pp.ENG_SURNAME||' '||pp.ENG_GIVENAME) AS ENG_NAME,
	    pp.NAME_CHI AS CHI_NAME
	FROM sth_attend_list aa 
	INNER JOIN sth_patient pp ON pp.PATIENT_KEY = aa.PATIENT_KEY
	LEFT JOIN UAM_USER uu ON uu.LOGIN_NAME = aa.UPDATE_BY
	ORDER BY TRUNC(aa.ARRIVAL_TIME) ASC, aa.PATIENT_KEY ASC
) t;

-------------------------------------------------------------------------------------------------------------------
-- CIMST-33102: (TB&C) RPT-TBCS-STA-0020 Consultation and Treatment Attendance by Age Group and Sex
-------------------------------------------------------------------------------------------------------------------
WITH TBC_CMN_SITE AS (
	SELECT 
		cs.SITE_ID
	FROM CMN_SITE cs 
	WHERE cs.SVC_CD ='TBC' AND cs.STATUS ='A' AND NVL(cs.IS_MOCK_UP,0) = 0
	AND (cs.EFFT_DATE IS NULL OR TRUNC(cs.EFFT_DATE) <= TRUNC(SYSDATE)) 
	AND (cs.EXPY_DATE IS NULL OR TRUNC(cs.EXPY_DATE) >= TRUNC(SYSDATE))
	AND cs.SITE_ID = DECODE(:i_site_id,'-', cs.SITE_ID, :i_site_id)
)
, TBC_ENCNTR_TYPE AS (
	SELECT 
		cet.ENCNTR_TYPE_ID, cet.ENCNTR_TYPE_CD 
	FROM CLN_ENCNTR_TYPE cet 
	WHERE cet.SVC_CD = 'TBC' 
	AND cet.ENCNTR_TYPE_CD IN ('TBC_CONS','TBC_TREAT')
)
, TBC_CLC_ENCNTR_1 AS (
	SELECT 
		ce.ATND_ID, ce.PATIENT_KEY,ce.SDT, ce.ENCNTR_TYPE_ID, ce.SITE_ID 
	FROM CLC_ENCNTR ce 
	WHERE ce.SVC_CD = 'TBC'
	AND ce.SDT >= TO_DATE(:i_from_date, 'YYYY-MM-dd') AND ce.SDT < TO_DATE(:i_to_date, 'YYYY-MM-dd') + 1
	AND NVL(ce.IS_CANCEL, 0) = 0
	AND (ce.ENCNTR_STS IS NULL OR ce.ENCNTR_STS < 'D' OR ce.ENCNTR_STS > 'D')
)
, TBC_CLC_ENCNTR AS (
	SELECT 
		ce.ATND_ID, ce.PATIENT_KEY,ce.SDT, cet.ENCNTR_TYPE_CD
	FROM TBC_CLC_ENCNTR_1 ce 
	INNER JOIN TBC_ENCNTR_TYPE cet ON cet.ENCNTR_TYPE_ID = ce.ENCNTR_TYPE_ID
	INNER JOIN TBC_CMN_SITE cs ON cs.SITE_ID = ce.SITE_ID
)
, attend AS (
	SELECT 
		ce.ATND_ID, ce.PATIENT_KEY, ce.ENCNTR_TYPE_CD, pp.GENDER_CD,
		TRUNC(MONTHS_BETWEEN(ce.SDT, pp.DOB) / 12) AS ATTEND_AGE
	FROM TBC_CLC_ENCNTR ce 
	INNER JOIN PMI_PATIENT pp ON pp.PATIENT_KEY = ce.PATIENT_KEY 
	WHERE NVL(pp.IS_MOCK_UP, 0) = 0
)
SELECT 
	CASE AGE_INDEX WHEN 17 THEN '85 or above' ELSE AGE_INDEX * 5 || '-' || (AGE_INDEX * 5 + 4) END AS AGE_RANGE,
    COUNT(CASE WHEN GENDER_CD = 'M' AND ENCNTR_TYPE_CD = 'TBC_CONS' THEN 1 ELSE NULL END) AS TBC_CONS_MALE,
    COUNT(CASE WHEN GENDER_CD = 'F' AND ENCNTR_TYPE_CD = 'TBC_CONS' THEN 1 ELSE NULL END) AS TBC_CONS_FEMALE,
    COUNT(CASE WHEN GENDER_CD = 'U' AND ENCNTR_TYPE_CD = 'TBC_CONS' THEN 1 ELSE NULL END) AS TBC_CONS_UNKNOWN,
    COUNT(CASE WHEN                     ENCNTR_TYPE_CD = 'TBC_CONS' THEN 1 ELSE NULL END) AS TBC_CONS_TOTAL,
    COUNT(CASE WHEN GENDER_CD = 'M' AND ENCNTR_TYPE_CD = 'TBC_TREAT' THEN 1 ELSE NULL END) AS TBC_TREAT_MALE,
    COUNT(CASE WHEN GENDER_CD = 'F' AND ENCNTR_TYPE_CD = 'TBC_TREAT' THEN 1 ELSE NULL END) AS TBC_TREAT_FEMALE,
    COUNT(CASE WHEN GENDER_CD = 'U' AND ENCNTR_TYPE_CD = 'TBC_TREAT' THEN 1 ELSE NULL END) AS TBC_TREAT_UNKNOWN,
    COUNT(CASE WHEN                     ENCNTR_TYPE_CD = 'TBC_TREAT' THEN 1 ELSE NULL END) AS TBC_TREAT_TOTAL,
    COUNT(CASE WHEN GENDER_CD = 'M' THEN 1 ELSE NULL END) AS MALE_TOTAL,
    COUNT(CASE WHEN GENDER_CD = 'F' THEN 1 ELSE NULL END) AS FEMALE_TOTAL,
    COUNT(CASE WHEN GENDER_CD = 'U' THEN 1 ELSE NULL END) AS UNKNOWN_TOTAL,
    COUNT(CASE WHEN GENDER_CD IS NOT NULL THEN 1 ELSE NULL END) AS ALL_TOTAL
FROM (
    SELECT 
    	TRUNC(CASE WHEN ATTEND_AGE >= 85 THEN 85 ELSE ATTEND_AGE END / 5) AS AGE_INDEX, 
    	ENCNTR_TYPE_CD, GENDER_CD
    FROM attend
    UNION ALL
    SELECT 
    	LEVEL - 1 AS AGE_INDEX, 
    	NUll AS ENCNTR_TYPE_CD, NUll AS GENDER_CD
    FROM DUAL CONNECT BY LEVEL <= 18
)
GROUP BY AGE_INDEX
ORDER BY AGE_INDEX;


-------------------------------------------------------------------------------------------------------------------
-- CIMST-33100: (TB&C) RPT-TBCS-STA-0019 Number of Treatment Attendance by Clinic
-------------------------------------------------------------------------------------------------------------------
WITH TBC_CMN_SITE AS (
	SELECT 
		cs.SITE_ID
	FROM CMN_SITE cs 
	WHERE cs.SVC_CD ='TBC' AND cs.STATUS ='A' AND nvl(cs.IS_MOCK_UP,0) = 0
	AND (cs.EFFT_DATE IS NULL OR trunc(cs.EFFT_DATE) <= TRUNC(SYSDATE)) 
	AND (cs.EXPY_DATE IS NULL OR trunc(cs.EXPY_DATE) >= TRUNC(SYSDATE))
	AND cs.SITE_ID = DECODE(:i_site_id,'-', cs.SITE_ID, :i_site_id)
)
, TBC_CLC_ENCNTR_1 AS (
	SELECT 
		ce.ATND_ID, ce.PATIENT_KEY, ce.SDT,ce.SITE_ID, ce.ENCNTR_TYPE_ID 
	FROM CLC_ENCNTR ce 
	WHERE ce.SVC_CD = 'TBC'
	AND ce.SITE_ID = DECODE(:i_site_id,'-', ce.SITE_ID, :i_site_id)
	AND ce.SDT >= TO_DATE(:i_from_date, 'YYYY-MM-dd') AND ce.SDT < TO_DATE(:i_to_date, 'YYYY-MM-dd') + 1
	AND nvl(ce.IS_CANCEL, 0) = 0
	AND (ce.ENCNTR_STS IS NULL OR ce.ENCNTR_STS < 'D' OR ce.ENCNTR_STS > 'D')
)
, TBC_CLC_ENCNTR AS (
	SELECT 
		ce.ATND_ID, ce.PATIENT_KEY, TO_CHAR(ce.SDT, 'hh24:mi:ss') AS HHMMSS
	FROM TBC_CLC_ENCNTR_1 ce 
	INNER JOIN CLN_ENCNTR_TYPE cet ON cet.ENCNTR_TYPE_ID = ce.ENCNTR_TYPE_ID AND cet.ENCNTR_TYPE_CD = 'TBC_TREAT'
	INNER JOIN TBC_CMN_SITE cs ON cs.SITE_ID = ce.SITE_ID
)
SELECT 
	NVL(SUM(SESSION_OF_ARRIVAL_AM), 0) AS AM_TOTAL,
	NVL(SUM(SESSION_OF_ARRIVAL_PM), 0) AS PM_TOTAL,
	NVL(SUM(SESSION_OF_ARRIVAL_EVENING), 0) AS EVENING_TOTAL
FROM ( 
	SELECT 
		ce.ATND_ID, ce.PATIENT_KEY,
		CASE WHEN ('00:00:00' <= ce.HHMMSS AND ce.HHMMSS <= '13:59:59') THEN 1 ELSE 0 END AS SESSION_OF_ARRIVAL_AM,
		CASE WHEN ('14:00:00' <= ce.HHMMSS AND ce.HHMMSS <= '17:29:59') THEN 1 ELSE 0 END AS SESSION_OF_ARRIVAL_PM,
		CASE WHEN ('17:30:00' <= ce.HHMMSS AND ce.HHMMSS <= '23:59:59') THEN 1 ELSE 0 END AS SESSION_OF_ARRIVAL_EVENING
	FROM TBC_CLC_ENCNTR ce 
	INNER JOIN PMI_PATIENT pp ON pp.PATIENT_KEY = ce.PATIENT_KEY 
	WHERE NVL(pp.IS_MOCK_UP,0) = 0
) t;

-------------------------------------------------------------------------------------------------------------------
-- CIMST-32307: (StdHS) RPT-STH-R004 Defaulter List
-------------------------------------------------------------------------------------------------------------------
WITH STH_SITES AS (
	SELECT 
		SITE_ID, SITE_CD, SITE_ENG_NAME 
	FROM CMN_SITE cs
	WHERE cs.SVC_CD ='STH' 
	AND nvl(cs.IS_MOCK_UP,0) = 0
	AND nvl(cs.SITE_ID , 0) = TO_NUMBER(:i_site_id)
)
, STH_ENCNTR_TYPES AS (
	SELECT
		cet.ENCNTR_TYPE_ID, cet.ENCNTR_TYPE_CD, cet.ENCNTR_TYPE_DESC
	FROM CLN_ENCNTR_TYPE cet
	WHERE cet.ENCNTR_TYPE_CD IN ('SHSC-AA', 'SHSC-P3', 'SHSC-SS/SQ', 'F')
	AND cet.SVC_CD = 'STH'
	AND (cet.SITE_ID IS NULL OR nvl(cet.SITE_ID , 0) = TO_NUMBER(:i_site_id))
)
, STH_ANA_APPTS AS (
	SELECT
		aa.SITE_ID, aa.APPT_ID, aa.PATIENT_KEY, aa.APPT_DATE
	FROM ANA_APPT aa
	WHERE aa.APPT_TYPE_CD <> 'D'
	AND aa.SITE_ID = TO_NUMBER(:i_site_id)
	AND aa.APPT_DATE >= TO_DATE(:i_from_date,'yyyy-MM-dd') AND aa.APPT_DATE < TO_DATE(:i_to_date,'yyyy-MM-dd') + 1
)
, appt_list AS (
	SELECT
		aa.SITE_ID, aa.APPT_ID, aa.PATIENT_KEY, aa.APPT_DATE, sad.SCH_ID, sad.GRADE, sad.CLASS,
		cet.ENCNTR_TYPE_ID, cet.ENCNTR_TYPE_CD, cet.ENCNTR_TYPE_DESC
	FROM STH_ANA_APPTS aa
	INNER JOIN STH_SITES sites ON sites.SITE_ID = aa.SITE_ID
	INNER JOIN ANA_APPT_DETL aad ON aa.APPT_ID = aad.APPT_ID
    INNER JOIN STH_APPT_DETL sad ON aa.APPT_ID = sad.APPT_ID AND sad.STATUS = 'A'
    INNER JOIN STH_ENCNTR_TYPES cet ON cet.ENCNTR_TYPE_ID = aad.ENCNTR_TYPE_ID
	WHERE NVL(aad.IS_OBS, 0) = 0
)
, appt_list_base AS (
	SELECT
	    aa.*,
	    ROW_NUMBER() OVER (PARTITION BY aa.APPT_ID, ce.ENCNTR_ID ORDER BY q.VISIT_SEQUENCE DESC) AS RN,
	    scsp.VISIT_POINT_DESCRIPTION
	FROM appt_list aa
	LEFT JOIN ANA_ATND atnd ON aa.APPT_ID = atnd.APPT_ID
	LEFT JOIN CLC_ENCNTR ce ON atnd.ATND_ID = ce.ATND_ID AND NVL(ce.IS_CANCEL, 0) = 0 AND ce.ENCNTR_STS <> 'D'
	LEFT JOIN STH_S_WAITING_QUEUE q ON q.ENCNTR_ID = ce.ENCNTR_ID AND q.IS_DEL = 0 AND q.VISIT_POINT_CD <> '5'
	LEFT JOIN STH_C_SERVICE_POINT scsp ON scsp.VISIT_POINT_CD = q.VISIT_POINT_CD 
		AND scsp.IS_ACTIVE = 'Y' AND scsp.CENTRE_TYPE = 1
)
, base_patientKey AS (
	SELECT DISTINCT PATIENT_KEY FROM appt_list_base
)
, pmi_phone AS(
    SELECT
    	ppp.*
    FROM
    base_patientKey p
    INNER JOIN PMI_PATIENT_PHONE ppp on p.PATIENT_KEY = ppp.PATIENT_KEY and ppp.PHONE_TYPE_CD IN ('H','M')
)
, home_tel AS(
    SELECT
    	PATIENT_KEY,
    	CASE WHEN PHONE_NO IS NULL OR DIALING_CD=852 OR DIALING_CD IS NULL THEN '' ELSE '+'||DIALING_CD||' ' END AS DIALING_CD,
    	CASE WHEN PHONE_NO IS NULL OR DIALING_CD=852 OR AREA_CD IS NULL THEN '' ELSE AREA_CD||' ' END AS AREA_CD,
    	PHONE_NO
    FROM (
        SELECT
        	d.*,
        	ROW_NUMBER() OVER(PARTITION BY d.PATIENT_KEY ORDER BY d.UPDATE_DTM DESC, d.PATIENT_PHONE_ID ASC) pm
        FROM (SELECT * FROM PMI_PHONE WHERE PHONE_TYPE_CD ='H') d
    ) WHERE pm = 1
)
, cont_tel AS(
    SELECT
    	PATIENT_KEY,
    	CASE WHEN PHONE_NO is null OR DIALING_CD=852 OR DIALING_CD IS NULL THEN '' ELSE '+'||DIALING_CD||' ' END AS DIALING_CD,
    	CASE WHEN PHONE_NO is null OR DIALING_CD=852 OR AREA_CD IS NULL THEN '' ELSE AREA_CD||' ' END AS AREA_CD,
    	PHONE_NO
    FROM (
        SELECT
        	d.*,
        	ROW_NUMBER() OVER(PARTITION BY d.PATIENT_KEY ORDER BY d.SMS_PHONE_IND DESC, d.UPDATE_DTM DESC, d.PATIENT_PHONE_ID ASC) pm
        FROM (SELECT * FROM PMI_PHONE WHERE PHONE_TYPE_CD ='M') d
    ) WHERE pm = 1
)
SELECT
	cet.ENCNTR_TYPE_ID,
	cet.ENCNTR_TYPE_DESC,
	t.APPT_DATE,
	t.APPT_DATE_STR,
	t.DOC_TYPE,
	t.DOC_NO,
	t.ENG_NAME,
	t.CHI_NAME,
	t.SCH_ID,
	t.GRADE_CLASS,
	t.HOME_TEL,
	t.CONT_TEL,
	t.VISIT_POINT_DESCRIPTION
FROM STH_ENCNTR_TYPES cet
LEFT JOIN (
	SELECT
		aa.ENCNTR_TYPE_ID,
		TRUNC(aa.APPT_DATE) AS APPT_DATE,
		TO_CHAR(aa.APPT_DATE,'dd/MM/yyyy') AS APPT_DATE_STR,
		d.ENG_DESC as DOC_TYPE,
	    trim(
	    	CASE WHEN ppdp.DOC_TYPE_CD in('ID','BC') AND ppdp.DOC_NO IS NOT NULL
	        	THEN SUBSTR(ppdp.DOC_NO, 1, LENGTH(ppdp.DOC_NO) - 1) || '(' || SUBSTR(ppdp.DOC_NO, -1) || ')'
	        	ELSE ppdp.DOC_NO END
	    	) AS DOC_NO,
	    trim(pp.ENG_SURNAME||' '||pp.ENG_GIVENAME) as ENG_NAME,
	    pp.NAME_CHI AS CHI_NAME,
	    aa.SCH_ID,
	    aa.GRADE||' / '||aa.CLASS AS GRADE_CLASS,
	    trim(h.DIALING_CD||h.AREA_CD||h.PHONE_NO) as HOME_TEL,
		trim(c.DIALING_CD||c.AREA_CD||c.PHONE_NO) as CONT_TEL,
		aa.VISIT_POINT_DESCRIPTION
	FROM appt_list_base aa
	INNER JOIN PMI_PATIENT pp ON aa.PATIENT_KEY = pp.PATIENT_KEY AND NVL(pp.IS_MOCK_UP, 0) = 0
	LEFT JOIN PMI_PATIENT_DOCUMENT_PAIR ppdp ON ppdp.PATIENT_KEY = pp.PATIENT_KEY AND ppdp.IS_PRIMARY = 1
	LEFT JOIN COD_DOC_TYPE d on ppdp.DOC_TYPE_CD = d.TYPE_CD
	LEFT JOIN home_tel h on aa.PATIENT_KEY = h.PATIENT_KEY
	LEFT JOIN cont_tel c on aa.PATIENT_KEY = c.PATIENT_KEY
	WHERE aa.RN = 1
) t ON t.ENCNTR_TYPE_ID = cet.ENCNTR_TYPE_ID
ORDER BY cet.ENCNTR_TYPE_DESC, t.APPT_DATE, t.DOC_NO;

-------------------------------------------------------------------------------------------------------------------
-- CIMST-32307: (StdHS) RPT-STH-R004 Defaulter List
-------------------------------------------------------------------------------------------------------------------
WITH STH_SITES AS (
	SELECT 
		SITE_ID, SITE_CD, SITE_ENG_NAME 
	FROM CMN_SITE cs
	WHERE cs.SVC_CD ='STH' 
	AND nvl(cs.IS_MOCK_UP,0) = 0
	AND cs.SITE_ID = TO_NUMBER(:i_site_id)
)
, STH_ENCNTR_TYPES AS (
	SELECT
		cet.ENCNTR_TYPE_ID, cet.ENCNTR_TYPE_CD, cet.ENCNTR_TYPE_DESC
	FROM CLN_ENCNTR_TYPE cet
	WHERE cet.ENCNTR_TYPE_CD IN ('SHSC-AA', 'SHSC-P3', 'SHSC-SS/SQ', 'F')
	AND cet.SVC_CD = 'STH'
	AND (cet.SITE_ID IS NULL OR nvl(cet.SITE_ID , 0) = TO_NUMBER(:i_site_id))
)
, STH_ANA_APPTS AS (
	SELECT
		aa.SITE_ID, aa.APPT_ID, aa.PATIENT_KEY, aa.APPT_DATE
	FROM ANA_APPT aa
	WHERE aa.APPT_TYPE_CD <> 'D'
	AND aa.SITE_ID = TO_NUMBER(:i_site_id)
	AND aa.APPT_DATE >= TO_DATE(:i_from_date,'yyyy-MM-dd') AND aa.APPT_DATE < TO_DATE(:i_to_date,'yyyy-MM-dd') + 1
)
, appt_list AS (
	SELECT
		aa.SITE_ID, aa.APPT_ID, aa.PATIENT_KEY, aa.APPT_DATE, sad.SCH_ID, sad.GRADE, sad.CLASS,
		cet.ENCNTR_TYPE_ID, cet.ENCNTR_TYPE_CD, cet.ENCNTR_TYPE_DESC
	FROM STH_ANA_APPTS aa
	INNER JOIN STH_SITES sites ON sites.SITE_ID = aa.SITE_ID
	INNER JOIN ANA_APPT_DETL aad ON aa.APPT_ID = aad.APPT_ID
	INNER JOIN STH_ENCNTR_TYPES cet ON cet.ENCNTR_TYPE_ID = aad.ENCNTR_TYPE_ID
    INNER JOIN STH_APPT_DETL sad ON aa.APPT_ID = sad.APPT_ID
	WHERE NVL(aad.IS_OBS, 0) = 0 AND sad.STATUS = 'A'
)
, appt_list_base AS (
	SELECT
	    aa.*,
	    ROW_NUMBER() OVER (PARTITION BY aa.APPT_ID, ce.ENCNTR_ID ORDER BY q.VISIT_SEQUENCE DESC) AS RN,
	    scsp.VISIT_POINT_CD,
	    scsp.VISIT_POINT_DESCRIPTION
	FROM appt_list aa
	LEFT JOIN ANA_ATND atnd ON aa.APPT_ID = atnd.APPT_ID
	LEFT JOIN CLC_ENCNTR ce ON atnd.ATND_ID = ce.ATND_ID AND NVL(ce.IS_CANCEL, 0) = 0 AND ce.ENCNTR_STS <> 'D'
	LEFT JOIN STH_S_WAITING_QUEUE q ON q.ENCNTR_ID = ce.ENCNTR_ID AND q.IS_DEL = 0
	LEFT JOIN STH_C_SERVICE_POINT scsp ON scsp.VISIT_POINT_CD = q.VISIT_POINT_CD
		AND scsp.IS_ACTIVE = 'Y' AND scsp.CENTRE_TYPE = 1
)
, base_patientKey AS (
	SELECT DISTINCT PATIENT_KEY FROM appt_list
)
, pmi_phone AS(
    SELECT
    	ppp.*
    FROM
    base_patientKey p
    INNER JOIN PMI_PATIENT_PHONE ppp on p.PATIENT_KEY = ppp.PATIENT_KEY and ppp.PHONE_TYPE_CD IN ('H','M')
)
, home_tel AS(
    SELECT
    	PATIENT_KEY,
    	CASE WHEN PHONE_NO IS NULL OR DIALING_CD=852 OR DIALING_CD IS NULL THEN '' ELSE '+'||DIALING_CD||' ' END AS DIALING_CD,
    	CASE WHEN PHONE_NO IS NULL OR DIALING_CD=852 OR AREA_CD IS NULL THEN '' ELSE AREA_CD||' ' END AS AREA_CD,
    	PHONE_NO
    FROM (
        SELECT
        	d.*,
        	ROW_NUMBER() OVER(PARTITION BY d.PATIENT_KEY ORDER BY d.UPDATE_DTM DESC, d.PATIENT_PHONE_ID ASC) pm
        FROM (SELECT * FROM PMI_PHONE WHERE PHONE_TYPE_CD ='H') d
    ) WHERE pm = 1
)
, cont_tel AS(
    SELECT
    	PATIENT_KEY,
    	CASE WHEN PHONE_NO is null OR DIALING_CD=852 OR DIALING_CD IS NULL THEN '' ELSE '+'||DIALING_CD||' ' END AS DIALING_CD,
    	CASE WHEN PHONE_NO is null OR DIALING_CD=852 OR AREA_CD IS NULL THEN '' ELSE AREA_CD||' ' END AS AREA_CD,
    	PHONE_NO
    FROM (
        SELECT
        	d.*,
        	ROW_NUMBER() OVER(PARTITION BY d.PATIENT_KEY ORDER BY d.SMS_PHONE_IND DESC, d.UPDATE_DTM DESC, d.PATIENT_PHONE_ID ASC) pm
        FROM (SELECT * FROM PMI_PHONE WHERE PHONE_TYPE_CD ='M') d
    ) WHERE pm = 1
)
SELECT
	cet.ENCNTR_TYPE_ID,
	cet.ENCNTR_TYPE_DESC,
	t.APPT_DATE,
	t.APPT_DATE_STR,
	t.DOC_TYPE,
	t.DOC_NO,
	t.ENG_NAME,
	t.CHI_NAME,
	t.SCH_ID,
	t.GRADE_CLASS,
	t.HOME_TEL,
	t.CONT_TEL,
	t.VISIT_POINT_DESCRIPTION
FROM STH_ENCNTR_TYPES cet
LEFT JOIN (
	SELECT
		aa.ENCNTR_TYPE_ID,
		TRUNC(aa.APPT_DATE) AS APPT_DATE,
		TO_CHAR(aa.APPT_DATE,'dd/MM/yyyy') AS APPT_DATE_STR,
		d.ENG_DESC as DOC_TYPE,
	    trim(
	    	CASE WHEN ppdp.DOC_TYPE_CD in('ID','BC') AND ppdp.DOC_NO IS NOT NULL
	        	THEN SUBSTR(ppdp.DOC_NO, 1, LENGTH(ppdp.DOC_NO) - 1) || '(' || SUBSTR(ppdp.DOC_NO, -1) || ')'
	        	ELSE ppdp.DOC_NO END
	    	) AS DOC_NO,
	    trim(pp.ENG_SURNAME||' '||pp.ENG_GIVENAME) as ENG_NAME,
	    pp.NAME_CHI AS CHI_NAME,
	    aa.SCH_ID,
	    aa.GRADE||' / '||aa.CLASS AS GRADE_CLASS,
	    trim(h.DIALING_CD||h.AREA_CD||h.PHONE_NO) as HOME_TEL,
		trim(c.DIALING_CD||c.AREA_CD||c.PHONE_NO) as CONT_TEL,
		aa.VISIT_POINT_DESCRIPTION
	FROM appt_list_base aa
	INNER JOIN PMI_PATIENT pp ON aa.PATIENT_KEY = pp.PATIENT_KEY
	LEFT JOIN PMI_PATIENT_DOCUMENT_PAIR ppdp ON ppdp.PATIENT_KEY = pp.PATIENT_KEY AND ppdp.IS_PRIMARY = 1
	LEFT JOIN COD_DOC_TYPE d on ppdp.DOC_TYPE_CD = d.TYPE_CD
	LEFT JOIN home_tel h on aa.PATIENT_KEY = h.PATIENT_KEY
	LEFT JOIN cont_tel c on aa.PATIENT_KEY = c.PATIENT_KEY
	WHERE aa.RN = 1 
	AND (aa.VISIT_POINT_CD IS NULL OR aa.VISIT_POINT_CD < '5' OR aa.VISIT_POINT_CD > '5')
	AND NVL(pp.IS_MOCK_UP, 0) = 0
) t ON t.ENCNTR_TYPE_ID = cet.ENCNTR_TYPE_ID
ORDER BY cet.ENCNTR_TYPE_DESC, t.APPT_DATE, t.DOC_NO;