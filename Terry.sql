create or replace PROCEDURE "RPT_STH_R031_PROC" (
    i_start_date IN VARCHAR2,
    i_end_date IN VARCHAR2,
	o_ret_val IN OUT SYS_REFCURSOR
) AS
BEGIN
OPEN o_ret_val FOR
WITH year_month_12 AS (
	SELECT ADD_MONTHS(TO_DATE(i_start_date,'YYYY-MM'),Rownum -1) as year_month
    FROM dual
	CONNECT BY Rownum <= 12
),
year_month_search AS (
	SELECT ADD_MONTHS(TO_DATE(i_start_date,'YYYY-MM'),Rownum -1) as year_month
    FROM dual
	CONNECT BY Rownum <= (SELECT MONTHS_BETWEEN(to_date(i_end_date,'YYYY-MM'), to_date(i_start_date,'YYYY-MM')) FROM dual)+1
),
activation_count_list as (
    select TRUNC(acct_efft_dtm, 'MM') as activation_month,count(ONLINE_BOOKING_USER_ID) as activation_count
    from UAM_ONLINE_BOOKING_USER
    where acct_efft_dtm is not null
    AND acct_efft_dtm >= TO_DATE(i_start_date,'YYYY-MM')
    AND acct_efft_dtm < add_months(TO_DATE(i_end_date,'YYYY-MM'), 1)
    group by TRUNC(acct_efft_dtm, 'MM')
),
encntr_by_date as (
    select TRUNC(sdt, 'MM') as sdt_month,ENCNTR_ID
    from CLC_ENCNTR
    where (IS_CANCEL is null or IS_CANCEL=0)
    AND ENCNTR_STS <> 'D'
    AND sdt >= TO_DATE(i_start_date,'YYYY-MM')
    AND sdt < add_months(TO_DATE(i_end_date,'YYYY-MM'), 1)
    AND site_id in(
        select site_id
        from cmn_site
        where svc_cd='STH'
        and is_mock_up=0
    )
),
attend_count_list as (
    select sdt_month,count(ENCNTR_ID) as attend_count
    from(
        select ce.* from encntr_by_date ce
        INNER JOIN STH_S_WAITING_QUEUE q ON q.ENCNTR_ID = ce.ENCNTR_ID and VISIT_POINT_CD='5' and q.is_del=0
    )group by sdt_month
),
percentage_list as (
    select year_month,
        case when nvl(atte.attend_count,0)=0 then 'N/A'
        when nvl(acti.activation_count,0)=0 then '0'
        else trim(to_char(acti.activation_count/atte.attend_count, '9999990.9')||'%') end as percentage
    from year_month_search ym
    left join activation_count_list acti on ym.year_month=acti.activation_month
    left join attend_count_list atte on ym.year_month=atte.sdt_month
),
all_list as (
    select yms.year_month,
        'No. of Attendance' as count_desc,
        1 AS order_seq,
        to_char(nvl(atte.attend_count,0)) as count_num
    from year_month_search yms
    left join attend_count_list atte on yms.year_month=atte.sdt_month
    union all
    select yms.year_month,
        'No. of Activation' as count_desc,
        2 AS order_seq,
        to_char(nvl(acti.activation_count,0)) as count_num
    from year_month_search yms
    left join activation_count_list acti on yms.year_month=acti.activation_month
    union all
    select year_month,
        '(Total no. of Activation / No. of Attendance) x 100%' as count_desc,
        3 AS order_seq,
        percentage as count_num
    from percentage_list
)
select count_desc,TO_CHAR(year_month,'Mon RR','NLS_DATE_LANGUAGE=AMERICAN') as year_month_str,count_num
from all_list
order by order_seq,year_month
;
END;




create or replace PROCEDURE "RPT_STH_R031_CHART_PROC" (
    i_start_date IN VARCHAR2,
    i_end_date IN VARCHAR2,
	o_ret_val IN OUT SYS_REFCURSOR
) AS
BEGIN
OPEN o_ret_val FOR
WITH year_month_12 AS (
	SELECT ADD_MONTHS(TO_DATE(i_start_date,'YYYY-MM'),Rownum -1) as year_month
    FROM dual
	CONNECT BY Rownum <= 12
),
year_month_search AS (
	SELECT ADD_MONTHS(TO_DATE(i_start_date,'YYYY-MM'),Rownum -1) as year_month
    FROM dual
	CONNECT BY Rownum <= (SELECT MONTHS_BETWEEN(to_date(i_end_date,'YYYY-MM'), to_date(i_start_date,'YYYY-MM')) FROM dual)+1
),
activation_count_list as (
    select TRUNC(acct_efft_dtm, 'MM') as activation_month,count(ONLINE_BOOKING_USER_ID) as activation_count
    from UAM_ONLINE_BOOKING_USER
    where acct_efft_dtm is not null
    AND acct_efft_dtm >= TO_DATE(i_start_date,'YYYY-MM')
    AND acct_efft_dtm < add_months(TO_DATE(i_end_date,'YYYY-MM'), 1)
    group by TRUNC(acct_efft_dtm, 'MM')
),
encntr_by_date as (
    select TRUNC(sdt, 'MM') as sdt_month,ENCNTR_ID
    from CLC_ENCNTR
    where (IS_CANCEL is null or IS_CANCEL=0)
    AND ENCNTR_STS <> 'D'
    AND sdt >= TO_DATE(i_start_date,'YYYY-MM')
    AND sdt < add_months(TO_DATE(i_end_date,'YYYY-MM'), 1)
    AND site_id in(
        select site_id
        from cmn_site
        where svc_cd='STH'
        and is_mock_up=0
    )
),
attend_count_list as (
    select sdt_month,count(ENCNTR_ID) as attend_count
    from(
        select ce.* from encntr_by_date ce
        INNER JOIN STH_S_WAITING_QUEUE q ON q.ENCNTR_ID = ce.ENCNTR_ID and VISIT_POINT_CD='5' and q.is_del=0
    )group by sdt_month
),
count_list as (
    select year_month,
        nvl(atte.attend_count,0) as attend_count,
        nvl(acti.activation_count,0) as activation_count
    from year_month_search ym
    left join activation_count_list acti on ym.year_month=acti.activation_month
    left join attend_count_list atte on ym.year_month=atte.sdt_month
)
select TO_CHAR(year_month,'Mon RR','NLS_DATE_LANGUAGE=AMERICAN') as year_month_str,attend_count,activation_count,rownum*10 as horizontal_axis  from (
    select ym.year_month,attend_count,activation_count
    from year_month_12 ym
    left join count_list cl on cl.year_month=ym.year_month
    order by ym.year_month
)
;
END;

