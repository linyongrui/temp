WITH appt_by_date AS (
    SELECT
        *
    FROM
        ana_appt appt
    WHERE
        appt.site_id IN ( :siteids )
        AND appt.appt_date >= TO_DATE(:startdate, 'yyyy-MM-dd')
        AND appt.appt_date <= TO_DATE(:enddate, 'yyyy-MM-dd') + ( 86399 / 86400 )
), appt_by_filter AS (
    SELECT
        *
    FROM
        appt_by_date appt
    WHERE
        ( :appttypecd IS NULL
          OR appt.appt_type_cd = :appttypecd )
        AND ( NOT appt.appt_type_cd = 'D' )
)
SELECT DISTINCT
    appt.*
FROM
         appt_by_filter appt
    INNER JOIN cims.ana_appt_detl apptdetl ON apptdetl.appt_id = appt.appt_id
    INNER JOIN cims.cmn_site      cmn_site ON cmn_site.site_id = appt.site_id
WHERE
    appt.site_id IN ( :siteids )
    AND ( NOT appt.appt_type_cd = 'D' )
    AND ( apptdetl.is_obs = '0' )
    AND apptdetl.sess_id IN ( :sessids )
    AND ( appt.appt_date >= TO_DATE(:startdate, 'yyyy-MM-dd') )
    AND ( appt.appt_date <= TO_DATE(:enddate, 'yyyy-MM-dd') + ( 86399 / 86400 ) )
    AND ( :appttypecd IS NULL
          OR appt.appt_type_cd = :appttypecd )
    AND ( :servicecd IS NULL
          OR cmn_site.svc_cd = :servicecd )
ORDER BY
    appt.appt_date ASC