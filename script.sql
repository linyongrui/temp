create or replace PROCEDURE RPT_STH_R049_PROC (
    i_startDate IN VARCHAR2,
    i_endDate IN VARCHAR2,
	o_ret_val IN OUT SYS_REFCURSOR
) AS
BEGIN
OPEN o_ret_val FOR
WITH STH_CLINICS AS (
    SELECT SITE_ID, site_cd
    FROM CMN_SITE 
    WHERE SVC_CD = 'STH' 
    AND IS_MOCK_UP = 0
),
SHSC_ENCNTR_TYPE_IDS AS (
	SELECT distinct ENCNTR_TYPE_ID 
    FROM CLN_ENCNTR_TYPE 
    WHERE SVC_CD = 'STH' 
    AND ENCNTR_TYPE_CD in('SHSC-AA','SHSC-P3','SHSC-SS/SQ')
),
SHSC_RM_IDS AS (
	SELECT distinct rm_id
    FROM CLN_RM
    WHERE site_ID in (select site_id from STH_CLINICS)
    AND (RM_CD = 'MO' or RM_CD = 'MO & Nurse') 
),
appt_by_date_rang as (
    select APPT_ID,appt_date,site_ID 
    from ANA_APPT
    WHERE site_ID in (select site_id from STH_CLINICS)
    AND APPT_TYPE_CD <> 'D'
    AND APPT_DATE >= TO_DATE(i_startDate, 'yyyy-MM-dd') 
    AND APPT_DATE < TO_DATE(i_endDate, 'yyyy-MM-dd')+1
),
appt_match as (
    select aa.*,aad.sess_id 
    from appt_by_date_rang aa
    INNER JOIN ANA_APPT_DETL aad ON aa.APPT_ID = aad.APPT_ID 
        AND NVL(aad.IS_OBS,0) = 0 
        and aad.ENCNTR_TYPE_ID in (select ENCNTR_TYPE_ID from SHSC_ENCNTR_TYPE_IDS) 
        and aad.rm_id in (select rm_id from SHSC_RM_IDS) 
),
appt_counter as (
    select APPT_DATE,aa.APPT_COUNT,sess.SESS_DESC,aa.SITE_ID
    from(
        select TRUNC(APPT_DATE) as appt_date,sess_id,site_id,count(appt_id) as APPT_COUNT 
        from appt_match 
        group by TRUNC(APPT_DATE),sess_id,site_id
    ) aa
    INNER JOIN CLN_SESS sess ON sess.sess_id = aa.sess_id 
)
, appt_list as (
    select a.appt_count,header.* from(
        select * from STH_CLINICS
        inner join
        (select appt_date,sess_desc from appt_counter group by appt_date,sess_desc)
        on 1=1
    ) header
    left join appt_counter a
        on header.appt_date=a.appt_date
        and header.sess_desc=a.sess_desc
        and header.site_id=a.site_id
)
select to_char(APPT_DATE,'dd-Mon-RR','NLS_DATE_LANGUAGE=AMERICAN') AS APPT_DATE_STR,
    sess_desc,site_cd,appt_count
from appt_list
order by appt_date,sess_desc,site_cd;
END;

