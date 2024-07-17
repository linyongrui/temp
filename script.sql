
WITH SHSC_ENCNTR_TYPE_IDS AS (
	SELECT distinct ENCNTR_TYPE_ID 
    FROM CLN_ENCNTR_TYPE 
    WHERE SVC_CD = 'STH' 
    AND ENCNTR_TYPE_CD in('SHSC-AA','SHSC-P3','SHSC-SS/SQ')
),
STH_CLINICS AS (
    SELECT SITE_ID, site_cd
    FROM CMN_SITE 
    WHERE SVC_CD = 'STH' 
    AND IS_MOCK_UP = 0
),
SHSC_RM_IDS AS (
	SELECT distinct rm_id
    FROM CLN_RM
    WHERE site_ID in (select site_id from STH_CLINICS)
--    AND (RM_CD = 'MO' or RM_CD = 'MO & Nurse') 
),
appt_by_date_rang as (
    select APPT_ID,TRUNC(APPT_DATE) as appt_date,site_ID 
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
)
select * from (
    select aa.appt_date,aa.appt_count,sess.sess_desc,s.site_cd from(
        select appt_date,sess_id,site_id,count(appt_id) as appt_count 
        from appt_match 
        group by appt_date,sess_id,site_id
    ) aa
    inner join STH_CLINICS s on s.site_id=aa.site_id
    INNER JOIN CLN_SESS sess ON sess.sess_id = aa.sess_id 
)
PIVOT (
    max(appt_count) as appt_count
    for site_cd in(
        'CWNS' as CW,
        'KBYS' as KB,
        'KCYS' as KC,
        'LTNS' as LT,
        'SKCS' as SKC,
        'STIS' as ST1,
        'TPOS' as ST2,
        'SWHS' as SWH,
        'TMNS' as TM,
        'WTNS' as WT,
        'WYYS' as WYY,
        'YLGS' as YL,
        'WKNS' as WK)
)
order by appt_date