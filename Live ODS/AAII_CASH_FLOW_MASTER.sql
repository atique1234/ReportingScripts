USE [REZAKWB01]
GO

/****** Object:  StoredProcedure [dbo].[AAII_CASH_FLOW_MASTER]    Script Date: 10/22/2015 12:23:33 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO












--ALTER PROCEDURE [dbo].[AAII_CASH_FLOW_MASTER]
--AS

DECLARE @startDateUTC   datetime,
		@endDateUTC		datetime,
		@MYDateUTC		datetime,
		@timeZone		varchar(4),
	    @isMorning		varchar(4)

SET @timeZone = GETDATE()
select @MYDateUTC  = ods.ConvertDate( 'MY', GETDATE(),0,0)
SET @startDateUTC = ods.ConvertDate( @timeZone, CAST(CONVERT(VARCHAR,@MYDateUTC-1, 101) AS DateTime) , 1, 0 )
SET @endDateUTC   = ods.ConvertDate( @timeZone,CAST(CONVERT(VARCHAR, DATEADD(day, 1, @MYDateUTC-1), 101) AS DateTime) , 1, 0 )
SET @startDateUTC = DATEADD(month, DATEDIFF(month, 0, @startDateUTC), 0)	
Set @isMorning = 'Y'

if datepart(hour,@MYDateUTC) > 10 
Begin
	SET @startDateUTC = ods.ConvertDate( @timeZone, CAST(CONVERT(VARCHAR,@MYDateUTC, 101) AS DateTime) , 1, 0 )
	SET @endDateUTC   = ods.ConvertDate( @timeZone,CAST(CONVERT(VARCHAR, DATEADD(day, 1, @MYDateUTC), 101) AS DateTime) , 1, 0 )
	SET @startDateUTC = DATEADD(month, DATEDIFF(month, 0, @startDateUTC), 0)	
	Set @isMorning = 'N'
end 
	  
print @MYDateUTC 
print @startDateUTC
print @endDateUTC



BEGIN TRY DROP TABLE #PASSENGERS END TRY BEGIN CATCH END CATCH

SELECT BK.BOOKINGID,BK.BOOKINGDATE,BK.STATUS,
BP.PASSENGERID,
PJS.SEGMENTID,PJS.JOURNEYNUMBER,PJS.SEGMENTNUMBER,PJS.FAREJOURNEYTYPE,
PJL.INVENTORYLEGID,
isnull(carr_map.mappedcarrier ,IL.CARRIERCODE) CARRIERCODE,IL.DEPARTUREDATE,
(CASE WHEN isnull(carr_map.mappedcarrier ,IL.CARRIERCODE) IN ('AK','D7') THEN 'MYR' 
	  WHEN isnull(carr_map.mappedcarrier ,IL.CARRIERCODE) IN ('FD','XJ') THEN 'THB'
	  WHEN isnull(carr_map.mappedcarrier ,IL.CARRIERCODE) = 'QZ' THEN 'IDR'
	  WHEN isnull(carr_map.mappedcarrier ,IL.CARRIERCODE) IN ('PQ','Z2') THEN 'PHP'
	  WHEN isnull(carr_map.mappedcarrier ,IL.CARRIERCODE)  = 'XT' THEN 'USD'
	  WHEN isnull(carr_map.mappedcarrier ,IL.CARRIERCODE) = 'I5' THEN 'INR'
	  ELSE 'MYR' END) LOCAL_CURRENCYCODE,
(
case when IL.CARRIERCODE+ltrim(rtrim(IL.FlightNumber)) in ('D7170','D7171','D7172','D7173','D7176','D7177', 'D7192','D7193','D7196','D7197', 'AK70','AK71') 
			then 'Y' else 'N' end
) IS_CHARTERED

INTO #PASSENGERS
FROM
(SELECT * FROM ODS.BOOKING
WHERE BOOKINGDATE >= @startDateUTC AND BOOKINGDATE < @endDateUTC AND STATUS IN (1,2,3)) BK
--WHERE BOOKINGDATE >= '2015-10-12' AND BOOKINGDATE < '2015-10-13' AND STATUS IN (1,2,3)) BK
JOIN
ODS.BOOKINGPASSENGER BP
ON
BK.BOOKINGID = BP.BOOKINGID
JOIN
ODS.PASSENGERJOURNEYSEGMENT PJS
ON
BP.PASSENGERID = PJS.PASSENGERID
JOIN
ODS.PASSENGERJOURNEYLEG PJL
ON
PJS.PASSENGERID = PJL.PASSENGERID
AND
PJS.SEGMENTID = PJL.SEGMENTID
JOIN
ODS.INVENTORYLEG IL
ON
PJL.INVENTORYLEGID = IL.INVENTORYLEGID
AND IL.CARRIERCODE <> 'BF'
AND IL.STATUS <> 2
AND IL.LID > 0
LEFT JOIN 
AAII_CARRIER_MAPPING carr_map
on carr_map.carriercode = il.carriercode
and ltrim(RTRIM(carr_map.flightnumber)) = ltrim(RTRIM(il.flightnumber))


BEGIN TRY DROP TABLE #PAX END TRY BEGIN CATCH END CATCH

SELECT CONVERT (DATE, BOOKINGDATE, 110) BOOKINGDATE, CARRIERCODE, IS_CHARTERED,STATUS,
COUNT (DISTINCT SEGMENTID) PAX
INTO #PAX
FROM #PASSENGERS
GROUP BY
CONVERT (DATE, BOOKINGDATE, 110), CARRIERCODE,IS_CHARTERED, STATUS



--SELECT TOP 100 * FROM #PASSENGERS

--SELECT TOP 100 * FROM #PJCR
--SELECT COUNT(DISTINCT SEGMENTID) FROM #PJCREVENUE
--SELECT TOP 100 * FROM ODS.Booking


BEGIN TRY DROP TABLE #PJCREVENUE END TRY BEGIN CATCH END CATCH

SELECT P.*,PJC.CurrencyCode,PJC.CREATEDDATE,
SUM(CASE WHEN PJC.CHARGETYPE IN (0,1,7,19)
THEN PJC.CHARGEAMOUNT*CTM.POSITIVENEGATIVEFLAG ELSE 0 END) 
+ SUM(CASE WHEN PJC.CHARGECODE IN ('FUEL','FUEX','DOMS','KLIA2','OTF')
THEN PJC.CHARGEAMOUNT*CTM.POSITIVENEGATIVEFLAG ELSE 0 END) FARE_REVENUE,
--SUM(CASE WHEN PJC.CHARGECODE IN ('APC','APF','OTF','AFX') OR PJC.CHARGETYPE = 8
--THEN PJC.CHARGEAMOUNT*CTM.POSITIVENEGATIVEFLAG ELSE 0 END) ANCILLARY_REVENUE
SUM(CASE WHEN dbo.isAncillaryFee(PJC.CHARGECODE) = 1 OR PJC.CHARGETYPE = 8
THEN PJC.CHARGEAMOUNT*CTM.POSITIVENEGATIVEFLAG ELSE 0 END) ANCILLARY_REVENUE,
-- Tax ---
SUM(CASE WHEN PJC.CHARGECODE IN ('ADF','AIF','APF','APFC','APT','APTF','ASC','ASF','AUDF','AVL','CUTE','DPSC','IPSC','IWJR','PSC','PSF','SCF','SVT','UDF','GST','VAT')
THEN PJC.CHARGEAMOUNT*CTM.POSITIVENEGATIVEFLAG ELSE 0 END) TAX
INTO #PJCREVENUE 
FROM
#PASSENGERS P
JOIN
ODS.PASSENGERJOURNEYCHARGE PJC
ON
P.PASSENGERID = PJC.PASSENGERID
AND
P.SEGMENTID = PJC.SEGMENTID
JOIN
DW.CHARGETYPEMATRIX CTM
ON
PJC.CHARGETYPE = CTM.CHARGETYPEID
GROUP BY
P.BOOKINGID,P.BOOKINGDATE,P.STATUS,P.PASSENGERID,P.SEGMENTID,P.JOURNEYNUMBER,P.SEGMENTNUMBER,P.FAREJOURNEYTYPE,P.INVENTORYLEGID,P.CarrierCode,P.DepartureDate,P.LOCAL_CURRENCYCODE,P.IS_CHARTERED,
PJC.CURRENCYCODE,PJC.CREATEDDATE

BEGIN TRY DROP TABLE #PJCR END TRY BEGIN CATCH END CATCH

SELECT  CONVERT(DATE,PJR.BOOKINGDATE,110) BOOKINGDATE,PJR.CARRIERCODE,PJR.IS_CHARTERED,PJR.STATUS, PJR.CURRENCYCODE,
SUM((CASE WHEN PJR.CURRENCYCODE = PJR.LOCAL_CURRENCYCODE then PJR.FARE_REVENUE else PJR.FARE_REVENUE*(1/CC.CONVERSIONRATE)end)) FARE_REVENUE,
SUM((CASE WHEN PJR.CURRENCYCODE = PJR.LOCAL_CURRENCYCODE then PJR.ANCILLARY_REVENUE else PJR.ANCILLARY_REVENUE*(1/CC.CONVERSIONRATE)end)) ANCILLARY_REVENUE,
--SUM(PJR.ANCILLARY_REVENUE*(1/CC.CONVERSIONRATE)) ANCILLARY_REVENUE
SUM((CASE WHEN PJR.CURRENCYCODE = PJR.LOCAL_CURRENCYCODE then PJR.TAX else PJR.TAX*(1/CC.CONVERSIONRATE)end)) TAX
INTO #PJCR
FROM
#PJCREVENUE PJR
LEFT JOIN
DW.CURRENCYCONVERSIONHISTORYDECOMPRESSED CC
ON
CONVERT(DATE,PJR.CREATEDDATE,110) = CONVERT(DATE,CC.CONVERSIONDATE,110)
AND
PJR.CURRENCYCODE = CC.TOCURRENCYCODE
AND
PJR.LOCAL_CURRENCYCODE = CC.FROMCURRENCYCODE
GROUP BY CONVERT(DATE,PJR.BOOKINGDATE,110),PJR.CARRIERCODE,PJR.IS_CHARTERED,PJR.STATUS,PJR.CURRENCYCODE


BEGIN TRY DROP TABLE #PFCREVENUE1 END TRY BEGIN CATCH END CATCH

SELECT P.*,PFC.CURRENCYCODE,PFC.CREATEDDATE,
0 FARE_REVENUE,
--SUM(PFC.CHARGEAMOUNT*CTM.POSITIVENEGATIVEFLAG) ANCILLARY_REVENUE
--dbo.isAncillaryFee('ABP15')
SUM(case when dbo.isAncillaryFee(PFC.CHARGECODE) = 1 then PFC.CHARGEAMOUNT*CTM.POSITIVENEGATIVEFLAG end) ANCILLARY_REVENUE,
-- Tax ---
SUM(CASE WHEN PFC.CHARGETYPE = 5 THEN PFC.CHARGEAMOUNT*CTM.POSITIVENEGATIVEFLAG ELSE 0 END) TAX
INTO #PFCREVENUE1
FROM
#PASSENGERS P
LEFT JOIN
ODS.PASSENGERFEE PF
ON
P.PASSENGERID = PF.PASSENGERID
AND
P.INVENTORYLEGID = PF.INVENTORYLEGID
AND
PF.INVENTORYLEGID <> '0'
JOIN
ODS.PASSENGERFEECHARGE PFC
ON
PF.PASSENGERID = PFC.PASSENGERID
AND
PF.FEECODE = PFC.CHARGECODE
AND
PF.FEENUMBER = PFC.FEENUMBER
JOIN
DW.CHARGETYPEMATRIX CTM
ON
PFC.CHARGETYPE = CTM.CHARGETYPEID
GROUP BY
P.BOOKINGID,P.BOOKINGDATE,P.STATUS,P.PASSENGERID,P.SEGMENTID,P.JOURNEYNUMBER,P.SEGMENTNUMBER,P.FAREJOURNEYTYPE,P.INVENTORYLEGID,P.CarrierCode,P.DepartureDate,P.LOCAL_CURRENCYCODE,P.IS_CHARTERED,
PFC.CURRENCYCODE,PFC.CREATEDDATE


--SELECT * FROM #PFCREVENUE1

BEGIN TRY DROP TABLE #PFCR1 END TRY BEGIN CATCH END CATCH

SELECT  CONVERT(DATE,PFR1.BOOKINGDATE,110) BOOKINGDATE,PFR1.CARRIERCODE,PFR1.IS_CHARTERED,PFR1.STATUS,PFR1.CURRENCYCODE,
SUM((CASE WHEN PFR1.CURRENCYCODE = PFR1.LOCAL_CURRENCYCODE then PFR1.FARE_REVENUE else PFR1.FARE_REVENUE*(1/CC.CONVERSIONRATE)end)) FARE_REVENUE,
SUM((CASE WHEN PFR1.CURRENCYCODE = PFR1.LOCAL_CURRENCYCODE then PFR1.ANCILLARY_REVENUE else PFR1.ANCILLARY_REVENUE*(1/CC.CONVERSIONRATE)end)) ANCILLARY_REVENUE,
SUM((CASE WHEN PFR1.CURRENCYCODE = PFR1.LOCAL_CURRENCYCODE then PFR1.TAX else PFR1.TAX*(1/CC.CONVERSIONRATE)end)) TAX
INTO #PFCR1
FROM
#PFCREVENUE1 PFR1
LEFT JOIN
DW.CURRENCYCONVERSIONHISTORYDECOMPRESSED CC
ON
CONVERT(DATE,PFR1.CREATEDDATE,110) = CONVERT(DATE,CC.CONVERSIONDATE,110)
AND
PFR1.CURRENCYCODE = CC.TOCURRENCYCODE
AND
PFR1.LOCAL_CURRENCYCODE = CC.FROMCURRENCYCODE
GROUP BY CONVERT(DATE,PFR1.BOOKINGDATE,110),PFR1.CARRIERCODE,PFR1.IS_CHARTERED,PFR1.STATUS,PFR1.CURRENCYCODE

BEGIN TRY DROP TABLE #PFCREVENUE2 END TRY BEGIN CATCH END CATCH

SELECT P.*,PFC.CURRENCYCODE,PFC.CREATEDDATE,
0 FARE_REVENUE,
--SUM(PFC.CHARGEAMOUNT*CTM.POSITIVENEGATIVEFLAG) ANCILLARY_REVENUE
SUM(case when dbo.isAncillaryFee(PFC.CHARGECODE) = 1 then PFC.CHARGEAMOUNT*CTM.POSITIVENEGATIVEFLAG end) ANCILLARY_REVENUE,
-- Tax ---
SUM(CASE WHEN PFC.CHARGETYPE = 5 THEN PFC.CHARGEAMOUNT*CTM.POSITIVENEGATIVEFLAG ELSE 0 END) TAX
INTO #PFCREVENUE2
FROM
#PASSENGERS P
JOIN
ODS.PASSENGERFEE PF
ON
P.PASSENGERID = PF.PASSENGERID
AND
PF.INVENTORYLEGID = '0'
AND
P.JOURNEYNUMBER = 1 AND P.SEGMENTNUMBER = 1
JOIN
ODS.PASSENGERFEECHARGE PFC
ON
PF.PASSENGERID = PFC.PASSENGERID
AND
PF.FEECODE = PFC.CHARGECODE
AND
PF.FEENUMBER = PFC.FEENUMBER
JOIN
DW.CHARGETYPEMATRIX CTM
ON
PFC.CHARGETYPE = CTM.CHARGETYPEID
GROUP BY
P.BOOKINGID,P.BOOKINGDATE,P.STATUS,P.PASSENGERID,P.SEGMENTID,P.JOURNEYNUMBER,P.SEGMENTNUMBER,P.FAREJOURNEYTYPE,P.INVENTORYLEGID,P.CarrierCode,P.DepartureDate,P.LOCAL_CURRENCYCODE,P.IS_CHARTERED,
PFC.CURRENCYCODE,PFC.CREATEDDATE


BEGIN TRY DROP TABLE #PFCR2 END TRY BEGIN CATCH END CATCH

SELECT  CONVERT(DATE,PFR2.BOOKINGDATE,110) BOOKINGDATE,PFR2.CARRIERCODE,PFR2.IS_CHARTERED,PFR2.STATUS,PFR2.CURRENCYCODE,
SUM((CASE WHEN PFR2.CURRENCYCODE = PFR2.LOCAL_CURRENCYCODE then PFR2.FARE_REVENUE else PFR2.FARE_REVENUE*(1/CC.CONVERSIONRATE)end)) FARE_REVENUE,
SUM((CASE WHEN PFR2.CURRENCYCODE = PFR2.LOCAL_CURRENCYCODE then PFR2.ANCILLARY_REVENUE else PFR2.ANCILLARY_REVENUE*(1/CC.CONVERSIONRATE)end)) ANCILLARY_REVENUE,
SUM((CASE WHEN PFR2.CURRENCYCODE = PFR2.LOCAL_CURRENCYCODE then PFR2.TAX else PFR2.TAX*(1/CC.CONVERSIONRATE)end)) TAX
INTO #PFCR2
FROM
#PFCREVENUE2 PFR2
LEFT JOIN
DW.CURRENCYCONVERSIONHISTORYDECOMPRESSED CC
ON
CONVERT(DATE,PFR2.CREATEDDATE,110) = CONVERT(DATE,CC.CONVERSIONDATE,110)
AND
PFR2.CURRENCYCODE = CC.TOCURRENCYCODE
AND
PFR2.LOCAL_CURRENCYCODE = CC.FROMCURRENCYCODE
GROUP BY CONVERT(DATE,PFR2.BOOKINGDATE,110),PFR2.CARRIERCODE,PFR2.IS_CHARTERED,PFR2.STATUS,PFR2.CURRENCYCODE



BEGIN TRY DROP TABLE [REZAKWB01].[DBO].[TEMP_CASH_SALES_REPORT] END TRY BEGIN CATCH END CATCH

SELECT X.*, P.PAX,@isMorning IS_MORNING 
INTO [REZAKWB01].[DBO].[TEMP_CASH_SALES_REPORT]
FROM
(SELECT * FROM #PJCR
UNION
SELECT * FROM #PFCR1
UNION
SELECT * FROM #PFCR2)X
LEFT JOIN
#PAX P
ON X.BOOKINGDATE = P.BOOKINGDATE AND
X.CARRIERCODE = P.CARRIERCODE AND
X.STATUS = P.STATUS And
x.IS_CHARTERED = P.IS_CHARTERED

--SELECT * FROM [REZAKWB01].[DBO].[TEMP_CASH_SALES_REPORT]











GO


