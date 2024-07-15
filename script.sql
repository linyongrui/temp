
WITH all_hx AS (
  SELECT * FROM (
    SELECT a.appt_id, a.cntct_time, a.delt_trace_cntct_type_id, a.is_cntct_success, a.repeat_call_date,
      a.rmrk AS remark, b.val_eng AS delt_trace_eng_desc, c.val_eng AS dflt_trace_detl_eng_desc,
      ROW_NUMBER() OVER(PARTITION BY a.appt_id ORDER BY a.cntct_time DESC ) pm
    FROM pmi_dflt_trace_cntct_hx a
    INNER JOIN cod_dflt_trace_cntct_type b ON a.delt_trace_cntct_type_id = b.delt_trace_cntct_type_id
    INNER JOIN cod_dflt_trace_cntct_detl c ON a.dflt_trace_cntct_detl_id = c.dflt_trace_cntct_detl_id
    WHERE a.status = 'A' AND a.svc_cd = :svccd
  ) WHERE pm = 1
 ), date_match_hx AS (
   SELECT appt_id FROM all_hx WHERE trunc(repeat_call_date) BETWEEN TO_DATE(:datefrom, 'YYYY-MM-DD') AND TO_DATE(:dateto, 'YYYY-MM-DD')
 ), data_match_appt_within_date_range AS (
    SELECT a.appt_id,a.appt_date,a.tbc_on_tx,a.is_trace,a.case_no,a.patient_key" );
    FROM ana_appt a 
    WHERE a.site_id = :siteid 
    AND a.appt_date BETWEEN TO_DATE(:datefrom || ' 00:00:00', 'YYYY-MM-DD hh24:mi:ss') AND TO_DATE(:dateto || ' 23:59:59' , 'YYYY-MM-DD hh24:mi:ss')" );
    AND a.appt_type_cd <> 'D'" );
    AND a.appt_date < trunc(sysdate)" );
  ), data_match_appt_hx AS (" );
    SELECT b.appt_id,b.appt_date,b.tbc_on_tx,b.is_trace,b.case_no,b.patient_key " );
    FROM ana_appt b" );
    WHERE b.appt_id IN ( SELECT appt_id FROM date_match_hx)" );
    AND NOT EXISTS (SELECT 1 FROM data_match_appt_within_date_range appts WHERE appts.appt_id = b.appt_id)" );
    AND b.site_id = :siteid" );
    AND b.appt_type_cd <> 'D'" );
    AND b.appt_date < trunc(sysdate)" );
 ),date_match_appt AS (" );
    SELECT DISTINCT aa.appt_id, aa.appt_date, aa.tbc_on_tx, aa.is_trace,aa.case_no, aa.patient_key" );
    FROM" );
  ( SELECT * FROM data_match_appt_within_date_range" );
  UNION ALL" );
  SELECT * FROM data_match_appt_hx" );
  ) aa
 ), date_match_patient_key AS (SELECT DISTINCT patient_key FROM date_match_appt
 ), phn AS (
 SELECT * FROM (
   SELECT k.patient_key,
    nvl(phn.dialing_cd, '') AS dialing_cd,
    nvl(phn.area_cd, '')    AS area_cd,
    nvl(phn.phone_no, '')   AS phone_no,
    ROW_NUMBER()
    OVER(PARTITION BY k.patient_key
    ORDER BY
        nvl(phn.sms_phone_ind, 0) DESC,
        decode(phn.phone_type_cd, 'M', 1, 'H', 2, 'O', 3, phn.patient_phone_id)
    ) AS rn
   FROM date_match_patient_key k
   INNER JOIN pmi_patient_phone phn ON k.patient_key = phn.patient_key
   WHERE phn.phone_type_cd IN ( 'M', 'H', 'O' ))
 WHERE rn = 1
 )
 SELECT * FROM (
   SELECT appt_info.tbc_on_tx AS tx, appt_info.appt_id, appt_info.patient_key, appt_info.case_no, appt_info.id_sts,
     appt_info.encntr_grp_cd, appt_info.alias, appt_info.pn_no, appt_info.eng_surname, appt_info.eng_givename,
     TRIM(appt_info.eng_surname || ' ' || appt_info.eng_givename) AS eng_name,
     appt_info.name_chi, phn.dialing_cd, phn.area_cd, phn.phone_no, appt_info.encntr_type_desc, appt_info.appt_date,
     appt_info.previous_attn_date, appt_info.attendance_after_default AS attn_after_default,
     decode(appt_info.previous_attn_date, NULL, NULL, (trunc(appt_info.appt_date) - trunc(appt_info.previous_attn_date))) + 0 AS period,
     CASE WHEN appt_info.appt_date IS NOT NULL AND hx.cntct_time IS NOT NULL THEN hx.cntct_time ELSE NULL END AS cntct_time,
     decode(nvl(appt_info.is_trace, 0), 1, 'Y', 'N') AS defaulter_tracing, appt_info.comm_lang_cd,
     hx.delt_trace_eng_desc, hx.dflt_trace_detl_eng_desc,
     CASE WHEN hx.is_cntct_success = 1 THEN 'Success'
          WHEN hx.is_cntct_success = 0 THEN 'Fail'
          ELSE ' ' END AS is_cntct_success_desc,
     hx.repeat_call_date,
     hx.remark AS remark
    FROM (
        SELECT pp.patient_key, appt.case_no, pp.id_sts, pc.encntr_grp_cd, pc.alias, pp.eng_surname,
            pp.eng_givename, pp.name_chi, cet.encntr_type_desc, appt.appt_id, appt.appt_date, appt.tbc_on_tx, appt.is_trace,
            (CASE WHEN pti.pn_no1 IS NOT NULL AND pti.pn_no2 IS NOT NULL THEN pti.pn_no1 || ' / ' || pti.pn_no2
              ELSE coalesce(pti.pn_no1, pti.pn_no2)
            END) AS pn_no,
            (SELECT appt_date FROM (
                SELECT aa1.appt_date
                FROM ana_appt aa1
                INNER JOIN ana_appt_detl aad ON aad.appt_id = aa1.appt_id AND appt.appt_date >= aa1.appt_date
                INNER JOIN ana_atnd aa2 ON aa2.appt_id = aa1.appt_id AND nvl(aa2.is_cancel, 0) = 0
                WHERE aa1.patient_key = appt.patient_key
                  AND aa1.appt_type_cd <> 'D'
                  AND appt_detl.is_obs = 0
                  AND aad.encntr_type_id = appt_detl.encntr_type_id
                ORDER BY aa1.appt_date DESC
            ) WHERE ROWNUM = 1 ) AS previous_attn_date,
            (SELECT appt_date FROM (
                 SELECT aa1.appt_date FROM ana_appt aa1
                 INNER JOIN ana_appt_detl aad ON aad.appt_id = aa1.appt_id AND appt.appt_date <= aa1.appt_date
                 INNER JOIN ana_atnd aa2 ON aa2.appt_id = aa1.appt_id AND nvl(aa2.is_cancel, 0) = 0
                 WHERE aa1.patient_key = appt.patient_key
                   AND aa1.appt_type_cd <> 'D'
                   AND appt_detl.is_obs = 0
                   AND aad.encntr_type_id = appt_detl.encntr_type_id
                 ORDER BY aa1.appt_date ASC
             ) WHERE ROWNUM = 1 ) AS attendance_after_default,
            (SELECT comm_lang_cd FROM (
                SELECT comm_lang_cd FROM pmi_patient_comm_mean WHERE status = 'A' AND patient_key = appt.patient_key ORDER BY UPDATE_DTM DESC
             ) WHERE ROWNUM = 1) AS comm_lang_cd
        FROM date_match_appt appt
        INNER JOIN ana_appt_detl   appt_detl ON appt_detl.appt_id = appt.appt_id AND nvl(appt_detl.is_obs, 0) = 0
        if (queryDto.getEncntrTypeId() != null) {
            AND appt_detl.encntr_type_id = :encntrtypeid
        }
        INNER JOIN cln_encntr_type cet ON cet.encntr_type_id = appt_detl.encntr_type_id
        INNER JOIN pmi_patient     pp ON pp.patient_key = appt.patient_key
        LEFT JOIN pmi_case        pc ON pc.case_no = appt.case_no
        LEFT JOIN pmi_tbc_info    pti ON pti.patient_key = appt.patient_key
        LEFT JOIN ana_atnd        attn ON attn.appt_id = appt.appt_id AND nvl(attn.is_cancel, 0) = 0
        WHERE nvl(pp.is_mock_up, 0) = 0 AND attn.atnd_id IS NULL
    ) appt_info
    LEFT JOIN phn ON phn.patient_key = appt_info.patient_key
    LEFT JOIN all_hx hx ON hx.appt_id = appt_info.appt_id
 ) WHERE 1 = 1
        if (queryDto.getPeriodFrom() != null) {
        AND period >= :periodfrom
            paramMap.put("periodfrom", queryDto.getPeriodFrom());
        }
        if (queryDto.getPeriodTo() != null) {
        AND :periodto >= period
            paramMap.put("periodto", queryDto.getPeriodTo());
        }
 ORDER BY period, defaulter_tracing DESC NULLS LAST, case_no