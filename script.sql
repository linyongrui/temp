-------------------------------------------------------------------------------------------------------------------
-- CIMST-32363: (StdHS) RPT STH-R049 SHSC Appointment for Doctor By Centre & Session Report
-------------------------------------------------------------------------------------------------------------------
-- @DELIMITER ~
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
    select APPT_ID,TRUNC(APPT_DATE) as appt_date,site_ID
    from ANA_APPT
    WHERE site_ID in (select site_id from STH_CLINICS)
    AND APPT_TYPE_CD <> 'D'
    AND APPT_DATE >= TO_DATE(i_startDate, 'yyyy-MM-dd') 
    AND APPT_DATE < TO_DATE(i_endDate, 'yyyy-MM-dd')+1
),
appt_count_by_sess_id as (
    select APPT_DATE,sess_id,site_id,ENCNTR_TYPE_ID,rm_id,count(appt_id) as APPT_COUNT
    from(
        select  aa.*,aad.sess_id,aad.ENCNTR_TYPE_ID,aad.rm_id
        from appt_by_date_rang aa
        INNER JOIN ANA_APPT_DETL aad ON aa.APPT_ID = aad.APPT_ID and aad.IS_OBS = 0
    )
    group by APPT_DATE,sess_id,site_id,ENCNTR_TYPE_ID,rm_id
),
appt_match as (
    select c.appt_date,sess.sess_desc,s.site_cd,c.appt_count
    from appt_count_by_sess_id c
    inner join SHSC_ENCNTR_TYPE_IDS e on e.ENCNTR_TYPE_ID=c.ENCNTR_TYPE_ID
    inner join SHSC_RM_IDS r on r.rm_id=c.rm_id
    INNER JOIN CLN_SESS sess ON sess.sess_id = c.sess_id
    INNER JOIN STH_CLINICS s ON s.site_id = c.site_id
),
header as (
    select appt_date,sess_desc,c.site_cd, null as appt_count
    from STH_CLINICS c
    inner join(
        select appt_date,sess_desc from(
            (select appt_date,sess_desc
                from appt_match
                order by appt_date,sess_desc
                fetch first 1 rows only)
            union
            select null as appt_date,null as sess_desc
            from dual
        ) order by appt_date nulls last
        fetch first 1 rows only
    ) on 1=1
),
appt_count_by_sess_desc as (
    select APPT_DATE,SESS_DESC,SITE_CD,sum(appt_count) as appt_count
    from(
        select * from appt_match
        union all
        select * from header
    )
    group by APPT_DATE,sess_desc,site_cd
)
select to_char(APPT_DATE,'dd-Mon-RR','NLS_DATE_LANGUAGE=AMERICAN') AS APPT_DATE_STR,
    sess_desc,site_cd,appt_count
from appt_count_by_sess_desc
order by appt_date,sess_desc,site_cd;
END;
~
-- @DELIMITER ;

-- //@UNDO
DROP PROCEDURE RPT_STH_R049_PROC;