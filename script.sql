SELECT DISTINCT
    appt.*
FROM
         cims.ana_appt appt
    INNER JOIN cims.ana_appt_detl apptdetl ON apptdetl.appt_id = appt.appt_id
    INNER JOIN cims.cmn_site      cmn_site ON cmn_site.site_id = appt.site_id
WHERE
    appt.site_id IN ( '251' )
    AND ( NOT appt.appt_type_cd = 'D' )
    AND ( apptdetl.is_obs = '0' )
    AND apptdetl.encntr_type_id = '2001'
--    AND apptdetl.encntr_type_id = '110001'
    AND ( appt.appt_date >= TO_DATE('2014-07-13', 'yyyy-MM-dd') )
    AND ( appt.appt_date <= TO_DATE('2024-07-13', 'yyyy-MM-dd') + ( 86399 / 86400 ) )
    AND ( NULL IS NULL
          OR appt.appt_type_cd = NULL )
    AND ( 'ANT' IS NULL
          OR cmn_site.svc_cd = 'ANT' )
ORDER BY
    appt.appt_date ASC