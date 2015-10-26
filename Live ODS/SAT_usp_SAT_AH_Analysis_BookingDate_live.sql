USE [REZAKWB01]
GO

/****** Object:  StoredProcedure [wb].[SAT_usp_SAT_AH_Analysis_BookingDate_live]    Script Date: 10/23/2015 12:58:57 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO












-- =============================================
-- Author:		<Abdullah Al Mahbub>
-- Create date: <2015-04-02>
-- Description:	<Create SAT_AH_Analysis_BookingDate in live ods>
-- =============================================


--ALTER PROCEDURE [wb].[SAT_usp_SAT_AH_Analysis_BookingDate_live]

--AS
BEGIN

SET NOCOUNT ON;


DECLARE	@MYDateUTC	DATETIME, 
		@STARTDATE DATETIME,
		@ENDDATE DATETIME


--SET @MYDateUTC = '2015-05-08'
select @MYDateUTC  = ods.ConvertDate( 'MY', GETDATE(),0,0)				
--select @MYDateUTC  = DATEADD(HH,+8,GetDate()) --CONVERT(DATE,DOWNLOADDATE) FROM SAT_AA_L_DOWNLOADDATE	
SET @STARTDATE= CAST(CONVERT(VARCHAR, DateAdd(day,-1,@MYDateUTC), 101) AS DateTime)
SET @ENDDATE= CAST(CONVERT(VARCHAR, @MYDateUTC, 101) AS DateTime)
--SET @STARTDATE= ods.convertdate('my',CAST(CONVERT(VARCHAR, DATEADD(s, 1,DATEADD(mm, DATEDIFF(m,0,DateAdd(month,-6,@MYDateUTC)),0)), 101) AS DateTime), 1, 0)
--SET @ENDDATE=CAST(CONVERT(VARCHAR, DATEADD(s, 1,DATEADD(mm, DATEDIFF(m,0,DateAdd(month,0,@MYDateUTC)),0)), 101) AS DateTime)


print @MYDateUTC
print @STARTDATE
print @ENDDATE
-- Get all bookings within the target dates

BEGIN TRY DROP TABLE #allbookings END TRY BEGIN CATCH END CATCH

select 
	bk.BookingID, 
	bk.RecordLocator,
	DATEADD(HH,+8,bk.BookingDate) as bookingdateUTC,
	bk.currencycode,
	bk.CreatedAgentID,
	LEFT(CurrencyCode,2) as CurrencyCountry
INTO 
	#allbookings
from 
	ods.Booking bk with (nolock, index(Booking_BookingDate_IDX))
where 
	DATEADD(HH,+8,bk.BookingDate) >= @STARTDATE and DATEADD(HH,+8,bk.BookingDate) < @ENDDATE--@STARTDATE and @ENDDATE
	--DATEADD(HH,+8,bk.BookingDate) >= '2014-07-22' and DATEADD(HH,+8,bk.BookingDate) < '2014-07-30'
	and bk.[Status] in (2,3)


BEGIN TRY DROP TABLE #allpassengers END TRY BEGIN CATCH END CATCH

--insert into #allpassengers
select
	ab.*,
	--CONVERT(DATE,ods.convertDate('MY',ab.BookingDateUTC,0,0)) as BookingDate,
	CONVERT(DATE,BookingDateUTC) as BookingDate,
	--DATENAME(MONTH,ods.convertDate('MY',ab.BookingDateUTC,0,0)) as BookingMonth,
	DATENAME(MONTH,ab.BookingDateUTC) as BookingMonth,
	convert(varchar(4),DATEPART(YEAR, ab.BookingDateUTC)) as BookingYear,
	isnull(cty.Name, '') as Nationality_Final,
	bp.PassengerID,
	bp.DOB, 
	DateDiff(YEAR, bp.DOB, getDate()) as Age, 
	bp.Nationality, 
	bp.FirstName, 
	bp.LastName,
	
	case when bp.Gender = 1 then 'Male' else 'Female' end as Gender,
	
	--isnull((select Top 1 DocNumber from ods.PassengerTravelDoc where PassengerID = bp.PassengerID order by ModifiedDate desc), '') as DocNumber,
	
	pjs.SegmentID,
	pjs.JourneyNumber, 
	bc.ProvinceState,
	pjs.InventoryLegID,
	pjs.CarrierCode, 
	pjs.DepartureStation, 
	pjs.ArrivalStation, 
	pjs.DepartureStation + pjs.ArrivalStation as Route, 
	pjs.DepartureDate,
	DATENAME(MONTH, pjs.DepartureDate) as DepartureMonth, 
	convert(varchar(4),DATEPART(YEAR, pjs.DepartureDate)) as DepartureYear, 
	--ab.CreatedAgentID,
	case when pjs.FareClassOfService in ('C','D','G','J') then 'Premium' else 'Economy' end as Premium
into #allpassengers
from
	(select * from #allbookings 
	--where bookingdateUTC >= '2013-07-01' and bookingdateUTC < '2013-08-01'
	) ab
left join 
	ods.BookingPassenger bp with (nolock) 
		on ab.BookingID = bp.BookingID
inner join
	(select t.PassengerID, t.SegmentID, t.InventoryLegID, t.DepartureStation, t.ArrivalStation, 	
	isnull(carr_map.mappedcarrier ,t.CARRIERCODE) CarrierCode, 
	CONVERT(DATE,t.DepartureDate) as DepartureDate, t.JourneyNumber,
	t.FareClassOfService
	from vw_PassengerJourneySegment t with (nolock)
	LEFT JOIN 
	AAII_CARRIER_MAPPING carr_map
	on carr_map.carriercode = t.carriercode
	and ltrim(RTRIM(carr_map.flightnumber)) = ltrim(RTRIM(t.flightnumber))
	
	where t.BookingStatus = 'HK'
	and t.CarrierCode in (select CarrierCode from ods.Carrier)--('AK','FD','D7','PQ','QZ','JW','Z2','I5','IL','BF')
	
	) pjs
		on bp.PassengerID = pjs.PassengerID
		
left join
	(select distinct BookingID, ProvinceState from ods.BookingContact with (nolock)) bc
	on bp.BookingID = bc.BookingID
left join
	ods.Country cty with (nolock)
		on bp.Nationality = cty.CountryCode	

			
-- The main work here
--18778077
--select * into SAT_JK_Passengers_tmp from #allpassengers
--select MAX(BookingDateUTC) from #allbookings


BEGIN TRY DROP TABLE #SSR1 END TRY BEGIN CATCH END CATCH

select AP.PassengerID, AP.SegmentID,
SUM(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end/ISNULL(ConversionRate,1)) as SSR
into #SSR1
from #allpassengers AP
inner join ods.PassengerFee PF with (nolock)
on AP.PassengerID = PF.PassengerID and AP.InventoryLegID = PF.InventoryLegID
inner join ods.PassengerFeeCharge PFC with (nolock)
on PFC.PassengerID = PF.PassengerID and PFC.FeeNumber = PF.FeeNumber and PFC.ChargeCode = PF.FeeCode
left join dw.CurrencyconversionHistoryDecompressed F with (nolock)	
on AP.BookingDate = F.ConversionDate and AP.CurrencyCode = F.ToCurrencyCode
where PF.InventoryLegID > 0
and FromCurrencyCode = 'MYR'
group by AP.PassengerID, AP.SegmentID
/*
select AP.PassengerID, AP.SegmentID, AP.RecordLocator, AP.JourneyNumber,
SUM(SSRAmount/ISNULL(ConversionRate,1)) as SSR
into #SSR1

from #allpassengers AP
inner join
(select PassengerID, FeeNumber, FeeCode, DepartureStation, ArrivalStation, InventoryLegID
from ods.PassengerFee with (nolock)
where InventoryLegID > 0) PF
on AP.PassengerID = PF.PassengerID and AP.DepartureStation = PF.DepartureStation 
and AP.ArrivalStation = PF.ArrivalStation and AP.InventoryLegID = PF.InventoryLegID

inner join
(select PassengerID, FeeNumber, ChargeCode, 
sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as SSRAmount
from ods.PassengerFeeCharge with (nolock)
group by PassengerID, FeeNumber, ChargeCode) PFC
on PFC.PassengerID = PF.PassengerID and PFC.FeeNumber = PF.FeeNumber
and PFC.ChargeCode = PF.FeeCode

left join
	(select FromCurrencyCode, ToCurrencyCode, ConversionDate, ConversionRate
	from dw.CurrencyconversionHistoryDecompressed with (nolock)	
	where FromCurrencyCode = 'MYR') F
	on AP.BookingDate = F.ConversionDate and AP.CurrencyCode = F.ToCurrencyCode

group by AP.PassengerID, AP.SegmentID, AP.RecordLocator, AP.JourneyNumber
*/

BEGIN TRY DROP TABLE #SSR2 END TRY BEGIN CATCH END CATCH

select AP.PassengerID, AP.SegmentID,
SUM(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end/ISNULL(ConversionRate,1)) as SSR
into #SSR2
from #allpassengers AP
inner join ods.PassengerFee PF with (nolock)
on AP.PassengerID = PF.PassengerID
inner join ods.PassengerFeeCharge PFC with (nolock)
on PFC.PassengerID = PF.PassengerID and PFC.FeeNumber = PF.FeeNumber and PFC.ChargeCode = PF.FeeCode
left join dw.CurrencyconversionHistoryDecompressed F with (nolock)	
on AP.BookingDate = F.ConversionDate and AP.CurrencyCode = F.ToCurrencyCode
where AP.JourneyNumber = 1 and PF.InventoryLegID = 0
and FromCurrencyCode = 'MYR'
group by AP.PassengerID, AP.SegmentID
/*
select AP.PassengerID, AP.SegmentID, AP.RecordLocator, AP.JourneyNumber,
SUM(SSRAmount/ISNULL(ConversionRate,1)) as SSR
into #SSR2
from 
(select * from #allpassengers
where JourneyNumber = 1) AP

inner join
(select PassengerID, FeeNumber, FeeCode
from ods.PassengerFee with (nolock)
where InventoryLegID = 0) PF
on AP.PassengerID = PF.PassengerID 

inner join
(select PassengerID, FeeNumber, ChargeCode, 
sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as SSRAmount
from ods.PassengerFeeCharge with (nolock)
group by PassengerID, FeeNumber, ChargeCode) PFC
on PFC.PassengerID = PF.PassengerID and PFC.FeeNumber = PF.FeeNumber
and PFC.ChargeCode = PF.FeeCode

left join
	(select FromCurrencyCode, ToCurrencyCode, ConversionDate, ConversionRate
	from dw.CurrencyconversionHistoryDecompressed with (nolock)	
	where FromCurrencyCode = 'MYR') F
	on AP.BookingDate = F.ConversionDate and AP.CurrencyCode = F.ToCurrencyCode

group by AP.PassengerID, AP.SegmentID, AP.RecordLocator, AP.JourneyNumber
*/

BEGIN TRY DROP TABLE #StationCountry END TRY BEGIN CATCH END CATCH 

select distinct A.StationCode, A.CountryCode, B.Name as CountryName
into #StationCountry
from ods.Station A
join ods.Country B
on A.CountryCode = B.CountryCode 



--BEGIN TRY DROP TABLE SAT_JK_Analysis_BookingDate END TRY BEGIN CATCH END CATCH
--BEGIN TRY DROP TABLE SAT_JK_Analysis_BookingDate_BF END TRY BEGIN CATCH END CATCH 
--BEGIN TRY DROP TABLE SAT_JK_AAX_Analysis_BookingDate END TRY BEGIN CATCH END CATCH 
--BEGIN TRY DROP TABLE SAT_Temp_AH_Analysis_BookingDate END TRY BEGIN CATCH END CATCH 
--BEGIN TRY DROP TABLE SAT_JK_Analysis_BookingDate_2013 END TRY BEGIN CATCH END CATCH 
BEGIN TRY DROP TABLE SAT_JK_Analysis_BookingDate_insert END TRY BEGIN CATCH END CATCH 

select 
E.DepartureMonth, 
E.DepartureYear, 
E.BookingDate, 
E.BookingMonth,
E.BookingYear,
(case DATEPART(weekday,E.BookingDate)
    When '1' then 'Sunday'
    When '2' then 'Monday'
    When '3' then 'Tuesday'
    When '4' then 'Wednesday'
    when '5' then 'Thursday'
    When '6' then 'Friday'
    When '7' then 'Saturday'
end) as DayOfWeek,		

('W'+CONVERT(VARCHAR(3),DATEPART(week, E.BookingDate))) as WeekNum, 

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
else '>400' end as PurchaseLeadDays_band,
/*
CASE WHEN Age>=0 AND Age<=12 THEN 'Under 12 years old'
	 WHEN Age>=13 AND Age<=19  THEN 'Teens'
	 WHEN Age>=20 AND Age<=24 THEN 'Youth'
	 WHEN Age>=25 AND Age<=29 THEN 'Young Adult'
	 WHEN Age>=30 AND Age<=39 THEN 'Mid Level Execs'
	 WHEN Age>=40 AND Age<=49 THEN 'Mature Affluent'
	 WHEN Age>=50 THEN 'Senior Citizens' ELSE 'Unknown' 
END as Age_band,
*/
CASE WHEN Age>=0 AND Age<=2 THEN '0-2'
	 WHEN Age>=3 AND Age<=5 THEN '3-5'
	 WHEN Age>=6 AND Age<=12 THEN '6-12'
	 WHEN Age>=13 AND Age<=18 THEN '13-18'
	 WHEN Age>=18 AND Age<=24 THEN '18-24'
	 WHEN Age>=25 AND Age<=29 THEN '25-29'
	 WHEN Age>=30 AND Age<=34 THEN '30-34'
	 WHEN Age>=35 AND Age<=39 THEN '35-39'
	 WHEN Age>=40 AND Age<=44 THEN '40-44'
	 WHEN Age>=45 AND Age<=49 THEN '45-49'
	 WHEN Age>=50 AND Age<=54 THEN '50-54'
	 WHEN Age>=55 AND Age<=59 THEN '55-59'
	 WHEN Age>=60 AND Age<=64 THEN '60-64'
	 WHEN Age>=65 AND Age<=69 THEN '65-69'
	 WHEN Age>=70 THEN '>70'
END as Age_Band,
	 
CASE WHEN Age>=0 AND Age<=19 THEN '0-19'
	 WHEN Age>=20 AND Age<=29 THEN '20-29'
	 WHEN Age>=30 AND Age<=39 THEN '30-39'
	 WHEN Age>=40 AND Age<=49 THEN '40-49'
	 WHEN Age>=50 THEN '>49' ELSE 'Unknown' 
END as Age_Band_Jack,

E.Gender,

case when V.InternationalFlag = 1 then 'INT' else 'DOM' end as Flight,

E.CarrierCode, 
E.DepartureStation, 
E.ArrivalStation, 
E.Route, 
SC.CountryName as DepartingCountry,
L.MarketGroup,
LB.MarketGroup as MarketGroup2,
Premium as Cabin,
ProvinceState,
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
end as SalesChannel_new,

(CASE 
	WHEN Paymentmethodcode in ('MS','VS','AX','JB','MC','VI') THEN 'Credit Card'
	WHEN Paymentmethodcode in ('DC','C3','M5','C1','D4','C2','C4','C5','C7','C9','D1','D2','D3','D5','D6','D8','D9','DF','I1','I2','T1','V1','C6','M2','PL') THEN 'Direct Debit'
	WHEN Paymentmethodcode in ('BD','M4','P1','SP','KS','N1','A1','KT','SC') THEN 'Over the Counter'
	WHEN Paymentmethodcode in ('CA') THEN 'Cash'
	Else 'Others' 
END) as PaymentMethod,

E.Nationality, 
case when E.Nationality_Final IS null then 'Unknown'
	 when E.Nationality_Final = ' ' then 'Unknown'
	 when E.Nationality_Final = 'United States of America' then 'United States'
else E.Nationality_Final end as Nationality_Final,
X.PaymentCountry,
E.CurrencyCode, 

count(E.PassengerID) as Guests,

--cast('' as varchar(10)) as Age_Band_Jack,	-- to be used later

--sum(CON.ConversionRate*Q.TotalRevenue) as BaseFare,
SUM(TotalRevenue/ISNULL(ConversionRate,1)) as BaseFare,
--isnull(sum(CON.ConversionRate*T.SSRAmount),0) as SSR,
SUM(SSR1.SSR)+SUM(SSR2.SSR) as SSR,
--SUM(SSR2.SSR) as SSR2,
--isnull(sum(CON.ConversionRate*U.AirportTax),0) as AirportTax,
SUM(AirportTax/ISNULL(ConversionRate,1)) as AirportTax
--BaseFare+SSR+AirportTax as TotalCosts

into 
SAT_JK_Analysis_BookingDate_insert
	--select distinct BookingDate, sum(Guests), sum(BaseFare) from SAT_JK_Analysis_BookingDate group by BookingDate order by BookingDate
	
from
(select * from #allpassengers 
where Route not in ('BOMKUL','CHCKUL','DELKUL','DLCKUL','HRBKUL','IKAKUL','KULLGW','KULORY','KULTSN','MELPER','KULWUH',
'KULBOM','KULCHC','KULDEL','KULDLC','KULHRB','KULIKA','LGWKUL','ORYKUL','TSNKUL','PERMEL','WUHKUL')
)E
	
left join
(select distinct AgentID, OrganizationCode from ods.Agent) G
on E.CreatedAgentID = G.AgentID

left join
(select distinct AgentID, RoleCode
from ods.AgentRole) H
on E.CreatedAgentID = H.AgentID

left join
(select distinct RoleCode, SalesChannelRpt 
from SAT_JK_SalesChannel
where Status = 'EXIST'
) I
on H.RoleCode = I.RoleCode

left join 
(select * from SAT_MarketGroupJK) L	
on E.DepartureStation = L.DepartureStation
and E.ArrivalStation = L.ArrivalStation

left join 
(select * from SAT_MarketGroupJK_DMK) LB
on E.DepartureStation = LB.DepartureStation
and E.ArrivalStation = LB.ArrivalStation

left join
(select distinct O.ReferenceID, O.Paymentmethodcode from
	(select distinct ReferenceID,
	(select top 1 PaymentID from ods.Payment M  with (nolock)where N.ReferenceID = M.ReferenceID order by PaymentID) as TopPaymentID
	from ods.Payment N with (nolock)) W
	inner join
	(select ReferenceID,PaymentID,PaymentMethodCode from ods.Payment with (nolock)) O
	on W.ReferenceID = O.ReferenceID and W.TopPaymentID = O.PaymentID) P
	on P.ReferenceID = E.BookingID

left join 
(select PassengerID, SegmentID,
sum(case when ChargeType = 0 then ISNULL(ChargeAmount,0.00) *1
	  when ChargeType = 8 then ISNULL(ChargeAmount,0.00) *1
	  when ChargeType = 1 then ISNULL(ChargeAmount,0.00) *-1 
	  when ChargeType = 7 then ISNULL(ChargeAmount,0.00) *-1 
end) as TotalRevenue
from ods.PassengerJourneyCharge with (nolock)
where ChargeType in (0,8,1,7,5)
group by PassengerID, SegmentID) Q
on E.PassengerID = Q.PassengerID
and E.SegmentID = Q.SegmentID

left join #SSR1 SSR1
on E.PassengerID = SSR1.PassengerID and E.SegmentID = SSR1.SegmentID 

left join #SSR2 SSR2
on E.PassengerID = SSR2.PassengerID and E.SegmentID = SSR2.SegmentID 
--and E.JourneyNumber = SSR2.JourneyNumber

left join
(select PassengerID, SegmentID,
sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) 
		 else ISNULL(ChargeAmount,0.00) end) AS AirportTax 
from ods.PassengerJourneyCharge
--where ChargeCode in ('APT','APF','ATF','AIF','APTF','APTR','NVF','PHTAX','SVT','VAT','ASC')
where ChargeType in (4,5)
group by PassengerID, SegmentID) U
on E.PassengerID = U.PassengerID
and E.SegmentID = U.SegmentID

left join
(select DepartureStation, ArrivalStation, InternationalFlag
from dw.CityPair) V
on E.DepartureStation = V.DepartureStation and E.ArrivalStation = V.ArrivalStation

left join 
(select CountryCode, Name as PaymentCountry from ods.Country with (nolock)) X
on E.CurrencyCountry = X.CountryCode

join #StationCountry SC on E.DepartureStation = SC.StationCode
/*
LEFT Join 
(
            select FromCurrencyCode, ToCurrencyCode, ConversionRate, VersionStartDate, VersionEndDate
            from ods.CurrencyConversionVersion with (nolock)
            where ToCurrencyCode = 'MYR'
) CON
on CON.FromCurrencyCode = E.CurrencyCode 
AND E.BookingDateUTC between VersionStartDate AND VersionEndDate
*/
left join
	(select FromCurrencyCode, ToCurrencyCode, ConversionDate, ConversionRate
	from dw.CurrencyconversionHistoryDecompressed with (nolock)	
	where FromCurrencyCode = 'MYR') F
	on E.BookingDate = F.ConversionDate and E.CurrencyCode = F.ToCurrencyCode

group by 
E.DepartureMonth, E.DepartureYear, E.BookingDate, E.BookingMonth, E.BookingYear,
(case DATEPART(weekday,E.BookingDate)
    When '1' then 'Sunday'
    When '2' then 'Monday'
    When '3' then 'Tuesday'
    When '4' then 'Wednesday'
    when '5' then 'Thursday'
    When '6' then 'Friday'
    When '7' then 'Saturday'
end),		
('W'+CONVERT(VARCHAR(3),DATEPART(week, E.BookingDate))), 

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
else '>400' end,

CASE WHEN Age>=0 AND Age<=2 THEN '0-2'
	 WHEN Age>=3 AND Age<=5 THEN '3-5'
	 WHEN Age>=6 AND Age<=12 THEN '6-12'
	 WHEN Age>=13 AND Age<=18 THEN '13-18'
	 WHEN Age>=18 AND Age<=24 THEN '18-24'
	 WHEN Age>=25 AND Age<=29 THEN '25-29'
	 WHEN Age>=30 AND Age<=34 THEN '30-34'
	 WHEN Age>=35 AND Age<=39 THEN '35-39'
	 WHEN Age>=40 AND Age<=44 THEN '40-44'
	 WHEN Age>=45 AND Age<=49 THEN '45-49'
	 WHEN Age>=50 AND Age<=54 THEN '50-54'
	 WHEN Age>=55 AND Age<=59 THEN '55-59'
	 WHEN Age>=60 AND Age<=64 THEN '60-64'
	 WHEN Age>=65 AND Age<=69 THEN '65-69'
	 WHEN Age>=70 THEN '>70'
END,

CASE WHEN Age>=0 AND Age<=19 THEN '0-19'
	 WHEN Age>=20 AND Age<=29 THEN '20-29'
	 WHEN Age>=30 AND Age<=39 THEN '30-39'
	 WHEN Age>=40 AND Age<=49 THEN '40-49'
	 WHEN Age>=50 THEN '>49' ELSE 'Unknown' 
END,

E.Gender,
case when V.InternationalFlag = 1 then 'INT' else 'DOM' end,
E.CarrierCode, E.DepartureStation, E.ArrivalStation, E.Route, SC.CountryName, L.MarketGroup, LB.MarketGroup, Premium, ProvinceState,
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
end,

(CASE 
	WHEN Paymentmethodcode in ('MS','VS','AX','JB','MC','VI') THEN 'Credit Card'
	WHEN Paymentmethodcode in ('DC','C3','M5','C1','D4','C2','C4','C5','C7','C9','D1','D2','D3','D5','D6','D8','D9','DF','I1','I2','T1','V1','C6','M2','PL') THEN 'Direct Debit'
	WHEN Paymentmethodcode in ('BD','M4','P1','SP','KS','N1','A1','KT','SC') THEN 'Over the Counter'
	WHEN Paymentmethodcode in ('CA') THEN 'Cash'
	Else 'Others' 
END),
E.Nationality, 
case when E.Nationality_Final IS null then 'Unknown'
	 when E.Nationality_Final = ' ' then 'Unknown'
	 when E.Nationality_Final = 'United States of America' then 'United States'
else E.Nationality_Final end,
X.PaymentCountry,
E.CurrencyCode
;



END


























































GO


