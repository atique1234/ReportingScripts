USE [REZAKWB01]
GO

/****** Object:  StoredProcedure [wb].[SAT_usp_AA_Report_Monthly_Nationality]    Script Date: 10/26/2015 10:27:40 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






















-- =============================================
-- Author:		<Tan Jenn Kok>
-- Create date: <2011-09-21>
-- Description:	<Monthly Nationality Report>
-- =============================================
--ALTER PROCEDURE [wb].[SAT_usp_AA_Report_Monthly_Nationality]

--AS
BEGIN

	SET NOCOUNT ON;
	
DECLARE	@MYDateUTC DATETIME, 
		@STARTDATE DATETIME,
		@ENDDATE DATETIME 
				
select @MYDateUTC  = CONVERT(DATE,DOWNLOADDATE) FROM SAT_AA_L_DOWNLOADDATE	

--select @MYDateUTC  = CONVERT(DATE,'2015-04-20 00:00:00.000')

--SET @STARTDATE= CAST(CONVERT(VARCHAR, DateAdd(day,-31,@MYDateUTC), 101) AS DateTime)

SET @STARTDATE= CAST(CONVERT(VARCHAR, DateAdd(day,-1,@MYDateUTC), 101) AS DateTime)
SET @ENDDATE= CAST(CONVERT(VARCHAR, @MYDateUTC, 101) AS DateTime)

print @STARTDATE
print @ENDDATE

BEGIN


BEGIN TRY DROP TABLE #Passengers END TRY BEGIN CATCH END CATCH 

select A.PassengerID, A.SegmentID, B.BookingID , A.JourneyNumber, BK.CurrencyCode, CONVERT(DATE,BK.BookingDate) as BookingDate,
CONVERT(DATE,DepartureDate) as DepartureDate, Month as DepartureMonth, Year as DepartureYear, A.FareClassOfService,
(Case International When 0 Then 'DOM' When 1 Then 'INT' END) as Flight, 
CarrierCode,Route, A.DepartureStation, A.ArrivalStation,/*
case when PJS.ArrivalStation IS not null then 'Y' else 'N' end as IslandTransfer,
PJS.DepartureStation as DepartureStation2, PJS.ArrivalStation as ArrivalStation2,*/
/* DepartureTime, ArrivalTime,*/ Nationality, 
case when (Passport = 'OT' OR Passport IS null) then B.Nationality else Passport end as Passport,
Nationality_DESC
into #Passengers
from 
(select PassengerID, SegmentID, CarrierCode, JourneyNumber, International, DepartureDate, DATENAME(M,DepartureDate) as Month, 
Year(DepartureDate) as Year,Datepart(MM,DepartureDate)as Month_1,
(DepartureStation + ArrivalStation) as Route, DepartureStation, ArrivalStation, FareClassOfService 
from vw_PassengerJourneySegment with (nolock)	
where Bookingstatus = 'HK'
and (DepartureDate >= @STARTDATE and DepartureDate < @MYDateUTC)--= @STARTDATE 
--and (DepartureDate >= '2013-11-01' and DepartureDate < '2014-05-08')--= @STARTDATE 
and CarrierCode in (select CarrierCode from ods.Carrier)
--and PassengerID = 167270425
) A 
join ods.BookingPassenger B with (nolock)
on A.PassengerID = B.PassengerID
inner join 
(select BookingID, CurrencyCode, DATEADD(HH,+8,BookingDate) as BookingDate
from ods.Booking with (nolock, index(Booking_BookingDate_IDX))
where Status in (2,3)) BK
on B.BookingID = BK.BookingID
left join 
(select distinct PassengerID, Nationality as Passport 
from ods.PassengerTravelDoc with (nolock)) C
on A.PassengerID = C.PassengerID
left join
(select CountryCode, Name as Nationality_DESC
from ods.Country with (nolock)) D
on B.Nationality = D.CountryCode

--select * from vw_PassengerJourneySegment where FareClassOfService in ('PF','LF','UF','TF','QF','MF','YF')

BEGIN TRY DROP TABLE #IslandJourney1 END TRY BEGIN CATCH END CATCH

select PJS.PassengerID, PJS.SegmentID, PJS.JourneyNumber, PJS.CarrierCode, PJS.DepartureStation, PJS.ArrivalStation
into #IslandJourney1
from #Passengers PSG
inner join
(select PassengerID, SegmentID, JourneyNumber, CarrierCode, DepartureStation, ArrivalStation
from vw_PassengerJourneySegment with (nolock)
--where PassengerID in (175038310,175038312,175038315)
where BookingStatus = 'HK'
and CarrierCode = 'BF'
and JourneyNumber = 1
) PJS
on PJS.PassengerID = PSG.PassengerID


BEGIN TRY DROP TABLE #IslandJourney2 END TRY BEGIN CATCH END CATCH

select PJS.PassengerID, PJS.SegmentID, PJS.JourneyNumber, PJS.CarrierCode, PJS.DepartureStation, PJS.ArrivalStation
into #IslandJourney2
from #Passengers PSG
inner join
(select PassengerID, SegmentID, JourneyNumber, CarrierCode, DepartureStation, ArrivalStation
from vw_PassengerJourneySegment with (nolock)
--where PassengerID in (175038310,175038312,175038315)
where BookingStatus = 'HK'
and CarrierCode = 'BF'
and JourneyNumber = 2
) PJS
on PJS.PassengerID = PSG.PassengerID



BEGIN TRY DROP TABLE SAT_Temp_Monthly_Nationality_Rpt END TRY BEGIN CATCH END CATCH
BEGIN TRY DROP TABLE SAT_JK_Monthly_Nationality_Rpt END TRY BEGIN CATCH END CATCH 

select DepartureMonth, DepartureYear, Flight, 
A.CarrierCode,Route, A.DepartureStation, A.ArrivalStation,
/* DepartureTime, ArrivalTime,*/ Nationality, 
Passport,
Nationality_DESC, 
case when A.FareClassOfService in ('PF','LF','UF','TF','QF','MF','YF','HF') then 'Hi-Flyer' else NULL end as Hi_Flyer,
case when (IJ1.CarrierCode = 'BF' OR IJ2.CarrierCode = 'BF') then 'Y' else 'N' end as IslandTransfer,
case when IJ1.DepartureStation IS not null then IJ1.DepartureStation 
	 when IJ2.DepartureStation IS not null then IJ2.DepartureStation 
else NULL end as DepartureStation2, 
case when IJ1.ArrivalStation IS not null then IJ1.ArrivalStation 
	 when IJ2.ArrivalStation IS not null then IJ2.ArrivalStation 
else NULL end as ArrivalStation2,
count(A.PassengerID) as Guests, 
--sum(ods.ConvertCurrency(Q.TotalBaseFare, A.CurrencyCode, 'MYR', A.BookingDate)) as BaseFare1,
SUM(Q.TotalBaseFare/ISNULL(ConversionRate,1)) as BaseFare
into SAT_JK_Monthly_Nationality_Rpt--26982626
from 
#Passengers A
left join
(select PassengerID, SegmentID,
sum(case when ChargeType = 0 then ISNULL(ChargeAmount,0.00) *1
	  when ChargeType = 8 then ISNULL(ChargeAmount,0.00) *1
	  when ChargeType = 1 then ISNULL(ChargeAmount,0.00) *-1 
	  when ChargeType = 7 then ISNULL(ChargeAmount,0.00) *-1 
end) as TotalBaseFare
from ods.PassengerJourneyCharge with (nolock)
where ChargeType in (0,8,1,7)
group by PassengerID, SegmentID) Q
on A.PassengerID = Q.PassengerID
and A.SegmentID = Q.SegmentID

left join #IslandJourney1 IJ1 
on A.PassengerID = IJ1.PassengerID and A.JourneyNumber = IJ1.JourneyNumber 
and A.ArrivalStation = IJ1.DepartureStation

left join #IslandJourney2 IJ2 
on A.PassengerID = IJ2.PassengerID and A.JourneyNumber = IJ2.JourneyNumber 
and A.DepartureStation = IJ2.ArrivalStation

left join
	(select FromCurrencyCode, ToCurrencyCode, ConversionDate, ConversionRate
	from wb.CurrencyConversionHistoryDecompressed with (nolock)	
	where FromCurrencyCode = 'MYR') CON
	on A.BookingDate = CON.ConversionDate and A.CurrencyCode = CON.ToCurrencyCode

group by
DepartureMonth, DepartureYear, Flight, 
A.CarrierCode,Route, A.DepartureStation, A.ArrivalStation,
/* DepartureTime, ArrivalTime,*/ Nationality, 
Passport,
Nationality_DESC,  
case when A.FareClassOfService in ('PF','LF','UF','TF','QF','MF','YF','HF') then 'Hi-Flyer' else NULL end,
case when (IJ1.CarrierCode = 'BF' OR IJ2.CarrierCode = 'BF') then 'Y' else 'N' end,
case when IJ1.DepartureStation IS not null then IJ1.DepartureStation 
	 when IJ2.DepartureStation IS not null then IJ2.DepartureStation 
else NULL end, 
case when IJ1.ArrivalStation IS not null then IJ1.ArrivalStation 
	 when IJ2.ArrivalStation IS not null then IJ2.ArrivalStation 
else NULL end

--select SUM(Guests), SUM(BaseFare), SUM(BaseFare1) from SAT_TEMP_Monthly_Nationality_Rpt


BEGIN TRY DROP TABLE SAT_JK_Monthly_Nationality_Rpt_Export END TRY BEGIN CATCH END CATCH 
BEGIN TRY DROP TABLE SAT_TEMP_Monthly_Nationality_Rpt_2013 END TRY BEGIN CATCH END CATCH 
BEGIN TRY DROP TABLE SAT_JK_Monthly_Nationality_Rpt_2013 END TRY BEGIN CATCH END CATCH 
BEGIN TRY DROP TABLE SAT_JK_Monthly_Nationality_Rpt_2013_oct END TRY BEGIN CATCH END CATCH 
BEGIN TRY DROP TABLE SAT_JK_Monthly_Nationality_Rpt_2013_nov END TRY BEGIN CATCH END CATCH 


select DepartureMonth,DepartureYear,Flight,CarrierCode,Route,DepartureStation,ArrivalStation,Nationality,
Region, SubRegion,
Passport,Nationality_DESC,Hi_Flyer, IslandTransfer,DepartureStation2,ArrivalStation2,
SUM(Guests) as Guests,
SUM(BaseFare) as BaseFare
into SAT_JK_Monthly_Nationality_Rpt_Export
from SAT_JK_Monthly_Nationality_Rpt A
left join SAT_JK_Country_Region B
on A.Nationality = B.CountryCode
group by 
DepartureMonth,DepartureYear,Flight,CarrierCode,Route,DepartureStation,ArrivalStation,Nationality,
Region, SubRegion,
Passport,Nationality_DESC,Hi_Flyer, IslandTransfer,DepartureStation2,ArrivalStation2


/*
select DepartureYear, DepartureMonth,
count(PassengerID) as Guests
from #Passengers
where ((DepartureYear = 2013 and DepartureMonth in ('November','December'))
OR (DepartureYear = 2014))
group by DepartureYear, DepartureMonth
order by DepartureYear, DepartureMonth

select DepartureYear, DepartureMonth,
sum(Total_Passengers) as Total
from SAT_CRM_Ramani2
group by DepartureYear, DepartureMonth
order by DepartureYear, DepartureMonth

sp_rename SAT_JK_Monthly_Nationality_Rpt_Export,SAT_JK_Monthly_Nationality_Rpt_Export_20140507
*/

BEGIN TRY DROP TABLE SAT_TEMP_Monthly_Nationality_Rpt END TRY BEGIN CATCH END CATCH
BEGIN TRY DROP TABLE SAT_JK_Monthly_Nationality_Rpt END TRY BEGIN CATCH END CATCH  
BEGIN TRY DROP TABLE #Passengers END TRY BEGIN CATCH END CATCH 

END


END





















GO


