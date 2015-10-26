USE [REZAKWB01]
GO

/****** Object:  StoredProcedure [wb].[SAT_usp_AA_SalesChannel_Daily]    Script Date: 10/26/2015 10:22:28 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO













-- =============================================
-- Author:		<Frederick Cheah> <Tan Jenn Kok>
-- Create date: <2012-09-21,,>    <2012-12-13>
-- Description:	<SAT_usp_AA_SalesChannel_Monthly>
-- Sales Channel cleanup, everything changed by JK
-- =============================================
--ALTER PROCEDURE [wb].[SAT_usp_AA_SalesChannel_Daily]

--AS
BEGIN

	SET NOCOUNT ON;
	

DECLARE	@MYDateUTC	DATETIME, 
		@STARTDATE DATE,
		@ENDDATE DATE 
				
select @MYDateUTC  = DATEADD(HH,+8,GetDate())

SET @STARTDATE= CAST(CONVERT(VARCHAR, DateAdd(day,-1,@MYDateUTC), 101) AS DateTime)
--SET @ENDDATE= CAST(CONVERT(VARCHAR, DateAdd(day,38,@MYDateUTC), 101) AS DateTime)-- NEW DATEADDED FOR CUSTOM QUERY--
SET @ENDDATE= CAST(CONVERT(VARCHAR, @MYDateUTC, 101) AS DateTime)
--SET @ENDDATE= @MYDateUTC-1

print @MYDateUTC
print @STARTDATE
print @ENDDATE

BEGIN

BEGIN TRY DROP TABLE #allBookings END TRY BEGIN CATCH END CATCH

select C.PassengerID, C.SegmentID, C.DepartureStation, C.ArrivalStation, FlightPath, 
DepartureDate, JourneyNumber, CarrierCode,
A.BookingID, RecordLocator, CreatedAgentID, CurrencyCode, 
BookingDate,
DATENAME(MONTH, BookingDate) as BookingMonth,
DATEPART(YEAR, BookingDate) as BookingYear,
('W'+CONVERT(VARCHAR(3),DATEPART(week, BookingDate))) as BookingWkYr,
('W'+CONVERT(VARCHAR(3),DATEPART(WEEK, BookingDate))) as BookingWkMth,
DOM_INT, FareClassOfService,
DepartureMonth, DepartureYear
into #allBookings
from
(select BookingID, RecordLocator, CreatedAgentID, CurrencyCode, CONVERT(DATE,DATEADD(HH,+8,BookingDate)) as BookingDate 
from ods.Booking with (nolock)
where Status in (2,3)
and DATEADD(HH,+8,BookingDate) >= @STARTDATE  and DATEADD(HH,+8,BookingDate) < @ENDDATE
--and DATEADD(HH,+8,BookingDate) >= '2014-05-27' and DATEADD(HH,+8,BookingDate) < '2014-05-28'
) A

left join
(select BookingID, PassengerID
from ods.BookingPassenger with (nolock)) B
on A.BookingID = B.BookingID

inner join
(select PassengerID, SegmentID, DepartureStation, ArrivalStation, DepartureStation+ArrivalStation as FlightPath, 
DepartureDate, JourneyNumber, CarrierCode, FareClassOfService,
DATENAME(MONTH,DepartureDate) as DepartureMonth, DATEPART(YEAR,DepartureDate) as DepartureYear
from vw_PassengerJourneySegment with (nolock)
where BookingStatus = 'HK'
and CarrierCode in (select CarrierCode from ods.Carrier)
and DepartureStation+ArrivalStation not in ('BOMKUL','CHCKUL','DELKUL','DLCKUL','HRBKUL','IKAKUL','KULLGW','KULORY','KULTSN','MELPER','KULWUH',
'KULBOM','KULCHC','KULDEL','KULDLC','KULHRB','KULIKA','LGWKUL','ORYKUL','TSNKUL','PERMEL','WUHKUL')) C
on B.PassengerID = C.PassengerID

left join
(select DepartureStation, ArrivalStation, case when InternationalFlag = 1 then 'International' else 'Domestic' end as DOM_INT 
from dw.CityPair) CP
on C.DepartureStation = CP.DepartureStation 
and C.ArrivalStation = CP.ArrivalStation




BEGIN TRY DROP TABLE #Passengers END TRY BEGIN CATCH END CATCH

select A.PassengerID, A.SegmentID, 
DATEPART(YEAR, BookingDate) as BookingYear,
DATENAME(MONTH, BookingDate) as BookingMonth,
('W'+CONVERT(VARCHAR(3),DATEPART(week, BookingDate))) as BookingWkYr,
('W'+CONVERT(VARCHAR(3),DATEPART(WEEK, DAY(BookingDate)))) as BookingWkMth,
CONVERT(DATE,BookingDate) as BookingDate, 
DepartureDate, DepartureMonth, DepartureYear, CarrierCode, MarketGroup, FlightPath, JourneyNumber, A.CreatedAgentID, A.CurrencyCode,
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
end as PurchaseLeadDays,
DOM_INT, FareClassOfService,
ST1.CountryCode+'-'+ST2.CountryCode as CountryPair,
--ST3.CountryCode+'-'+ST4.CountryCode as CountryPairMktGrp
(CASE WHEN ascii(SUBSTRING(ST3.COUNTRYCODE,1,1)) < ascii(SUBSTRING(ST4.COUNTRYCODE,1,1)) THEN ST3.COUNTRYCODE+'-'+ST4.COUNTRYCODE

	 WHEN ascii(SUBSTRING(ST3.COUNTRYCODE,1,1)) > ascii(SUBSTRING(ST4.COUNTRYCODE,1,1)) THEN ST4.COUNTRYCODE+'-'+ST3.COUNTRYCODE

	 WHEN ascii(SUBSTRING(ST3.COUNTRYCODE,1,1)) = ascii(SUBSTRING(ST4.COUNTRYCODE,1,1)) THEN

					(CASE WHEN ascii(SUBSTRING(ST3.COUNTRYCODE,2,1)) <= ascii(SUBSTRING(ST4.COUNTRYCODE,2,1)) THEN ST3.COUNTRYCODE+'-'+ST4.COUNTRYCODE

						  WHEN ascii(SUBSTRING(ST3.COUNTRYCODE,2,1)) > ascii(SUBSTRING(ST4.COUNTRYCODE,2,1)) THEN ST4.COUNTRYCODE+'-'+ST3.COUNTRYCODE 
						  END)
	END) CountryPairMktGrp
into #Passengers
from 
#allBookings A

left join 
(select DepartureStation, ArrivalStation, MarketGroup, LEFT(MarketGroup,3) as DepartureStationMG, RIGHT(MarketGroup,3) as ArrivalStationMG
from SAT_MarketGroupJK) H 
on A.DepartureStation = H.DepartureStation
and A.ArrivalStation = H.ArrivalStation

left join ods.Station ST1 on A.DepartureStation = ST1.StationCode
left join ods.Station ST2 on A.ArrivalStation = ST2.StationCode
left join ods.Station ST3 on H.DepartureStationMG = ST3.StationCode
left join ods.Station ST4 on H.ArrivalStationMG = ST4.StationCode


BEGIN TRY DROP TABLE #Passengers2 END TRY BEGIN CATCH END CATCH

select A.*,
--SUM(ods.convertCurrency(D.BaseFare, A.CurrencyCode, 'MYR', A.BookingDate)) as BaseFare 
SUM(BaseFare/ISNULL(ConversionRate,1)) as BaseFare
into #Passengers2
from 
#Passengers A

left join
(select PassengerID, SegmentID,
sum(case when ChargeType = 0 then ISNULL(ChargeAmount,0.00) *1
	  when ChargeType = 8 then ISNULL(ChargeAmount,0.00) *1
	  when ChargeType = 1 then ISNULL(ChargeAmount,0.00) *-1 
	  when ChargeType = 7 then ISNULL(ChargeAmount,0.00) *-1 
end) as BaseFare
from ods.PassengerJourneyCharge with (nolock)
where ChargeType in (0,8,1,7,5)
group by PassengerID, SegmentID) D
on A.PassengerID = D.PassengerID
and A.SegmentID = D.SegmentID

left join
	(select FromCurrencyCode, ToCurrencyCode, ConversionDate, ConversionRate
	from dw.CurrencyconversionHistoryDecompressed with (nolock)	
	where FromCurrencyCode = 'MYR') F
	on A.BookingDate = F.ConversionDate and A.CurrencyCode = F.ToCurrencyCode	
group by
A.PassengerID, A.SegmentID, BookingYear, BookingMonth, BookingWkYr, BookingWkMth, BookingDate, 
DepartureDate, DepartureMonth, DepartureYear, CarrierCode, MarketGroup, FlightPath, JourneyNumber, A.CreatedAgentID, A.CurrencyCode, PurchaseLeadDays,
DOM_INT, FareClassOfService,
CountryPair,
CountryPairMktGrp



BEGIN TRY DROP TABLE SAT_Temp_SalesChannel_Daily_2011 END TRY BEGIN CATCH END CATCH
BEGIN TRY DROP TABLE SAT_Temp_SalesChannel_Daily_2012 END TRY BEGIN CATCH END CATCH
BEGIN TRY DROP TABLE SAT_Temp_SalesChannel_Daily END TRY BEGIN CATCH END CATCH
BEGIN TRY DROP TABLE SAT_JK_tmptmp END TRY BEGIN CATCH END CATCH
BEGIN TRY DROP TABLE #Passengers END TRY BEGIN CATCH END CATCH
BEGIN TRY DROP TABLE #allBookings END TRY BEGIN CATCH END CATCH

select BookingYear, BookingMonth, BookingWkYr, BookingWkMth, BookingDate, 
DepartureMonth, DepartureYear,
CarrierCode, MarketGroup, FlightPath, JourneyNumber,
PurchaseLeadDays, 
F.RoleCode, A.CurrencyCode,
case when H.SalesChannelRpt = 'Corporate' and (G.OrganizationCode like '%A%' OR G.OrganizationCode like '%B%' OR G.OrganizationCode like '%C%' OR
		 G.OrganizationCode like '%D%' OR G.OrganizationCode like '%E%' OR G.OrganizationCode like '%F%' OR G.OrganizationCode like '%G%' OR
		 G.OrganizationCode like '%H%' OR G.OrganizationCode like '%I%' OR G.OrganizationCode like '%J%' OR G.OrganizationCode like '%K%' OR
		 G.OrganizationCode like '%L%' OR G.OrganizationCode like '%M%' OR G.OrganizationCode like '%N%' OR G.OrganizationCode like '%O%' OR
		 G.OrganizationCode like '%P%' OR G.OrganizationCode like '%Q%' OR G.OrganizationCode like '%R%' OR G.OrganizationCode like '%S%' OR
		 G.OrganizationCode like '%T%' OR G.OrganizationCode like '%U%' OR G.OrganizationCode like '%V%' OR G.OrganizationCode like '%W%' OR
		 G.OrganizationCode like '%X%' OR G.OrganizationCode like '%Y%' OR G.OrganizationCode like '%Z%') then 'Corporate - Direct'
	 when H.SalesChannelRpt = 'Corporate' and (G.OrganizationCode not like '%A%' AND G.OrganizationCode not like '%B%' AND G.OrganizationCode not like '%C%' AND
		 G.OrganizationCode not like '%D%' AND G.OrganizationCode not like '%E%' AND G.OrganizationCode not like '%F%' AND G.OrganizationCode not like '%G%' AND
		 G.OrganizationCode not like '%H%' AND G.OrganizationCode not like '%I%' AND G.OrganizationCode not like '%J%' AND G.OrganizationCode not like '%K%' AND
		 G.OrganizationCode not like '%L%' AND G.OrganizationCode not like '%M%' AND G.OrganizationCode not like '%N%' AND G.OrganizationCode not like '%O%' AND
		 G.OrganizationCode not like '%P%' AND G.OrganizationCode not like '%Q%' AND G.OrganizationCode not like '%R%' AND G.OrganizationCode not like '%S%' AND
		 G.OrganizationCode not like '%T%' AND G.OrganizationCode not like '%U%' AND G.OrganizationCode not like '%V%' AND G.OrganizationCode not like '%W%' AND
		 G.OrganizationCode not like '%X%' AND G.OrganizationCode not like '%Y%' AND G.OrganizationCode not like '%Z%') then 'Corporate - TMC'
	 when SalesChannelRpt = 'Corporate' and G.OrganizationCode IS NULL then SalesChannelRpt
	 when SalesChannelRpt <> 'Corporate' then SalesChannelRpt else 'UnknownRoleCode'
end as SalesChannel,
Category,  Grouping as SalesChannelGrouping,
DOM_INT, FareClassOfService,
CountryPair,
CountryPairMktGrp,
COUNT(A.PassengerID) as SeatSold,
SUM(BaseFare) as BaseFare 
into 
SAT_Temp_SalesChannel_Daily
from 
#Passengers2 A
/*
left join
(select AgentID, OrganizationCode, DepartmentCode, LocationCode 
from ods.Agent with (nolock)) E
on A.CreatedAgentID = E.AgentID
*/
left join
(select AgentID, RoleCode
from ods.AgentRole) F
on A.CreatedAgentID = F.AgentID

left join
(select AgentID, OrganizationCode from ods.Agent) G
on A.CreatedAgentID = G.AgentID

left join
(select distinct RoleCode, SalesChannelRpt 
from SAT_JK_SalesChannel
where Status = 'EXIST'
) H
on F.RoleCode = H.RoleCode

left join SAT_JK_SalesChannel_Grp SCG
on H.SalesChannelRpt = SCG.ChannelBreakdown

group by
BookingYear, BookingMonth, BookingWkYr, BookingWkMth, BookingDate, 
DepartureMonth, DepartureYear,
CarrierCode, MarketGroup, FlightPath, JourneyNumber,PurchaseLeadDays,
F.RoleCode, A.CurrencyCode,
case when H.SalesChannelRpt = 'Corporate' and (G.OrganizationCode like '%A%' OR G.OrganizationCode like '%B%' OR G.OrganizationCode like '%C%' OR
		 G.OrganizationCode like '%D%' OR G.OrganizationCode like '%E%' OR G.OrganizationCode like '%F%' OR G.OrganizationCode like '%G%' OR
		 G.OrganizationCode like '%H%' OR G.OrganizationCode like '%I%' OR G.OrganizationCode like '%J%' OR G.OrganizationCode like '%K%' OR
		 G.OrganizationCode like '%L%' OR G.OrganizationCode like '%M%' OR G.OrganizationCode like '%N%' OR G.OrganizationCode like '%O%' OR
		 G.OrganizationCode like '%P%' OR G.OrganizationCode like '%Q%' OR G.OrganizationCode like '%R%' OR G.OrganizationCode like '%S%' OR
		 G.OrganizationCode like '%T%' OR G.OrganizationCode like '%U%' OR G.OrganizationCode like '%V%' OR G.OrganizationCode like '%W%' OR
		 G.OrganizationCode like '%X%' OR G.OrganizationCode like '%Y%' OR G.OrganizationCode like '%Z%') then 'Corporate - Direct'
	 when H.SalesChannelRpt = 'Corporate' and (G.OrganizationCode not like '%A%' AND G.OrganizationCode not like '%B%' AND G.OrganizationCode not like '%C%' AND
		 G.OrganizationCode not like '%D%' AND G.OrganizationCode not like '%E%' AND G.OrganizationCode not like '%F%' AND G.OrganizationCode not like '%G%' AND
		 G.OrganizationCode not like '%H%' AND G.OrganizationCode not like '%I%' AND G.OrganizationCode not like '%J%' AND G.OrganizationCode not like '%K%' AND
		 G.OrganizationCode not like '%L%' AND G.OrganizationCode not like '%M%' AND G.OrganizationCode not like '%N%' AND G.OrganizationCode not like '%O%' AND
		 G.OrganizationCode not like '%P%' AND G.OrganizationCode not like '%Q%' AND G.OrganizationCode not like '%R%' AND G.OrganizationCode not like '%S%' AND
		 G.OrganizationCode not like '%T%' AND G.OrganizationCode not like '%U%' AND G.OrganizationCode not like '%V%' AND G.OrganizationCode not like '%W%' AND
		 G.OrganizationCode not like '%X%' AND G.OrganizationCode not like '%Y%' AND G.OrganizationCode not like '%Z%') then 'Corporate - TMC'
	 when SalesChannelRpt = 'Corporate' and G.OrganizationCode IS NULL then SalesChannelRpt
	 when SalesChannelRpt <> 'Corporate' then SalesChannelRpt else 'UnknownRoleCode'
end,	
Category, Grouping,
DOM_INT, FareClassOfService,
CountryPair,
CountryPairMktGrp



/*

select distinct BookingYear from SAT_Temp_SalesChannel_Monthly_2012

select max(BaseFare) from SAT_Temp_SalesChannel_Monthly_2012
where SeatSold = 1800
*/
--1:17:02

/*
BEGIN TRY DROP TABLE SAT_TEMP_SalesChannel_Monthly END TRY BEGIN CATCH END CATCH

select * into SAT_TEMP_SalesChannel_Monthly 
from SAT_JK_SalesChannel_Monthly_2011
UNION ALL
select * from SAT_JK_SalesChannel_Monthly_2012

select distinct SalesChannelRpt  from SAT_JK_SalesChannel
*/
/*
left join

update SAT_JK_SalesChannel set SalesChannelRpt = 
case when SalesChannel = 'Corporate' and (OrganizationCode like '%A%' OR OrganizationCode like '%B%' OR OrganizationCode like '%C%' OR
		 OrganizationCode like '%D%' OR OrganizationCode like '%E%' OR OrganizationCode like '%F%' OR OrganizationCode like '%G%' OR
		 OrganizationCode like '%H%' OR OrganizationCode like '%I%' OR OrganizationCode like '%J%' OR OrganizationCode like '%K%' OR
		 OrganizationCode like '%L%' OR OrganizationCode like '%M%' OR OrganizationCode like '%N%' OR OrganizationCode like '%O%' OR
		 OrganizationCode like '%P%' OR OrganizationCode like '%Q%' OR OrganizationCode like '%R%' OR OrganizationCode like '%S%' OR
		 OrganizationCode like '%T%' OR OrganizationCode like '%U%' OR OrganizationCode like '%V%' OR OrganizationCode like '%W%' OR
		 OrganizationCode like '%X%' OR OrganizationCode like '%Y%' OR OrganizationCode like '%Z%') then Corp
	 when SalesChannel = 'Corporate' and (OrganizationCode not like '%A%' AND OrganizationCode not like '%B%' AND OrganizationCode not like '%C%' AND
		 OrganizationCode not like '%D%' AND OrganizationCode not like '%E%' AND OrganizationCode not like '%F%' AND OrganizationCode not like '%G%' AND
		 OrganizationCode not like '%H%' AND OrganizationCode not like '%I%' AND OrganizationCode not like '%J%' AND OrganizationCode not like '%K%' AND
		 OrganizationCode not like '%L%' AND OrganizationCode not like '%M%' AND OrganizationCode not like '%N%' AND OrganizationCode not like '%O%' AND
		 OrganizationCode not like '%P%' AND OrganizationCode not like '%Q%' AND OrganizationCode not like '%R%' AND OrganizationCode not like '%S%' AND
		 OrganizationCode not like '%T%' AND OrganizationCode not like '%U%' AND OrganizationCode not like '%V%' AND OrganizationCode not like '%W%' AND
		 OrganizationCode not like '%X%' AND OrganizationCode not like '%Y%' AND OrganizationCode not like '%Z%') then Corp
	 when SalesChannel = 'Corporate' and OrganizationCode IS NULL then Corp
	 else SalesChannel 
end

SELECT DISTINCT (SALESCHANNEL) FROM SAT_JK_SalesChannel
WHERE SALESCHA

*/



BEGIN TRY DROP TABLE #Passengers END TRY BEGIN CATCH END CATCH
BEGIN TRY DROP TABLE #Passengers2 END TRY BEGIN CATCH END CATCH
 
END

END
































GO


