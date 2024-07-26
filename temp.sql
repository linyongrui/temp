create or replace PROCEDURE      "RPT_STH_R030_PROC" (
    i_siteId IN VARCHAR2,
    i_start_date IN VARCHAR2,
    i_end_date IN VARCHAR2,
	o_ret_val IN OUT SYS_REFCURSOR
) AS
BEGIN
OPEN o_ret_val FOR
WITH MONTH_YEAR AS (
	SELECT TO_CHAR(ADD_MONTHS(TO_DATE(i_start_date,'YYYY-MM'),Rownum -1),'MM/YY') AS month_year FROM dual
	CONNECT BY Rownum <= (SELECT MONTHS_BETWEEN(to_date(i_end_date,'YYYY-MM'), to_date(i_start_date,'YYYY-MM')) FROM dual)
)
,STH_CLINIC AS (
	SELECT SITE_ID FROM CMN_SITE cs WHERE cs.SVC_CD ='STH' AND nvl(cs.IS_MOCK_UP,0) = 0
)
,SHSC_AA_ENCNTRTYPE_IDS AS (
	SELECT cet.ENCNTR_TYPE_ID FROM CLN_ENCNTR_TYPE cet 
	INNER JOIN STH_CLINIC c ON c.SITE_ID = cet.SITE_ID 
	WHERE cet.SVC_CD ='STH' AND cet.ENCNTR_TYPE_CD ='SHSC-AA' 
	AND (cet.SITE_ID IS NULL OR cet.SITE_ID = DECODE(i_siteId,'-',cet.SITE_ID,i_siteId))
)
,SHSC_AA_APPT_IDS AS (
	SELECT DISTINCT aa.APPT_ID FROM ANA_APPT aa 
	INNER JOIN ANA_APPT_DETL aad ON aad.APPT_ID = aa.APPT_ID AND aad.ENCNTR_TYPE_ID IN (SELECT * FROM SHSC_AA_ENCNTRTYPE_IDS)
	INNER JOIN STH_CLINIC c ON c.SITE_ID = aa.SITE_ID 
	WHERE aa.SITE_ID = DECODE(i_siteId,'-',aa.SITE_ID,i_siteId)
)
, apptCounts AS  (
	SELECT 
	to_char(ala.APPT_DATE,'MM/YY') AS month_year, count(APPT_ID) AS changeCounts
	FROM ANA_LOG_APPT ala 
	WHERE 
    ala.APPT_DATE >= to_date(i_start_date,'YYYY-MM') 
    AND ala.APPT_DATE < to_date(i_end_date,'YYYY-MM')
	AND APPT_ID IN (SELECT APPT_ID FROM SHSC_AA_APPT_IDS)
	AND ala.APPT_TYPE_CD = 'R'
	GROUP BY to_char(ala.APPT_DATE,'MM/YY')
)
SELECT my.month_year, nvl(c.changeCounts,0) AS change_counts FROM MONTH_YEAR my
LEFT JOIN apptCounts c ON my.month_year = c.month_year
ORDER BY my.month_year;
END;