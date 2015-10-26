USE [REZAKWB01]
GO

/****** Object:  StoredProcedure [dbo].[AAII_SALESCHANNEL_MONTHLY]    Script Date: 10/26/2015 10:36:52 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO








--ALTER PROCEDURE [dbo].[AAII_SALESCHANNEL_MONTHLY]

--AS



BEGIN


DECLARE     @MYDateUTC			 datetime,
			@dateStart      datetime,
			@dateEnd		 datetime,
			@test				 datetime
 

	--SET @MYDateUTC ='2011-02-16'
	
	--select @MYDateUTC  = ods.ConvertDate( 'MY', GETDATE(),0,0)
	select @MYDateUTC  = GETDATE()
	 --SET @departureStart =CAST(CONVERT(VARCHAR, DATEADD(s, 1,DATEADD(mm, DATEDIFF(m,0,DateAdd(month,0,@MYDateUTC)),0)), 101) AS DateTime) 
	
	SET @dateEnd   = DATEADD(MM,DATEDIFF(MM,0,DATEADD(MM,0,@MYDateUTC)),0)
    SET @dateStart = DATEADD(MONTH,-1,@dateEnd)
	

	print @MYDateUTC 
	print @dateStart
	print @dateEnd


BEGIN TRY DROP TABLE #PASSENGERS END TRY BEGIN CATCH END CATCH



SELECT BK.BOOKINGDATE,BK.BOOKINGID,BK.CREATEDAGENTID,

BP.PASSENGERID,

PJS.SEGMENTID,PJS.DEPARTUREDATE,PJS.DEPARTURESTATION,PJS.ARRIVALSTATION,PJS.JOURNEYNUMBER,PJS.SEGMENTNUMBER,PJS.INTERNATIONAL,

AR.ROLECODE,

IL.CARRIERCODE,

AG.ORGANIZATIONCODE,AG.LOCATIONCODE,

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

WHERE BOOKINGDATE >= @dateStart AND BOOKINGDATE < @dateEnd AND STATUS IN (2,3)) BK

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

AND IL.STATUS <> 2
AND IL.LID > 0

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

GROUP BY BK.BOOKINGDATE,BK.BOOKINGID,BK.CREATEDAGENTID,

BP.PASSENGERID,

PJS.SEGMENTID,PJS.DEPARTUREDATE,PJS.DEPARTURESTATION,PJS.ARRIVALSTATION,PJS.JOURNEYNUMBER,PJS.SEGMENTNUMBER,PJS.INTERNATIONAL,

AR.ROLECODE,

IL.CARRIERCODE,

AG.ORGANIZATIONCODE,AG.LOCATIONCODE,

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







BEGIN TRY DROP TABLE #PASSENGERPOS END TRY BEGIN CATCH END CATCH



SELECT BK.BOOKINGID,

PJS.PASSENGERID,PJS.DEPARTURESTATION,

ST.COUNTRYCODE POSCOUNTRYCODE,

CTY.NAME POSCOUNTRYNAME,CTY.DEFAULTCURRENCYCODE POSCOUNTRYCURRENCY

INTO #PASSENGERPOS

FROM

(SELECT * FROM ODS.BOOKING

WHERE BOOKINGDATE >= @dateStart AND BOOKINGDATE < @dateEnd AND STATUS IN (2,3)) BK

JOIN

ODS.BOOKINGPASSENGER BP

ON

BK.BOOKINGID = BP.BOOKINGID

JOIN

ODS.PASSENGERJOURNEYSEGMENT PJS

ON

BP.PASSENGERID = PJS.PASSENGERID

AND

PJS.JOURNEYNUMBER = 1 AND PJS.SEGMENTNUMBER = 1

JOIN

ODS.STATION ST

ON

PJS.DEPARTURESTATION = ST.STATIONCODE

JOIN

ODS.COUNTRY CTY

ON

ST.COUNTRYCODE = CTY.COUNTRYCODE







BEGIN TRY DROP TABLE #PASSENGERALL END TRY BEGIN CATCH END CATCH





SELECT P.*,PP.POSCOUNTRYCODE,PP.POSCOUNTRYNAME,PP.POSCOUNTRYCURRENCY

INTO #PASSENGERALL

FROM

#PASSENGERS P

LEFT JOIN

#PASSENGERPOS PP

ON

P.BOOKINGID = PP.BOOKINGID

AND

P.PASSENGERID = PP.PASSENGERID





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

end SALESCHANNEL,

SCG.GROUPING,SCG.CATEGORY,SA.ORGANIZATIONNAME,SA.COUNTRYCODE ORGANIZATIONCOUNTRYCODE

INTO #PASSENGERCHANNEL

FROM

(SELECT  * FROM #PASSENGERALL) P

LEFT JOIN

SAT_JK_SALESCHANNEL SC

ON

P.ROLECODE = SC.ROLECODE

LEFT JOIN

SAT_JK_SALESCHANNEL_GRP SCG

ON

SC.SALESCHANNELRPT = SCG.CHANNELBREAKDOWN

AND

SCG.CHANNELBREAKDOWN+SCG.CATEGORY <> 'OthersThird Party'

LEFT JOIN

ODS.ORGANIZATION SA

ON

P.ORGANIZATIONCODE = SA.ORGANIZATIONCODE




/*

SELECT TOP 100 * FROM ODS.ORGANIZATION

SELECT TOP 100 * FROM REF_SALES_AGENCY_LIST

*/




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



BEGIN TRY DROP TABLE #PASSENGERALLCURRENCY2 END TRY BEGIN CATCH END CATCH





SELECT P.*,

(CASE WHEN P.CURRENCYCODE <> P.AOCCURRENCY THEN P.FARE_REVENUE*(1/CCA.CONVERSIONRATE) ELSE P.FARE_REVENUE END) FARE_REV_AOCCURRENCY,

(CASE WHEN P.CURRENCYCODE <> P.AOCCURRENCY THEN P.FUEL_REV*(1/CCA.CONVERSIONRATE) ELSE P.FUEL_REV END) FUEL_REV_AOCCURRENCY

INTO #PASSENGERALLCURRENCY2

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







BEGIN TRY DROP TABLE #PASSENGERALLCURRENCY END TRY BEGIN CATCH END CATCH





SELECT P.*,

(CASE WHEN P.CURRENCYCODE <> P.POSCOUNTRYCURRENCY THEN P.FARE_REVENUE*(1/CCP.CONVERSIONRATE) ELSE P.FARE_REVENUE END) FARE_REV_POSCURRENCY,

(CASE WHEN P.CURRENCYCODE <> P.POSCOUNTRYCURRENCY THEN P.FUEL_REV*(1/CCP.CONVERSIONRATE) ELSE P.FUEL_REV END) FUEL_REV_POSCURRENCY

INTO #PASSENGERALLCURRENCY

FROM

#PASSENGERALLCURRENCY2 P

LEFT JOIN

DW.CURRENCYCONVERSIONHISTORYDECOMPRESSED CCP

ON

CONVERT(DATE,CCP.CONVERSIONDATE,110) = CONVERT(DATE,P.BOOKINGDATE,110)

AND

CCP.FROMCURRENCYCODE = P.POSCOUNTRYCURRENCY

AND

CCP.TOCURRENCYCODE = P.CURRENCYCODE















BEGIN TRY DROP TABLE TEMP_SALESCHANNEL_MONTHLY_V3 END TRY BEGIN CATCH END CATCH



SELECT DATEPART(YYYY,BOOKINGDATE) BOOKINGYEAR, DATENAME(MM,BOOKINGDATE) BOOKINGMONTH,CARRIERCODE,

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

case when DATEDIFF(DAY,BookingDate,DepartureDate) between 0 and 10 then '0-10'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 11 and 20 then '11-20'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 21 and 30 then '21-30'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 31 and 40 then '31-40'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 41 and 50 then '41-50'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 51 and 60 then '51-60'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 61 and 70 then '61-70'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 71 and 80 then '71-80'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 81 and 90 then '81-90'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 91 and 100 then '91-100'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 101 and 110 then '101-110'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 111 and 120 then '111-120'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 121 and 130 then '121-130'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 131 and 140 then '131-140'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 141 and 150 then '141-150'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 151 and 160 then '151-160'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 161 and 170 then '161-170'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 171 and 180 then '171-180'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 181 and 190 then '181-190'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 191 and 200 then '191-200'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 201 and 210 then '201-210'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 211 and 220 then '211-220'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 221 and 230 then '221-230'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 231 and 240 then '231-240'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 241 and 250 then '241-250'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 251 and 260 then '251-260' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 261 and 270 then '261-270' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 271 and 280 then '271-280' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 281 and 290 then '281-290' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 291 and 300 then '291-300' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 301 and 310 then '301-310' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 311 and 320 then '311-320' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 321 and 330 then '321-330' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 331 and 340 then '331-340' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 341 and 350 then '341-350' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 351 and 360 then '351-360' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 361 and 370 then '361-370' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 371 and 380 then '371-380' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 381 and 390 then '381-390' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 391 and 400 then '391-400' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 401 and 410 then '401-410' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 411 and 420 then '411-420' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 421 and 430 then '421-430' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 431 and 440 then '431-440' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 441 and 450 then '441-450' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 451 and 460 then '451-460' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 461 and 470 then '461-470' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 471 and 480 then '471-480' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 481 and 490 then '481-490' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 491 and 500 then '491-500' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 501 and 510 then '501-510' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 511 and 520 then '511-520' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 521 and 530 then '521-530' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 531 and 540 then '531-540' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 541 and 550 then '541-550' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 551 and 560 then '551-560' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 561 and 570 then '561-570' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 571 and 580 then '571-580' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 581 and 590 then '581-590' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 591 and 600 then '591-600' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 601 and 610 then '601-610' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 611 and 620 then '611-620' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 621 and 630 then '621-630' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 631 and 640 then '631-640' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 641 and 650 then '641-650' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 651 and 660 then '651-660' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 661 and 670 then '661-670' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 671 and 680 then '671-680' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 681 and 690 then '681-690' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 691 and 700 then '691-700' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 701 and 710 then '701-710' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 711 and 720 then '711-720' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 721 and 730 then '721-730' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 731 and 740 then '731-740' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 741 and 750 then '741-750' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 751 and 760 then '751-760' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 761 and 770 then '761-770' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 771 and 780 then '771-780' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 781 and 790 then '781-790' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 791 and 800 then '791-800' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 801 and 810 then '801-810' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 811 and 820 then '811-820' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 821 and 830 then '821-830' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 831 and 840 then '831-840' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 841 and 850 then '841-850' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 851 and 860 then '851-860' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 861 and 870 then '861-870' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 871 and 880 then '871-880' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 881 and 890 then '881-890' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 891 and 900 then '891-900' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 901 and 910 then '901-910' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 911 and 920 then '911-920' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 921 and 930 then '921-930' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 931 and 940 then '931-940' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 941 and 950 then '941-950' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 951 and 960 then '951-960' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 961 and 970 then '961-970' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 971 and 980 then '971-980' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 981 and 990 then '981-990' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 991 and 1000 then '991-1000' 

	 else 'Unknown'

end as PURCHASELEADDAYS,

SALESCHANNEL,CURRENCYCODE,ORGANIZATIONCODE,ORGANIZATIONNAME,ORGANIZATIONCOUNTRYCODE,CATEGORY,GROUPING SALESCHANNELGROUPING,

CASE WHEN INTERNATIONAL = 1 THEN 'INT' ELSE 'DOM' END DOM_INT,

DEPARTURECOUNTRYCODE+'-'+ARRIVALCOUNTRYCODE COUNTRYPAIR,

(CASE WHEN ASCII(SUBSTRING(DEPARTURECOUNTRYCODE,1,1)) < ASCII(SUBSTRING(ARRIVALCOUNTRYCODE,1,1)) THEN DEPARTURECOUNTRYCODE +'-'+ ARRIVALCOUNTRYCODE

	  WHEN ASCII(SUBSTRING(DEPARTURECOUNTRYCODE,1,1)) > ASCII(SUBSTRING(ARRIVALCOUNTRYCODE,1,1)) THEN ARRIVALCOUNTRYCODE +'-'+ DEPARTURECOUNTRYCODE

	  ELSE 

		CASE WHEN ASCII(SUBSTRING(DEPARTURECOUNTRYCODE,2,1)) < ASCII(SUBSTRING(ARRIVALCOUNTRYCODE,2,1)) THEN DEPARTURECOUNTRYCODE +'-'+ ARRIVALCOUNTRYCODE

		WHEN ASCII(SUBSTRING(DEPARTURECOUNTRYCODE,2,1)) > ASCII(SUBSTRING(ARRIVALCOUNTRYCODE,2,1)) THEN ARRIVALCOUNTRYCODE +'-'+ DEPARTURECOUNTRYCODE

		ELSE DEPARTURECOUNTRYCODE+'-'+ARRIVALCOUNTRYCODE 

		END

	 END) COUNTRYPAIRGROUP,

DEPARTURECOUNTRY DEPCOUNTRY,ARRIVALCOUNTRY ARRCOUNTRY,POSCOUNTRYNAME POSCOUNTRY, POSCOUNTRYCURRENCY POSCURRENCY,

COUNT(DISTINCT SEGMENTID) SEATSOLD,

SUM(FARE_REVENUE) FARE_REV_BOOKINGCURRENCY,

SUM(FUEL_REV) FUEL_REV_BOOKINGCURRENCY,

SUM(FARE_REV_MYR) FARE_REV_MYR,

SUM(FUEL_REV_MYR) FUEL_REV_MYR,

SUM(FARE_REV_AOCCURRENCY) FARE_REV_AOCCURRENCY,

SUM(FUEL_REV_AOCCURRENCY) FUEL_REV_AOCCURRENCY,

SUM(FARE_REV_POSCURRENCY) FARE_REV_POSCURRENCY,

SUM(FUEL_REV_POSCURRENCY) FUEL_REV_POSCURRENCY

 INTO TEMP_SALESCHANNEL_MONTHLY_V3

 FROM #PASSENGERALLCURRENCY

 GROUP BY DATEPART(YYYY,BOOKINGDATE), DATENAME(MM,BOOKINGDATE),CARRIERCODE,

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

case when DATEDIFF(DAY,BookingDate,DepartureDate) between 0 and 10 then '0-10'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 11 and 20 then '11-20'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 21 and 30 then '21-30'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 31 and 40 then '31-40'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 41 and 50 then '41-50'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 51 and 60 then '51-60'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 61 and 70 then '61-70'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 71 and 80 then '71-80'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 81 and 90 then '81-90'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 91 and 100 then '91-100'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 101 and 110 then '101-110'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 111 and 120 then '111-120'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 121 and 130 then '121-130'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 131 and 140 then '131-140'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 141 and 150 then '141-150'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 151 and 160 then '151-160'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 161 and 170 then '161-170'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 171 and 180 then '171-180'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 181 and 190 then '181-190'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 191 and 200 then '191-200'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 201 and 210 then '201-210'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 211 and 220 then '211-220'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 221 and 230 then '221-230'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 231 and 240 then '231-240'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 241 and 250 then '241-250'

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 251 and 260 then '251-260' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 261 and 270 then '261-270' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 271 and 280 then '271-280' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 281 and 290 then '281-290' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 291 and 300 then '291-300' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 301 and 310 then '301-310' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 311 and 320 then '311-320' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 321 and 330 then '321-330' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 331 and 340 then '331-340' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 341 and 350 then '341-350' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 351 and 360 then '351-360' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 361 and 370 then '361-370' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 371 and 380 then '371-380' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 381 and 390 then '381-390' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 391 and 400 then '391-400' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 401 and 410 then '401-410' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 411 and 420 then '411-420' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 421 and 430 then '421-430' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 431 and 440 then '431-440' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 441 and 450 then '441-450' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 451 and 460 then '451-460' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 461 and 470 then '461-470' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 471 and 480 then '471-480' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 481 and 490 then '481-490' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 491 and 500 then '491-500' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 501 and 510 then '501-510' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 511 and 520 then '511-520' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 521 and 530 then '521-530' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 531 and 540 then '531-540' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 541 and 550 then '541-550' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 551 and 560 then '551-560' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 561 and 570 then '561-570' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 571 and 580 then '571-580' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 581 and 590 then '581-590' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 591 and 600 then '591-600' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 601 and 610 then '601-610' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 611 and 620 then '611-620' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 621 and 630 then '621-630' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 631 and 640 then '631-640' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 641 and 650 then '641-650' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 651 and 660 then '651-660' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 661 and 670 then '661-670' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 671 and 680 then '671-680' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 681 and 690 then '681-690' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 691 and 700 then '691-700' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 701 and 710 then '701-710' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 711 and 720 then '711-720' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 721 and 730 then '721-730' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 731 and 740 then '731-740' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 741 and 750 then '741-750' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 751 and 760 then '751-760' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 761 and 770 then '761-770' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 771 and 780 then '771-780' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 781 and 790 then '781-790' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 791 and 800 then '791-800' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 801 and 810 then '801-810' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 811 and 820 then '811-820' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 821 and 830 then '821-830' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 831 and 840 then '831-840' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 841 and 850 then '841-850' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 851 and 860 then '851-860' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 861 and 870 then '861-870' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 871 and 880 then '871-880' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 881 and 890 then '881-890' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 891 and 900 then '891-900' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 901 and 910 then '901-910' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 911 and 920 then '911-920' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 921 and 930 then '921-930' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 931 and 940 then '931-940' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 941 and 950 then '941-950' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 951 and 960 then '951-960' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 961 and 970 then '961-970' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 971 and 980 then '971-980' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 981 and 990 then '981-990' 

	 when DATEDIFF(DAY,BookingDate,DepartureDate) between 991 and 1000 then '991-1000' 

	 else 'Unknown'

end,

SALESCHANNEL,CURRENCYCODE,ORGANIZATIONCODE,ORGANIZATIONNAME,ORGANIZATIONCOUNTRYCODE,CATEGORY,GROUPING,

CASE WHEN INTERNATIONAL = 1 THEN 'INT' ELSE 'DOM' END,

DEPARTURECOUNTRYCODE+'-'+ARRIVALCOUNTRYCODE,

(CASE WHEN ASCII(SUBSTRING(DEPARTURECOUNTRYCODE,1,1)) < ASCII(SUBSTRING(ARRIVALCOUNTRYCODE,1,1)) THEN DEPARTURECOUNTRYCODE +'-'+ ARRIVALCOUNTRYCODE

	  WHEN ASCII(SUBSTRING(DEPARTURECOUNTRYCODE,1,1)) > ASCII(SUBSTRING(ARRIVALCOUNTRYCODE,1,1)) THEN ARRIVALCOUNTRYCODE +'-'+ DEPARTURECOUNTRYCODE

	  ELSE 

		CASE WHEN ASCII(SUBSTRING(DEPARTURECOUNTRYCODE,2,1)) < ASCII(SUBSTRING(ARRIVALCOUNTRYCODE,2,1)) THEN DEPARTURECOUNTRYCODE +'-'+ ARRIVALCOUNTRYCODE

		WHEN ASCII(SUBSTRING(DEPARTURECOUNTRYCODE,2,1)) > ASCII(SUBSTRING(ARRIVALCOUNTRYCODE,2,1)) THEN ARRIVALCOUNTRYCODE +'-'+ DEPARTURECOUNTRYCODE

		ELSE DEPARTURECOUNTRYCODE+'-'+ARRIVALCOUNTRYCODE 

		END

	 END),

DEPARTURECOUNTRY,ARRIVALCOUNTRY,POSCOUNTRYNAME, POSCOUNTRYCURRENCY














END















GO


