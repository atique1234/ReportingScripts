USE [REZAKWB01]
GO

/****** Object:  StoredProcedure [wb].[SAT_usp_SAT_JK_Tinky_China]    Script Date: 10/22/2015 17:11:35 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO























-- =============================================
-- Author:		 <Tan Jenn Kok>
-- Create date: <2012-09-21,,>    <2012-12-13>
-- Description:	<SAT_usp_AA_SalesChannel_Monthly>
-- Sales Channel cleanup, everything changed by JK
-- =============================================
--ALTER PROCEDURE [wb].[SAT_usp_SAT_JK_Tinky_China]

--AS
BEGIN

	SET NOCOUNT ON;
	

DECLARE	@MYDate	DATETIME, 
		@STARTDATE DATETIME,
		@ENDDATE DATETIME
		 
				
select @MYDate  = CONVERT(DATE,DOWNLOADDATE) FROM SAT_AA_L_DOWNLOADDATE	
--SET @MYDate = CONVERT(DATETIME,@MYDateUTC)
SET @STARTDATE= CAST(CONVERT(VARCHAR, DATEADD(s, 1,DATEADD(mm, DATEDIFF(m,0,DateAdd(month,-5,@MYDate)),0)), 101) AS DateTime)
SET @ENDDATE=CAST(CONVERT(VARCHAR, DATEADD(s, 1,DATEADD(mm, DATEDIFF(m,0,DateAdd(month,0,@MYDate)),0)), 101) AS DateTime)
--SET @ENDDATE= @MYDateUTC-1

PRINT @MYDate
PRINT @STARTDATE
PRINT @ENDDATE

BEGIN

BEGIN TRY DROP TABLE #allBookings END TRY BEGIN CATCH END CATCH

select pjs.PassengerID, pjs.SegmentID, pjs.DepartureStation, pjs.ArrivalStation, MarketGroup, pjs.DepartureStation+pjs.ArrivalStation as FlightPath, 
pjs.DepartureDate, pjs.JourneyNumber, isnull(carr_map.mappedcarrier ,pjs.CARRIERCODE) CarrierCode, pjs.FlightNumber, co.Name as Nationality,
bk.BookingID, bk.RecordLocator, bk.CreatedAgentID, bk.CurrencyCode, 
DATEADD(HH,+8,bk.BookingDate) as BookingDate, case when bp.Gender = 1 then 'Male' else 'Female' end as Gender, DATEDIFF(YEAR,DOB,GetDate()) as Age, bp.FirstName, bp.LastName,
DATENAME(MONTH, DATEADD(HH,+8,bk.BookingDate)) as BookingMonth,
DATEPART(YEAR, DATEADD(HH,+8,bk.BookingDate)) as BookingYear,
('W'+CONVERT(VARCHAR(3),DATEPART(week, DATEADD(HH,+8,bk.BookingDate)))) as BookingWkYr,
('W'+CONVERT(VARCHAR(3),DATEPART(WEEK, DATEADD(HH,+8,bk.BookingDate)))) as BookingWkMth
into #allBookings
from ods.Booking bk with (nolock) 
inner join ods.BookingPassenger bp with (nolock) on bk.BookingID = bp.BookingID
inner join vw_PassengerJourneySegment pjs with (nolock) on bp.PassengerID = pjs.PassengerID
LEFT JOIN 
AAII_CARRIER_MAPPING carr_map
on carr_map.carriercode = pjs.carriercode
and ltrim(RTRIM(carr_map.flightnumber)) = ltrim(RTRIM(pjs.flightnumber))
		
left join SAT_MarketGroupJK H on pjs.DepartureStation = H.DepartureStation and pjs.ArrivalStation = H.ArrivalStation
left join ods.Country co on bp.Nationality = co.CountryCode
where bk.Status in (2,3) and pjs.BookingStatus = 'HK'
and DATEADD(HH,+8,bk.BookingDate) >= @STARTDATE  and DATEADD(HH,+8,bk.BookingDate) < @MYDate
and bp.Nationality in ('CN','HK','MO')
and pjs.CarrierCode in (select CarrierCode from ods.Carrier)



BEGIN TRY DROP TABLE #Passengers END TRY BEGIN CATCH END CATCH

select A.PassengerID, A.SegmentID, BookingYear, BookingMonth, RecordLocator, CONVERT(DATE,BookingDate) as BookingDate, 
DepartureDate, CarrierCode, A.DepartureStation, A.ArrivalStation, MarketGroup, FlightPath, JourneyNumber, A.CreatedAgentID, A.CurrencyCode,
CASE WHEN Age>=0 AND Age<=12 THEN 'Under 12 years old'
	 WHEN Age>=13 AND Age<=19  THEN 'Teens'
	 WHEN Age>=20 AND Age<=24 THEN 'Youth'
	 WHEN Age>=25 AND Age<=29 THEN 'Young Adult'
	 WHEN Age>=30 AND Age<=39 THEN 'Mid Level Execs'
	 WHEN Age>=40 AND Age<=49 THEN 'Mature Affluent'
	 WHEN Age>=50 THEN 'Senior Citizens' ELSE 'Unknown' 
END as AgeGroup,
CASE WHEN DATEDIFF(DAY,A.BookingDate,A.DepartureDate)<=0 THEN '0' 
	 WHEN DATEDIFF(DAY,A.BookingDate,A.DepartureDate)=1 THEN '1' 							  
	 WHEN DATEDIFF(DAY,A.BookingDate,A.DepartureDate)>=2 AND DATEDIFF(DAY,A.BookingDate,A.DepartureDate)<=7  THEN '>1-7'
	 WHEN DATEDIFF(DAY,A.BookingDate,A.DepartureDate)>=8 AND DATEDIFF(DAY,A.BookingDate,A.DepartureDate)<=30 THEN '>7-30'
	 WHEN DATEDIFF(DAY,A.BookingDate,A.DepartureDate)>=31 AND DATEDIFF(DAY,A.BookingDate,A.DepartureDate)<=90 THEN '>30-90'
	 WHEN DATEDIFF(DAY,A.BookingDate,A.DepartureDate)>=91 THEN '>90'  
END as PurchaseLeadDays, 
Gender, A.Nationality, PV.ProvinceState, BC.City, 
case when E.InternationalFlag = 1 then 'INT' else 'DOM' end as DOM_INT,
--DATEDIFF(MINUTE,DepartureTime, ArrivalTime) as FlightTimeMin, ActualDistance as FlightDistanceKM,
BC.EmailAddress, A.FirstName, A.LastName,
case when I.SalesChannelRpt = 'Corporate' and (G.OrganizationCode like '%A%' OR G.OrganizationCode like '%B%' OR G.OrganizationCode like '%C%' OR
		 G.OrganizationCode like '%D%' OR G.OrganizationCode like '%E%' OR G.OrganizationCode like '%F%' OR G.OrganizationCode like '%G%' OR
		 G.OrganizationCode like '%H%' OR G.OrganizationCode like '%I%' OR G.OrganizationCode like '%J%' OR G.OrganizationCode like '%K%' OR
		 G.OrganizationCode like '%L%' OR G.OrganizationCode like '%M%' OR G.OrganizationCode like '%N%' OR G.OrganizationCode like '%O%' OR
		 G.OrganizationCode like '%P%' OR G.OrganizationCode like '%Q%' OR G.OrganizationCode like '%R%' OR G.OrganizationCode like '%S%' OR
		 G.OrganizationCode like '%T%' OR G.OrganizationCode like '%U%' OR G.OrganizationCode like '%V%' OR G.OrganizationCode like '%W%' OR
		 G.OrganizationCode like '%X%' OR G.OrganizationCode like '%Y%' OR G.OrganizationCode like '%Z%') then 'Corporate - Direct'
	 when I.SalesChannelRpt = 'Corporate' and (G.OrganizationCode not like '%A%' AND G.OrganizationCode not like '%B%' AND G.OrganizationCode not like '%C%' AND
		 G.OrganizationCode not like '%D%' AND G.OrganizationCode not like '%E%' AND G.OrganizationCode not like '%F%' AND G.OrganizationCode not like '%G%' AND
		 G.OrganizationCode not like '%H%' AND G.OrganizationCode not like '%I%' AND G.OrganizationCode not like '%J%' AND G.OrganizationCode not like '%K%' AND
		 G.OrganizationCode not like '%L%' AND G.OrganizationCode not like '%M%' AND G.OrganizationCode not like '%N%' AND G.OrganizationCode not like '%O%' AND
		 G.OrganizationCode not like '%P%' AND G.OrganizationCode not like '%Q%' AND G.OrganizationCode not like '%R%' AND G.OrganizationCode not like '%S%' AND
		 G.OrganizationCode not like '%T%' AND G.OrganizationCode not like '%U%' AND G.OrganizationCode not like '%V%' AND G.OrganizationCode not like '%W%' AND
		 G.OrganizationCode not like '%X%' AND G.OrganizationCode not like '%Y%' AND G.OrganizationCode not like '%Z%') then 'Corporate - TMC'
	 when SalesChannelRpt = 'Corporate' and G.OrganizationCode IS NULL then SalesChannelRpt
	 when SalesChannelRpt <> 'Corporate' then SalesChannelRpt else 'UnknownRoleCode'
end as SalesChannel
into #Passengers
from 
#allBookings A

left join
(select distinct BookingID, LOWER(EmailAddress) AS EmailAddress, UPPER(ProvinceState) as ProvinceState, UPPER(RTRIM(LTRIM(City))) as City, CountryCode,
UPPER(FirstName) as FirstName, UPPER(LastName) as LastName
from ods.BookingContact with (nolock)) BC
on A.BookingID = BC.BookingID
and A.FirstName = BC.FirstName and A.LastName = BC.LastName


left join
(select CountryCode, ProvinceStateCode, Name as ProvinceState
from ods.ProvinceState) PV	
on BC.CountryCode = PV.CountryCode
and BC.ProvinceState = PV.ProvinceStateCode

left join
(select DepartureStation, ArrivalStation, InternationalFlag, ActualDistance
from dw.CityPair) E
on A.DepartureStation = E.DepartureStation
and A.ArrivalStation = E.ArrivalStation

left join
(select distinct AgentID, OrganizationCode from ods.Agent) G
on A.CreatedAgentID = G.AgentID

left join
(select distinct AgentID, RoleCode
from ods.AgentRole) H
on A.CreatedAgentID = H.AgentID

left join
(select distinct RoleCode, SalesChannelRpt 
from SAT_JK_SalesChannel
where Status = 'EXIST'
) I
on H.RoleCode = I.RoleCode

--select top 200 * from #Passengers order by PassengerID

BEGIN TRY DROP TABLE #allBookings END TRY BEGIN CATCH END CATCH
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
	where FromCurrencyCode = 'CNY') F
	on A.BookingDate = F.ConversionDate and A.CurrencyCode = F.ToCurrencyCode	

group by
A.PassengerID, A.SegmentID, BookingYear, BookingMonth, RecordLocator, BookingDate, 
DepartureDate, CarrierCode, DepartureStation, ArrivalStation, MarketGroup, FlightPath, JourneyNumber, A.CreatedAgentID, A.CurrencyCode, AgeGroup, PurchaseLeadDays,
Gender, Nationality, ProvinceState, City, DOM_INT, EmailAddress, FirstName, LastName, SalesChannel


BEGIN TRY DROP TABLE SAT_JK_Ticky_China_v2 END TRY BEGIN CATCH END CATCH
BEGIN TRY DROP TABLE SAT_JK_Ticky_China_2013 END TRY BEGIN CATCH END CATCH

select BookingMonth,BookingYear,
DepartureStation,ArrivalStation,FlightPath as Route,
CarrierCode,
--FlightNumber,
Gender,Nationality,ProvinceState,City, EmailAddress, FirstName, LastName, DOM_INT,AgeGroup,PurchaseLeadDays,
--DepartureMonth,
--CurrencyCode,
--BookingDate,DepartureDate,
--JourneyNumber,
SalesChannel, 
count(PassengerID) as TotalSeatSold,
count(distinct RecordLocator) as TotalBooking,
sum(BaseFare) as TotalBaseFareCNY
into SAT_JK_Ticky_China_2013
from #Passengers2
group by BookingMonth,BookingYear,
DepartureStation,ArrivalStation,FlightPath,
CarrierCode,
--FlightNumber,
Gender,Nationality,ProvinceState,City,EmailAddress, FirstName, LastName,DOM_INT,AgeGroup,PurchaseLeadDays,
--DepartureMonth,
--CurrencyCode,
--BookingDate,DepartureDate,
--JourneyNumber,
SalesChannel
/*
select BookingYear, SUM(TotalSeatSold)--, SUM(TotalBaseFareCNY) 
from SAT_JK_Ticky_China_2013
group by BookingYear
*/
BEGIN TRY DROP TABLE #Passengers END TRY BEGIN CATCH END CATCH
BEGIN TRY DROP TABLE #Passengers2 END TRY BEGIN CATCH END CATCH
BEGIN TRY DROP TABLE SAT_JK_Ticky_China_MthYr END TRY BEGIN CATCH END CATCH

select distinct CONVERT(VARCHAR(4),BookingYear)  as BookingYear, BookingMonth, BookingMonth+CONVERT(VARCHAR(4),BookingYear) as BookingMthYr 
into SAT_JK_Ticky_China_MthYr
from SAT_JK_Ticky_China_2013

--select * from SAT_JK_Ticky_China_MthYr




 
END

END




















GO


