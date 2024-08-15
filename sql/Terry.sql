SELECT DISTINCT pmi.PATIENT_KEY FROM PMI_PATIENT pmi
WHERE pmi.GENDER_CD = :genderCd AND pmi.DOB = TO_DATE('2018-03-31','yyyy-mm-dd') AND pmi.EXACT_DOB_CD = :exactDobCd 
AND UPPER(pmi.ENG_SURNAME) = :surName
AND UPPER(pmi.ENG_GIVENAME) = :givenName
AND NOT EXISTS (SELECT doc.PATIENT_KEY FROM PMI_PATIENT_DOCUMENT_PAIR doc WHERE doc.IS_PRIMARY = 1 AND doc.PATIENT_KEY = pmi.PATIENT_KEY AND doc.DOC_TYPE_CD = :docTypeCd AND UPPER(doc.DOC_NO) = :docNo )
;

SELECT DISTINCT pmi.PATIENT_KEY FROM PMI_PATIENT pmi
WHERE pmi.GENDER_CD = :genderCd AND pmi.DOB = TO_DATE('2018-03-31','yyyy-mm-dd') AND pmi.EXACT_DOB_CD = :exactDobCd 
AND UPPER(pmi.ENG_SURNAME) = :surName
AND UPPER(pmi.ENG_GIVENAME) = :givenName
--AND UPPER(pmi.ENG_SURNAME||' '||pmi.ENG_GIVENAME) = :surName||' '||:givenName
AND NOT EXISTS (SELECT doc.PATIENT_KEY FROM PMI_PATIENT_DOCUMENT_PAIR doc WHERE doc.IS_PRIMARY = 1 AND doc.PATIENT_KEY = pmi.PATIENT_KEY AND doc.DOC_TYPE_CD = :docTypeCd AND UPPER(doc.DOC_NO) = :docNo )

