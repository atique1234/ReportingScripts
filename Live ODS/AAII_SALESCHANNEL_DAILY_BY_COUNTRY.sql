USE [REZAKWB01]
GO

/****** Object:  StoredProcedure [dbo].[AAII_SALESCHANNEL_DAILY_BY_COUNTRY]    Script Date: 10/26/2015 12:51:55 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO













--ALTER PROCEDURE [dbo].[AAII_SALESCHANNEL_DAILY_BY_COUNTRY]

--AS

BEGIN

DECLARE     @MYDateUTC			 datetime,
			@dateStart           datetime,
			@dateEnd		     datetime,
			@timeZone            varchar(4)
 

	--SET @MYDateUTC ='2011-02-16'
	
	--SET @MYDateUTC  = ods.ConvertDate( 'MY', GETDATE(),0,0)
	----SET @MYDateUTC  = GETDATE()
	-- --SET @departureStart =CAST(CONVERT(VARCHAR, DATEADD(s, 1,DATEADD(mm, DATEDIFF(m,0,DateAdd(month,0,@MYDateUTC)),0)), 101) AS DateTime) 
	--SET @departureStart = CONVERT(DATETIME,datediff(day,0,dateadd(week,-1,@MYDateUTC)))
	--SET @departureEnd   = CONVERT(DATETIME,datediff(day,0,@MYDateUTC))
	
	
	SET @timeZone         = GETDATE()
	--SET @MYDateUTC ='2011-02-16'
	--SET @MYDateUTC      = ods.ConvertDate( 'MY', GETDATE(),0,0)
	--SET @dateStart      = ods.ConvertDate( @timeZone,CAST(CONVERT(VARCHAR, DATEADD(week, -1, @MYDateUTC-1), 101) AS DateTime) , 1, 0 )
	--SET @dateEnd        = ods.ConvertDate( @timeZone, CAST(CONVERT(VARCHAR,@MYDateUTC-1, 101) AS DateTime) , 1, 0 )
	
	SET @MYDateUTC  = GETDATE()
	SET @dateStart = CONVERT(DATETIME,datediff(day,0,dateadd(week,-1,@MYDateUTC)))
	SET @dateEnd   = CONVERT(DATETIME,datediff(day,0,@MYDateUTC))
	--SET @dateStart = '2015-01-01'
	--SET @dateEnd   = CONVERT(DATETIME,datediff(day,0,@MYDateUTC)) 

	print @MYDateUTC 
	print @dateStart
	print @dateEnd






BEGIN TRY DROP TABLE #PASSENGERS END TRY BEGIN CATCH END CATCH



SELECT distinct BK.BOOKINGDATE,BK.BOOKINGID,

BP.PASSENGERID,

PJS.SEGMENTID,PJS.DEPARTUREDATE,PJS.DEPARTURESTATION,PJS.ARRIVALSTATION,

AR.ROLECODE,

IL.CARRIERCODE,IL.Flightnumber,AG.ORGANIZATIONCODE,AG.LOCATIONCODE,

DS.COUNTRYCODE DEPARTURECOUNTRYCODE,

ARS.COUNTRYCODE ARRIVALCOUNTRYCODE,

DC.NAME DEPARTURECOUNTRY,

AC.NAME ARRIVALCOUNTRY,

PJC.CURRENCYCODE,

(CASE WHEN IL.CARRIERCODE IN ('AK','D7') THEN 'MYR'

	  WHEN IL.CARRIERCODE IN ('FD','XJ') THEN 'THB'

	  WHEN IL.CARRIERCODE = 'QZ' THEN 'IDR'

	  WHEN IL.CARRIERCODE = 'XT' THEN 'USD'

	  WHEN IL.CARRIERCODE IN ('PQ','Z2') THEN 'PHP'

	  WHEN IL.CARRIERCODE = 'I5' THEN 'INR'

	  ELSE 'MYR' END) AOCCURRENCY,

SUM(CASE WHEN CHARGETYPE IN (0,1,7,19) THEN PJC.CHARGEAMOUNT*CTM.POSITIVENEGATIVEFLAG ELSE 0 END)
+ SUM(CASE WHEN PJC.CHARGECODE IN ('KLIA2')
THEN PJC.CHARGEAMOUNT*CTM.POSITIVENEGATIVEFLAG ELSE 0 END) FARE_REVENUE,

SUM(CASE WHEN CHARGECODE IN ('FUEL','FUEX','DOMS') THEN PJC.CHARGEAMOUNT*CTM.POSITIVENEGATIVEFLAG ELSE 0 END) FUEL_REV 

INTO #PASSENGERS

FROM

(SELECT * FROM ODS.BOOKING

WHERE 
	BOOKINGDATE >= @dateStart  
	AND BOOKINGDATE < @dateEnd 
	--BOOKINGDATE >= '2015-05-10' 
	--AND BOOKINGDATE < '2015-06-16' 
	AND STATUS IN (2,3)) BK

JOIN

ODS.BOOKINGPASSENGER BP

ON

BK.BOOKINGID = BP.BOOKINGID

JOIN

ODS.PASSENGERJOURNEYSEGMENT PJS

ON

BP.PASSENGERID = PJS.PASSENGERID

JOIN

ODS.AGENTROLE AR

ON

BK.CREATEDAGENTID = AR.AGENTID

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

JOIN

ODS.AGENT AG

ON

BK.CREATEDAGENTID = AG.AGENTID

JOIN

ODS.PASSENGERJOURNEYCHARGE PJC

ON

PJL.PASSENGERID = PJC.PASSENGERID

AND

PJL.SEGMENTID = PJC.SEGMENTID

JOIN

DW.CHARGETYPEMATRIX CTM

ON

PJC.CHARGETYPE = CTM.CHARGETYPEID

JOIN

ODS.STATION DS

ON

PJS.DEPARTURESTATION = DS.StationCode

JOIN

ODS.Station ARS 

ON

PJS.ARRIVALSTATION = ARS.STATIONCODE

JOIN

ODS.COUNTRY DC

ON

DS.COUNTRYCODE = DC.COUNTRYCODE

JOIN

ODS.COUNTRY AC

ON

ARS.COUNTRYCODE = AC.COUNTRYCODE

where (DS.COUNTRYCODE = 'SG' or ARS.COUNTRYCODE = 'SG')
or (DS.COUNTRYCODE = 'PH' or ARS.COUNTRYCODE = 'PH')
or (DS.COUNTRYCODE = 'ID' or ARS.COUNTRYCODE = 'ID')
or (DS.COUNTRYCODE = 'AU' or ARS.COUNTRYCODE = 'AU')


GROUP BY BK.BOOKINGDATE,BK.BOOKINGID,--BK.CREATEDAGENTID,

BP.PASSENGERID,

PJS.SEGMENTID,PJS.DEPARTUREDATE,PJS.DEPARTURESTATION,PJS.ARRIVALSTATION,

AR.ROLECODE,

IL.CARRIERCODE,IL.Flightnumber,AG.ORGANIZATIONCODE,AG.LOCATIONCODE,

--AG.ORGANIZATIONCODE,AG.LOCATIONCODE,

DS.COUNTRYCODE,

ARS.COUNTRYCODE,

DC.NAME,

AC.NAME,

PJC.CURRENCYCODE,

(CASE WHEN IL.CARRIERCODE IN ('AK','D7') THEN 'MYR'

	  WHEN IL.CARRIERCODE IN ('FD','XJ') THEN 'THB'

	  WHEN IL.CARRIERCODE = 'QZ' THEN 'IDR'

	  WHEN IL.CARRIERCODE = 'XT' THEN 'USD'

	  WHEN IL.CARRIERCODE IN ('PQ','Z2') THEN 'PHP'

	  WHEN IL.CARRIERCODE = 'I5' THEN 'INR'

	  ELSE 'MYR' END)










--BEGIN TRY DROP TABLE #PASSENGERALL END TRY BEGIN CATCH END CATCH

--SELECT P.*

--INTO #PASSENGERALL

--FROM

--#PASSENGERS P




--select * from #PASSENGERCHANNEL

BEGIN TRY DROP TABLE #PASSENGERCHANNEL END TRY BEGIN CATCH END CATCH



SELECT P.*,

case when SC.SalesChannelRpt = 'Corporate' and (P.OrganizationCode like '%A%' OR P.OrganizationCode like '%B%' OR P.OrganizationCode like '%C%' OR

		 P.OrganizationCode like '%D%' OR P.OrganizationCode like '%E%' OR P.OrganizationCode like '%F%' OR P.OrganizationCode like '%G%' OR

		 P.OrganizationCode like '%H%' OR P.OrganizationCode like '%I%' OR P.OrganizationCode like '%J%' OR P.OrganizationCode like '%K%' OR

		 P.OrganizationCode like '%L%' OR P.OrganizationCode like '%M%' OR P.OrganizationCode like '%N%' OR P.OrganizationCode like '%O%' OR

		 P.OrganizationCode like '%P%' OR P.OrganizationCode like '%Q%' OR P.OrganizationCode like '%R%' OR P.OrganizationCode like '%S%' OR

		 P.OrganizationCode like '%T%' OR P.OrganizationCode like '%U%' OR P.OrganizationCode like '%V%' OR P.OrganizationCode like '%W%' OR

		 P.OrganizationCode like '%X%' OR P.OrganizationCode like '%Y%' OR P.OrganizationCode like '%Z%') then 'Corporate - Direct'

	 when SC.SalesChannelRpt = 'Corporate' and (P.OrganizationCode not like '%A%' AND P.OrganizationCode not like '%B%' AND P.OrganizationCode not like '%C%' AND

		 P.OrganizationCode not like '%D%' AND P.OrganizationCode not like '%E%' AND P.OrganizationCode not like '%F%' AND P.OrganizationCode not like '%G%' AND

		 P.OrganizationCode not like '%H%' AND P.OrganizationCode not like '%I%' AND P.OrganizationCode not like '%J%' AND P.OrganizationCode not like '%K%' AND

		 P.OrganizationCode not like '%L%' AND P.OrganizationCode not like '%M%' AND P.OrganizationCode not like '%N%' AND P.OrganizationCode not like '%O%' AND

		 P.OrganizationCode not like '%P%' AND P.OrganizationCode not like '%Q%' AND P.OrganizationCode not like '%R%' AND P.OrganizationCode not like '%S%' AND

		 P.OrganizationCode not like '%T%' AND P.OrganizationCode not like '%U%' AND P.OrganizationCode not like '%V%' AND P.OrganizationCode not like '%W%' AND

		 P.OrganizationCode not like '%X%' AND P.OrganizationCode not like '%Y%' AND P.OrganizationCode not like '%Z%') then 'Corporate - TMC'

	 when SalesChannelRpt = 'Corporate' and P.OrganizationCode IS NULL then SalesChannelRpt

	 when SalesChannelRpt = 'Call Centre' and LocationCode in ('KUL','ORY','AUH','ICN','HND','MNL') then 'Call Centre - Scicom'

	 when SalesChannelRpt = 'Call Centre' and LocationCode in ('MAA','DEL') then 'Call Centre - Sutherland'

	 when SalesChannelRpt = 'Call Centre' and LocationCode in ('SZX','CAN') then 'Call Centre - Sonic'

	 when SalesChannelRpt = 'Call Centre' and LocationCode in ('CGK') then 'Call Centre - IAA'

	 when SalesChannelRpt = 'Call Centre' and LocationCode in ('DMK','BKK') then 'Call Centre - TAA'

	 else SalesChannelRpt

end SALESCHANNEL
--,

--SCG.GROUPING,SCG.CATEGORY,SA.ORGANIZATIONNAME,SA.COUNTRYCODE ORGANIZATIONCOUNTRYCODE

INTO #PASSENGERCHANNEL

FROM

(SELECT  * FROM #PASSENGERS) P

LEFT JOIN

SAT_JK_SALESCHANNEL SC

ON

P.ROLECODE = SC.ROLECODE

--LEFT JOIN

--SAT_JK_SALESCHANNEL_GRP SCG

--ON

--SC.SALESCHANNELRPT = SCG.CHANNELBREAKDOWN

--AND

--SCG.CHANNELBREAKDOWN+SCG.CATEGORY <> 'OthersThird Party'

--LEFT JOIN

--REF_SALES_AGENCY_LIST SA

--ON

--P.ORGANIZATIONCODE = SA.ORGANIZATIONCODE








BEGIN TRY DROP TABLE #PASSENGERALLCURRENCY1 END TRY BEGIN CATCH END CATCH





SELECT P.*,

(CASE WHEN P.CURRENCYCODE <> 'MYR' THEN P.FARE_REVENUE*(1/CC.CONVERSIONRATE) ELSE P.FARE_REVENUE END) FARE_REV_MYR,

(CASE WHEN P.CURRENCYCODE <> 'MYR' THEN P.FUEL_REV*(1/CC.CONVERSIONRATE) ELSE P.FUEL_REV END) FUEL_REV_MYR

INTO #PASSENGERALLCURRENCY1

FROM

#PASSENGERCHANNEL P

LEFT JOIN

DW.CURRENCYCONVERSIONHISTORYDECOMPRESSED CC

ON

CONVERT(DATE,CC.CONVERSIONDATE,110) = CONVERT(DATE,P.BOOKINGDATE,110)

AND

CC.FROMCURRENCYCODE = 'MYR'

AND

CC.TOCURRENCYCODE = P.CURRENCYCODE



BEGIN TRY DROP TABLE #PASSENGERALLCURRENCY END TRY BEGIN CATCH END CATCH





SELECT P.*,

(CASE WHEN P.CURRENCYCODE <> P.AOCCURRENCY THEN P.FARE_REVENUE*(1/CCA.CONVERSIONRATE) ELSE P.FARE_REVENUE END) FARE_REV_AOCCURRENCY,

(CASE WHEN P.CURRENCYCODE <> P.AOCCURRENCY THEN P.FUEL_REV*(1/CCA.CONVERSIONRATE) ELSE P.FUEL_REV END) FUEL_REV_AOCCURRENCY

INTO #PASSENGERALLCURRENCY

FROM

#PASSENGERALLCURRENCY1 P

LEFT JOIN

DW.CURRENCYCONVERSIONHISTORYDECOMPRESSED CCA

ON

CONVERT(DATE,CCA.CONVERSIONDATE,110) = CONVERT(DATE,P.BOOKINGDATE,110)

AND

CCA.FROMCURRENCYCODE = P.AOCCURRENCY

AND

CCA.TOCURRENCYCODE = P.CURRENCYCODE





--select * from #PASSENGERALLCURRENCY

--BEGIN TRY DROP TABLE #PASSENGERALLCURRENCY END TRY BEGIN CATCH END CATCH





--SELECT P.*
--INTO #PASSENGERALLCURRENCY

--FROM

--#PASSENGERALLCURRENCY2 P




--select * from TEMP_SALESCHANNEL_DAILY_SG

BEGIN TRY DROP TABLE TEMP_SALESCHANNEL_DAILY_BY_COUNTRY END TRY BEGIN CATCH END CATCH



SELECT DATEPART(YYYY,BOOKINGDATE) BOOKINGYEAR, DATENAME(MM,BOOKINGDATE) BOOKINGMONTH,CONVERT(DATE,BOOKINGDATE,110) BOOKINGDATE,
CARRIERCODE,flightnumber,

(CASE WHEN ASCII(SUBSTRING(DEPARTURESTATION,1,1)) < ASCII(SUBSTRING(ARRIVALSTATION,1,1)) THEN DEPARTURESTATION + ARRIVALSTATION

	  WHEN ASCII(SUBSTRING(DEPARTURESTATION,1,1)) > ASCII(SUBSTRING(ARRIVALSTATION,1,1)) THEN ArrivalStation + DepartureStation

	  ELSE 

		CASE WHEN ASCII(SUBSTRING(DEPARTURESTATION,2,1)) < ASCII(SUBSTRING(ARRIVALSTATION,2,1)) THEN DEPARTURESTATION + ARRIVALSTATION

		WHEN ASCII(SUBSTRING(DEPARTURESTATION,2,1)) > ASCII(SUBSTRING(ARRIVALSTATION,2,1)) THEN ArrivalStation + DepartureStation

		ELSE

			CASE WHEN ASCII(SUBSTRING(DEPARTURESTATION,3,1)) < ASCII(SUBSTRING(ARRIVALSTATION,3,1)) THEN DEPARTURESTATION + ARRIVALSTATION

			WHEN ASCII(SUBSTRING(DEPARTURESTATION,3,1)) > ASCII(SUBSTRING(ARRIVALSTATION,3,1)) THEN ArrivalStation + DepartureStation

			ELSE DEPARTURESTATION+ARRIVALSTATION 

			END

		END

	 END) MARKETGROUP,


SALESCHANNEL,CURRENCYCODE,

DEPARTURECOUNTRYCODE+'-'+ARRIVALCOUNTRYCODE COUNTRYPAIR,


DEPARTURECOUNTRY DEPCOUNTRY,ARRIVALCOUNTRY ARRCOUNTRY,

COUNT(DISTINCT SEGMENTID) SEATSOLD,

SUM(FARE_REVENUE) FARE_REV_BOOKINGCURRENCY,

SUM(FUEL_REV) FUEL_REV_BOOKINGCURRENCY,

SUM(FARE_REV_MYR) FARE_REV_MYR,

SUM(FUEL_REV_MYR) FUEL_REV_MYR,

SUM(FARE_REV_AOCCURRENCY) FARE_REV_AOCCURRENCY,

SUM(FUEL_REV_AOCCURRENCY) FUEL_REV_AOCCURRENCY


 INTO TEMP_SALESCHANNEL_DAILY_BY_COUNTRY

 FROM #PASSENGERALLCURRENCY

 GROUP BY DATEPART(YYYY,BOOKINGDATE), DATENAME(MM,BOOKINGDATE),CONVERT(DATE,BOOKINGDATE,110),CARRIERCODE,flightnumber,

(CASE WHEN ASCII(SUBSTRING(DEPARTURESTATION,1,1)) < ASCII(SUBSTRING(ARRIVALSTATION,1,1)) THEN DEPARTURESTATION + ARRIVALSTATION

	  WHEN ASCII(SUBSTRING(DEPARTURESTATION,1,1)) > ASCII(SUBSTRING(ARRIVALSTATION,1,1)) THEN ArrivalStation + DepartureStation

	  ELSE 

		CASE WHEN ASCII(SUBSTRING(DEPARTURESTATION,2,1)) < ASCII(SUBSTRING(ARRIVALSTATION,2,1)) THEN DEPARTURESTATION + ARRIVALSTATION

		WHEN ASCII(SUBSTRING(DEPARTURESTATION,2,1)) > ASCII(SUBSTRING(ARRIVALSTATION,2,1)) THEN ArrivalStation + DepartureStation

		ELSE

			CASE WHEN ASCII(SUBSTRING(DEPARTURESTATION,3,1)) < ASCII(SUBSTRING(ARRIVALSTATION,3,1)) THEN DEPARTURESTATION + ARRIVALSTATION

			WHEN ASCII(SUBSTRING(DEPARTURESTATION,3,1)) > ASCII(SUBSTRING(ARRIVALSTATION,3,1)) THEN ArrivalStation + DepartureStation

			ELSE DEPARTURESTATION+ARRIVALSTATION 

			END

		END

	 END),

SALESCHANNEL,CURRENCYCODE,

DEPARTURECOUNTRYCODE+'-'+ARRIVALCOUNTRYCODE,


DEPARTURECOUNTRY,ARRIVALCOUNTRY










END













GO


