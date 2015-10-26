USE [REZAKWB01]
GO

/****** Object:  StoredProcedure [wb].[SAT_Update_Monthly_FlyThru_v2]    Script Date: 10/23/2015 12:44:37 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO












-- =============================================
-- Author:		<Matthew Oh>
-- Create date: <2012-04-24,,>
-- Description:	<AAX (Network Planning) - Monthly Flythru Pax>
-- =============================================
--ALTER PROCEDURE [wb].[SAT_Update_Monthly_FlyThru_v2]

--AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
		
	DECLARE @departureStart     datetime,
			@departureEnd    datetime,
			@PurchaseStart    datetime,
			@PurchaseEnd    datetime
/*
  	SET @PurchaseStart  =CAST(CONVERT(VARCHAR, DATEADD(YY, -1, DATEADD(s, 1,DATEADD(mm, DATEDIFF(m,0,DateAdd(month,0,GETDATE())),0))), 101) AS DateTime)
  	SET @PurchaseEnd	=CAST(CONVERT(VARCHAR, DATEADD(s, 1,DATEADD(mm, DATEDIFF(m,0,DateAdd(month,0,GETDATE())),0)), 101) AS DateTime)
 --	SET @DepartureStart  =CAST(CONVERT(VARCHAR, DATEADD(YEAR, DATEDIFF(YEAR, 0, GETDATE()), 0), 101) as datetime)
	SET @DepartureStart  = CAST(CONVERT(VARCHAR, DATEADD(YY, -1, DATEADD(s, 1,DATEADD(mm, DATEDIFF(m,0,DateAdd(month,0,GETDATE())),0))), 101) AS DateTime)
  	SET @DepartureEnd	=CAST(CONVERT(VARCHAR, DATEADD(YY, 1, DATEADD(s, 1,DATEADD(mm, DATEDIFF(m,0,DateAdd(month,0,GETDATE())),0))), 101) AS DateTime)
	print @PurchaseStart 
	print @PurchaseEnd
	print @DepartureStart 
	print @DepartureEnd
*/
  	SET @PurchaseStart			=CAST(CONVERT(VARCHAR, DATEADD(YY, -1, DATEADD(s, 1,DATEADD(mm, DATEDIFF(m,0,DateAdd(month,0,GETDATE())),0))), 101) AS DateTime)
  	SET @PurchaseEnd			=CAST(CONVERT(VARCHAR, DATEADD(wk, DATEDIFF(wk, 6, GETDATE()), 7), 101) as datetime) --CAST(CONVERT(VARCHAR, DATEADD(s, 1,DATEADD(mm, DATEDIFF(m,0,DateAdd(month,0,GETDATE())),0)), 101) AS DateTime)
 	--SET @PreviousPurchaseEnd	=CAST(CONVERT(VARCHAR, DATEADD(wk, DATEDIFF(wk, 6, GETDATE()), 0), 101) as datetime)--CAST(CONVERT(VARCHAR, DATEADD(s, 1,DATEADD(mm, DATEDIFF(m,0,DateAdd(month,-12,GETDATE())),0)), 101) AS DateTime)
 	SET @DepartureStart			=CAST(CONVERT(VARCHAR, DATEADD(YEAR, DATEDIFF(YEAR, 0, GETDATE()), 0), 101) as datetime)
  	SET @DepartureEnd			=CAST(CONVERT(VARCHAR, DATEADD(YY, 1, DATEADD(wk, DATEDIFF(wk, 6, GETDATE()), 7)), 101) AS DateTime)--CAST(CONVERT(VARCHAR, DATEADD(YY, 1, DATEADD(s, 1,DATEADD(mm, DATEDIFF(m,0,DateAdd(month,0,GETDATE())),0))), 101) AS DateTime)
  	
	print @PurchaseStart 
	print @PurchaseEnd
	--print @PreviousPurchaseEnd
	print @DepartureStart 
	print @DepartureEnd

	--*Seats Sold and Base Fare RM*--
	
	BEGIN TRY TRUNCATE TABLE #SeatsSold_FlyThru_BaseRevRM DROP TABLE #SeatsSold_FlyThru_BaseRevRM END TRY BEGIN CATCH END CATCH 
	select A.PassengerID, A.SegmentID, SegmentSTD, CarrierCode, A.FlightNumber, DepartureStation, ArrivalStation,
	JourneyNumber, SegmentNumber, CurrencyCode, CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) as PurchaseDate,
	sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0) + ISNULL(Connecting_Amt,0))/ConversionRate) as BaseFare_RM,
	sum((ISNULL(Fuel_Amt,0))/ConversionRate) as FuelSurcharge_RM,
	sum((ISNULL(ThruFare_Amt,0))/ConversionRate) as ThruFare_RM
	
	into #SeatsSold_FlyThru_BaseRevRM
	from
		(select t.PassengerID, t.SegmentID, t.SegmentSTD, 
		isnull(carr_map.mappedcarrier ,t.CARRIERCODE) CarrierCode, 
		t.FlightNumber, t.DepartureStation, t.ArrivalStation, t.CurrencyCode,
		t.CreatedDate, t.JourneyNumber, t.SegmentNumber
		
		 from 
		(select PassengerID, SegmentID, SegmentSTD, CarrierCode, /*new*/FlightNumber, DepartureStation, ArrivalStation, CurrencyCode,
			CreatedDate, JourneyNumber, SegmentNumber
			from vw_PassengerJourneySegment
			where BookingStatus = 'HK'
			and DepartureDate between @DepartureStart and @departureEnd
			and DATEADD(HH,8,CreatedDate) < @PurchaseEnd
			and FareJourneyType = 4
		) t
		LEFT JOIN 
		AAII_CARRIER_MAPPING carr_map
		on carr_map.carriercode = t.carriercode
		and ltrim(RTRIM(carr_map.flightnumber)) = ltrim(RTRIM(t.flightnumber))
		
		) A
	left join
		(select PassengerID, SegmentID, --(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as Fare_Amt
		case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end as Fare_Amt
		from
			(select PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge
			where ChargeType = '0') C
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix) D
			on C.ChargeType = D.ChargeTypeID) E
		on A.SegmentID = E.SegmentID and A.PassengerID = E.PassengerID
	left join 
		(select PassengerID, SegmentID, --(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as Disc_Amt
		case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end as Disc_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge
			where ChargeType = '1') F
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix) G
			on F.ChargeType = G.ChargeTypeID) H
		on A.SegmentID = H.SegmentID and A.PassengerID = H.PassengerID
	left join 
		(select PassengerID, SegmentID, --(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as Promo_Amt
		case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end as Promo_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge
			where ChargeType = '7') I	
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix) J
			on I.ChargeType = J.ChargeTypeID) K		
		on A.SegmentID = K.SegmentID and A.PassengerID = K.PassengerID 	
	left join 
		(select PassengerID, SegmentID, --(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as Connecting_Amt
		case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end as Connecting_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge
			where ChargeType = '8') O	
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix) P
			on O.ChargeType = P.ChargeTypeID) Q		
		on A.SegmentID = Q.SegmentID and A.PassengerID = Q.PassengerID 
	left join 
		(select PassengerID, SegmentID, --(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as Fuel_Amt
		case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end as Fuel_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge
			where ChargeCode in ('FUEL','FUEX')) R	
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix) S
			on R.ChargeType = S.ChargeTypeID)T		
		on A.SegmentID = T.SegmentID and A.PassengerID = T.PassengerID 		
	
	left join 
		(select PassengerID, SegmentID, --(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as Fuel_Amt
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as ThruFare_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge
			where ChargeCode in ('THRU')) THRU1	
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix) THRU2
			on THRU1.ChargeType = THRU2.ChargeTypeID
		group by PassengerID, SegmentID	
		)THRU		
		on A.SegmentID = THRU.SegmentID and A.PassengerID = THRU.PassengerID 
				
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from wb.CurrencyConversionHistoryDeCompressed with (nolock)
		where FromCurrencyCode = 'MYR') L
		on L.ToCurrencyCode = A.CurrencyCode 
		and CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = L.ConversionDate
	group by A.PassengerID, A.SegmentID, JourneyNumber, SegmentNumber, CurrencyCode, SegmentSTD, 
	CarrierCode, A.FlightNumber, DepartureStation, ArrivalStation,CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime)

	--select top 100* from #SeatsSold_FlyThru_BaseRevRM

	--*Ancillary *--

	BEGIN TRY TRUNCATE TABLE #FlyThru_Ancillaries DROP TABLE #FlyThru_Ancillaries END TRY BEGIN CATCH END CATCH
	Select distinct A.PassengerId,B.FeeNumber,B.FeeCode,B.DepartureDate,B.CarrierCode,B.FlightNumber,B.DepartureStation,B.ArrivalStation,
	C.CurrencyCode, C.CreatedDate, (C.ChargeAmount * D.PositiveNegativeFlag) As ChargeAmount
	Into #FlyThru_Ancillaries
	From #SeatsSold_FlyThru_BaseRevRM A 
	left Join vw_PassengerFee B  With (NoLock) On A.PassengerId = B.PassengerId 
	left Join ods.PassengerFeeCharge C With (NoLock)  On B.PassengerId = C.PassengerId And B.FeeNumber = C.FeeNumber
	left Join dw.ChargeTypeMatrix D With (NoLock) On C.ChargeType = D.ChargeTypeID
	
	
	
	--*Ancillary RM*--
		
	BEGIN TRY TRUNCATE TABLE #FlyThru_Ancillaries_RM DROP TABLE #FlyThru_Ancillaries_RM END TRY BEGIN CATCH END CATCH
	Select A.PassengerId,A.DepartureDate,A.CarrierCode,A.FlightNumber,A.DepartureStation+A.ArrivalStation as route,A.CurrencyCode,
	Sum(ISNULL(A.ChargeAmount,0) / B.ConversionRate) AS AncillaryAmount_MYR
	Into #FlyThru_Ancillaries_RM
	from
		(select PassengerId,DepartureDate,CarrierCode,FlightNumber,DepartureStation,ArrivalStation,CurrencyCode,
		ChargeAmount, CreatedDate
		from #FlyThru_Ancillaries
		where CarrierCode <> ' ' 
		and Flightnumber <> ' ' 
		and DepartureStation <> ' ' 
		and ArrivalStation <> ' ') A 
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from wb.CurrencyConversionHistoryDeCompressed
		where FromCurrencyCode = 'MYR') B
		on B.ToCurrencyCode = A.CurrencyCode 
		and CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = B.ConversionDate
	group by A.PassengerId,A.DepartureDate,A.CarrierCode,A.FlightNumber,A.DepartureStation,A.ArrivalStation, A.CurrencyCode
	
		
	--select top 100* from #SeatsSold_FlyThru_BaseRevRM order by PassengerID
	--select top 100* from #FlyThru_Ancillaries_RM
		
		
	--*Ancillary merge*--	
	
	BEGIN TRY TRUNCATE TABLE #FlyThru_all_RM DROP TABLE #FlyThru_all_RM END TRY BEGIN CATCH END CATCH 
	select RecordLocator, A.PassengerID, SegmentID, JourneyNumber, SegmentNumber, PurchaseDate, A.DepartureDate, SegmentSTD, A.DepartureStation, A.ArrivalStation, 
	E.Nationality, DOB, CurrencyCode, G.Country_Booking,
	A.CarrierCode, A.FlightNumber, BaseFare_RM, FuelSurcharge_RM, ISNULL(AncillaryAmount_MYR,0) as AncillaryAmount_RM, /*new*/ThruFare_RM	
	into #FlyThru_all_RM
	from
		(select PassengerID, SegmentID, SegmentSTD, CAST(CONVERT(VARCHAR,SegmentSTD,110) as datetime) as DepartureDate,
		PurchaseDate, CarrierCode, /*new*/FlightNumber, DepartureStation, ArrivalStation, JourneyNumber, SegmentNumber, CurrencyCode,
		BaseFare_RM, FuelSurcharge_RM, /*new*/ThruFare_RM
		from #SeatsSold_FlyThru_BaseRevRM) A
	left join
		(select PassengerID, CarrierCode, Departuredate, SUBSTRING(route,1,3) as DepartureStation, SUBSTRING(Route,4,3) as ArrivalStation,
		AncillaryAmount_MYR
		from #FlyThru_Ancillaries_RM) B
		on A.PassengerID = B.PassengerID and A.DepartureStation = B.DepartureStation and A.Carriercode = B.CarrierCode
		and A.ArrivalStation = B.ArrivalStation and A.DepartureDate = B.DepartureDate
	left join
		(select PassengerID, BookingID, Nationality, DOB
		from ods.BookingPassenger) c
		on A.PassengerID = C.PassengerID
	left join
		(select BookingID, RecordLocator
		from ods.Booking) D
		on C.BookingID = D.BookingID
	left join
		(select CountryCode, Name as Nationality
		from ods.Country) E
		on C.Nationality = E.CountryCode		
	left join
		(select bookingID, CountryCode
		from ods.BookingContact) F
		on C.BookingID = F.BookingID
	left join
		(select CountryCode, Name as Country_Booking
		from ods.Country) G
		on F.CountryCode = G.CountryCode	
	--where A.CarrierCode in ('AK','FD','QZ','D7','PQ','JW','Z2')		
	where A.CarrierCode in ('AK','FD','QZ','D7','PQ','JW','Z2','XJ','XT','I5')
	--order by PassengerID	

	--select count(*) from #_Temp_FlyThru_All_RM
	
	
	
	--*Fly Thru merging*---
	
	BEGIN TRY TRUNCATE TABLE #_Temp_FlyThru_All_RM DROP TABLE #_Temp_FlyThru_All_RM END TRY BEGIN CATCH END CATCH 
	select RecordLocator, B.PassengerID, PurchaseDate, B.DepartureDate, 
	B.DepartureStation+B.ArrivalStation as Route_Leg1, B.CarrierCode as CarrierCode_Leg1, /*new*/B.FlightNumber as FlightNumber_Leg1,
	C.DepartureStation+C.ArrivalStation as Route_Leg2, C.CarrierCode as CarrierCode_Leg2, /*new*/C.FlightNumber as FlightNumber_Leg2,
	BaseFare_Leg1_RM, FuelSurcharge_Leg1_RM, AncillaryAmount_Leg1_RM, /*new*/ThruFare_Leg1_RM,
	BaseFare_Leg2_RM, FuelSurcharge_Leg2_RM, AncillaryAmount_Leg2_RM, /*new*/ThruFare_Leg2_RM,
	Nationality, Country_Booking, DATEDIFF(YY, DOB, B.DepartureDate) as Age, CurrencyCode
	into #_Temp_FlyThru_All_RM
	from	
		(select RecordLocator, PassengerID, SegmentID, PurchaseDate, DepartureDate, SegmentSTD, CarrierCode, /*new*/FlightNumber, CurrencyCode,
		DepartureStation, ArrivalStation, Nationality, Country_Booking, DOB,
		BaseFare_RM as BaseFare_Leg1_RM, FuelSurcharge_RM as FuelSurcharge_Leg1_RM, AncillaryAmount_RM as AncillaryAmount_Leg1_RM,
		/*new*/ThruFare_RM as ThruFare_Leg1_RM
		from #FlyThru_all_RM
		where JourneyNumber = 1
		and SegmentNumber = 1) B
	left join
		(select PassengerID, SegmentID, DepartureDate, SegmentSTD, CarrierCode, /*new*/FlightNumber, 
		DepartureStation, ArrivalStation,
		BaseFare_RM as BaseFare_Leg2_RM, FuelSurcharge_RM as FuelSurcharge_Leg2_RM, 
		AncillaryAmount_RM as AncillaryAmount_Leg2_RM,
		/*new*/ThruFare_RM as ThruFare_Leg2_RM
		from #FlyThru_all_RM
		where JourneyNumber = 1
		and SegmentNumber = 2) C
		on B.PassengerID = C.PassengerID and B.ArrivalStation = C.DepartureStation
	union		
	select RecordLocator, B.PassengerID, PurchaseDate, B.DepartureDate, 
	B.DepartureStation+B.ArrivalStation as Route_Leg1, B.CarrierCode as CarrierCode_Leg1,/*new*/B.FlightNumber as FlightNumber_Leg1,
	C.DepartureStation+C.ArrivalStation as Route_Leg2, C.CarrierCode as CarrierCode_Leg2,/*new*/C.FlightNumber as FlightNumber_Leg2,
	BaseFare_Leg1_RM, FuelSurcharge_Leg1_RM, AncillaryAmount_Leg1_RM, /*new*/ThruFare_Leg1_RM,
	BaseFare_Leg2_RM, FuelSurcharge_Leg2_RM, AncillaryAmount_Leg2_RM, /*new*/ThruFare_Leg2_RM,
	Nationality, Country_Booking, DATEDIFF(YY, DOB, B.DepartureDate) as Age, CurrencyCode
	from	
		(select RecordLocator, PassengerID, SegmentID, PurchaseDate, DepartureDate, SegmentSTD, CarrierCode,  /*new*/FlightNumber,CurrencyCode,
		DepartureStation, ArrivalStation, Nationality, Country_Booking, DOB,
		BaseFare_RM as BaseFare_Leg1_RM, FuelSurcharge_RM as FuelSurcharge_Leg1_RM, AncillaryAmount_RM as AncillaryAmount_Leg1_RM,
		/*new*/ThruFare_RM as ThruFare_Leg1_RM
		from #FlyThru_all_RM
		where JourneyNumber = 2
		and SegmentNumber = 1) B
	left join
		(select PassengerID, SegmentID, DepartureDate, SegmentSTD, CarrierCode, /*new*/FlightNumber, 
		DepartureStation, ArrivalStation,
		BaseFare_RM as BaseFare_Leg2_RM, FuelSurcharge_RM as FuelSurcharge_Leg2_RM, 
		AncillaryAmount_RM as AncillaryAmount_Leg2_RM,
		/*new*/ThruFare_RM as ThruFare_Leg2_RM
		from #FlyThru_all_RM
		where JourneyNumber = 2
		and SegmentNumber = 2) C
		on B.PassengerID = C.PassengerID and B.ArrivalStation = C.DepartureStation

		
	--*Final Aggregation*--
	
		
	BEGIN TRY TRUNCATE TABLE #SAT_AH_Temp_FlyThru_All_v2 DROP TABLE #SAT_AH_Temp_FlyThru_All_v2 END TRY BEGIN CATCH END CATCH 
	select @PurchaseEnd as CapturedDate, count(RecordLocator) as Booking, COUNT(PAssengerID) as SeatsSold, Route_Leg1, Route_Leg2, CarrierCode_Leg1, /*new*/FlightNumber_Leg1, CarrierCode_Leg2, /*new*/FlightNumber_Leg2,
	SUBSTRING(Route_Leg1,1,3)+'-'+SUBSTRING(Route_Leg2,4,3) as Route, YEAR(DepartureDate) as DepartureYear, 
	DATENAME(MM,DepartureDate) as DepartureMonth, MONTH(DEpartureDate) as MonthNum,
	YEAR(PurchaseDate) as PurchaseYear, DATENAME(MM,PurchaseDate) as PurchaseMonth,
	SUM(BaseFare_Leg1_RM) as BaseFare_Leg1_RM, SUM(FuelSurcharge_Leg1_RM) as FuelSurcharge_Leg1_RM, SUM(AncillaryAmount_Leg1_RM) as AncillaryAmount_Leg1_RM, /*new*/SUM(ThruFare_Leg1_RM) as ThruFare_Leg1_RM,
	SUM(BaseFare_Leg2_RM) as BaseFare_Leg2_RM, SUM(FuelSurcharge_Leg2_RM) as FuelSurcharge_Leg2_RM, SUM(AncillaryAmount_Leg2_RM) as AncillaryAmount_Leg2_RM, /*new*/SUM(ThruFare_Leg2_RM) as ThruFare_Leg2_RM,
	SUM(BaseFare_Leg1_RM + BaseFare_Leg2_RM) as BaseFare_RM,
	SUM(FuelSurcharge_Leg1_RM+FuelSurcharge_Leg2_RM) as FuelSurcharge_RM,
	SUM(AncillaryAmount_Leg1_RM+AncillaryAmount_Leg2_RM) as AncillaryAmount_RM,
	/*new*/SUM(ThruFare_Leg1_RM+ThruFare_Leg2_RM) as ThruFare_RM,
	SUM(BaseFare_Leg1_RM + BaseFare_Leg2_RM+FuelSurcharge_Leg1_RM+FuelSurcharge_Leg2_RM+AncillaryAmount_Leg1_RM+AncillaryAmount_Leg2_RM+/*new*/ThruFare_Leg1_RM+ThruFare_Leg2_RM) as TotalRevenue_RM,
	Nationality, CurrencyCode, Country_Booking, 
	AgeBand = 	case when age between 0 and 12 then 'Under12'
	when age between 13 and 19 then 'Teens'
	when age between 20 and 24 then 'Youth'
	when age between 25 and 29 then 'YoungAdult'
	when age between 30 and 39 then 'MidLevelExecs'
	when age between 40 and 60 then 'MatureAffluent'
	when age between 60 and 100 then '>60' Else 'Unknown' End
	into #SAT_AH_Temp_FlyThru_All_v2
	from #_Temp_FlyThru_All_RM
	where route_Leg2 is not null
	group by Route_Leg1, Route_Leg2, CarrierCode_Leg1, /*new*/FlightNumber_Leg1, CarrierCode_Leg2, /*new*/FlightNumber_Leg2,
	SUBSTRING(Route_Leg1,1,3)+'-'+SUBSTRING(Route_Leg2,4,3), age, Nationality, CurrencyCode,
	YEar(DepartureDate), DATENAME(MM,DepartureDate), MONTH(DEpartureDate),
	YEAR(PurchaseDate), DATENAME(MM,PurchaseDate), Country_Booking
	
	
	BEGIN TRY TRUNCATE TABLE #SAT_AH_Temp_FlyThru_All_v2_tmp DROP TABLE #SAT_AH_Temp_FlyThru_All_v2_tmp END TRY BEGIN CATCH END CATCH 
	select CapturedDate, sum(Booking) as Booking, SUM(SeatsSold) as SeatsSold, Route_Leg1, Route_Leg2, CarrierCode_Leg1, /*new*/FlightNumber_Leg1, CarrierCode_Leg2, /*new*/FlightNumber_Leg2,
	Route, DepartureYear, DepartureMonth, MonthNum, PurchaseYear, PurchaseMonth,
	sum(BaseFare_Leg1_RM) as BaseFare_Leg1_RM, sum(FuelSurcharge_Leg1_RM) as FuelSurcharge_Leg1_RM, sum(AncillaryAmount_Leg1_RM) as AncillaryAmount_Leg1_RM, /*new*/SUM(ThruFare_Leg1_RM) as ThruFare_Leg1_RM,
	sum(BaseFare_Leg2_RM) as BaseFare_Leg2_RM, sum(FuelSurcharge_Leg2_RM) as FuelSurcharge_Leg2_RM, sum(AncillaryAmount_Leg2_RM) as AncillaryAmount_Leg2_RM, /*new*/SUM(ThruFare_Leg2_RM) as ThruFare_Leg2_RM,
	sum(BaseFare_RM) as BaseFare_RM, sum(FuelSurcharge_RM) AS FuelSurcharge_RM, sum(AncillaryAmount_RM) as AncillaryAmount_RM, 
	/*new*/sum(ThruFare_RM) as ThruFare_RM,
	sum(TotalRevenue_RM) as TotalRevenue_RM,
	Nationality, CurrencyCode, Country_Booking, AgeBAnd
	into #SAT_AH_Temp_FlyThru_All_v2_tmp
	from #SAT_AH_Temp_FlyThru_All_v2
	where route_Leg2 is not null
	group by CapturedDate, Route_Leg1, Route_Leg2, CarrierCode_Leg1, /*new*/FlightNumber_Leg1, CarrierCode_Leg2, /*new*/FlightNumber_Leg2,
	Route, DepartureYear, DepartureMonth, MonthNum, PurchaseYear, PurchaseMonth, Nationality, CurrencyCode, Country_Booking,AgeBAnd
	
			
	--select COUNT(*) from SAT_AH_Temp_FlyThru_All_v2_tmp
	BEGIN TRY TRUNCATE TABLE SAT_AH_Temp_FlyThru_All_v2 DROP TABLE SAT_AH_Temp_FlyThru_All_v2 END TRY BEGIN CATCH END CATCH 
	select CapturedDate,Booking,SeatsSold,Route_Leg1,Route_Leg2,
	B.MarketGroup as ODPair, 
	C.CountryCode as Orig_Country,
	D.CountryCode as Des_Country,
	CarrierCode_Leg1, /*new*/FlightNumber_Leg1, CarrierCode_Leg2, /*new*/FlightNumber_Leg2,
	/*new*/ CarrierCode_Leg1 + '-' + CarrierCode_Leg2 CarrierCode_Leg1toLeg2,
	Route,DepartureYear,DepartureMonth,MonthNum,
	PurchaseYear,PurchaseMonth,
	BaseFare_Leg1_RM,FuelSurcharge_Leg1_RM,AncillaryAmount_Leg1_RM,/*new*/ThruFare_Leg1_RM,
	BaseFare_Leg2_RM,FuelSurcharge_Leg2_RM,AncillaryAmount_Leg2_RM,/*new*/ThruFare_Leg2_RM,
	BaseFare_RM,FuelSurcharge_RM,AncillaryAmount_RM,/*new*/ThruFare_RM,TotalRevenue_RM,Nationality,A.CurrencyCode,Country_Booking,
	AgeBAnd
	into SAT_AH_Temp_FlyThru_All_v2
	from #SAT_AH_Temp_FlyThru_All_v2_tmp A
	left join SAT_MarketGroupJK B on LEFT(A.Route,3) = B.DepartureStation and RIGHT(A.Route,3) = B.ArrivalStation
	left join ods.Station C on LEFT(A.Route,3) = C.StationCode
	left join ods.Station D on RIGHT(A.Route,3) = D.StationCode
	
	BEGIN TRY TRUNCATE TABLE #SAT_AH_Temp_FlyThru_All_v2_tmp DROP TABLE #SAT_AH_Temp_FlyThru_All_v2_tmp END TRY BEGIN CATCH END CATCH 
	--select COUNT(*) from SAT_AH_Temp_FlyThru_All_v2
	
	
	
	BEGIN TRY TRUNCATE TABLE #Temp_FlyThru_All_v3 DROP TABLE #_Temp_FlyThru_All_v3 END TRY BEGIN CATCH END CATCH 
	select @PurchaseEnd as CapturedDate, count(RecordLocator) as Booking, COUNT(PAssengerID) as SeatsSold, Route_Leg1, Route_Leg2, CarrierCode_Leg1, /*new*/FlightNumber_Leg1, CarrierCode_Leg2, /*new*/FlightNumber_Leg2,
	SUBSTRING(Route_Leg1,1,3)+'-'+SUBSTRING(Route_Leg2,4,3) as Route, DepartureDate, PurchaseDate,
	SUM(BaseFare_Leg1_RM) as BaseFare_Leg1_RM, SUM(FuelSurcharge_Leg1_RM) as FuelSurcharge_Leg1_RM, SUM(AncillaryAmount_Leg1_RM) as AncillaryAmount_Leg1_RM,/*new*/SUM(ThruFare_Leg1_RM) as ThruFare_Leg1_RM,
	SUM(BaseFare_Leg2_RM) as BaseFare_Leg2_RM, SUM(FuelSurcharge_Leg2_RM) as FuelSurcharge_Leg2_RM, SUM(AncillaryAmount_Leg2_RM) as AncillaryAmount_Leg2_RM,/*new*/SUM(ThruFare_Leg2_RM) as ThruFare_Leg2_RM,
	SUM(BaseFare_Leg1_RM + BaseFare_Leg2_RM) as BaseFare_RM,
	SUM(FuelSurcharge_Leg1_RM+FuelSurcharge_Leg2_RM) as FuelSurcharge_RM,
	SUM(AncillaryAmount_Leg1_RM+AncillaryAmount_Leg2_RM) as AncillaryAmount_RM,
	/*new*/SUM(ThruFare_Leg1_RM+ThruFare_Leg2_RM) as ThruFare_RM,
	SUM(BaseFare_Leg1_RM + BaseFare_Leg2_RM+FuelSurcharge_Leg1_RM+FuelSurcharge_Leg2_RM+AncillaryAmount_Leg1_RM+AncillaryAmount_Leg2_RM+/*new*/ThruFare_Leg1_RM+ThruFare_Leg2_RM) as TotalRevenue_RM,
	Nationality = case when Nationality in ('Australia','Indonesia','China','Japan','Malaysia','South Korea',
	'Thailand','Taiwan','India','Singapore') then Nationality Else 'Others' End,
	AgeBand = case when age between 0 and 12 then 'Under12'
	when age between 13 and 19 then 'Teens'
	when age between 20 and 24 then 'Youth'
	when age between 25 and 29 then 'YoungAdult'
	when age between 30 and 39 then 'MidLevelExecs'
	when age between 40 and 60 then 'MatureAffluent'
	when age between 60 and 100 then '>60' Else 'Unknown' End
	into #_Temp_FlyThru_All_v3
	from #_Temp_FlyThru_All_RM
	where route_Leg2 is not null
	group by Route_Leg1, Route_Leg2, CarrierCode_Leg1, /*new*/FlightNumber_Leg1, CarrierCode_Leg2, /*new*/FlightNumber_Leg2,
	SUBSTRING(Route_Leg1,1,3)+'-'+SUBSTRING(Route_Leg2,4,3), Age, Nationality,
	BaseFare_Leg1_RM, FuelSurcharge_Leg1_RM, AncillaryAmount_Leg1_RM, ThruFare_Leg1_RM,
	BaseFare_Leg2_RM, FuelSurcharge_Leg2_RM, AncillaryAmount_Leg2_RM, ThruFare_Leg2_RM,
	DepartureDate, PurchaseDate
	
	
	BEGIN TRY TRUNCATE TABLE SAT_AH_Temp_FlyThru_All_v3 DROP TABLE SAT_AH_Temp_FlyThru_All_v3 END TRY BEGIN CATCH END CATCH 
	select CapturedDate, Route_Leg1, Route_Leg2, CarrierCode_Leg1, /*new*/FlightNumber_Leg1, CarrierCode_Leg2, /*new*/FlightNumber_Leg2,
	Route, DepartureDate, PurchaseDate, 	Nationality, AgeBand,
	sum(Booking) as Booking, sum(SeatsSold) as SeatsSold,
	sum(BaseFare_Leg1_RM) as BaseFare_Leg1_RM, sum(FuelSurcharge_Leg1_RM) as FuelSurcharge_Leg1_RM, sum(AncillaryAmount_Leg1_RM) as AncillaryAmount_Leg1_RM,/*new*/SUM(ThruFare_Leg1_RM) as ThruFare_Leg1_RM,
	sum(BaseFare_Leg2_RM) as BaseFare_Leg2_RM, sum(FuelSurcharge_Leg2_RM) as FuelSurcharge_Leg2_RM, sum(AncillaryAmount_Leg2_RM) as AncillaryAmount_Leg2_RM,/*new*/SUM(ThruFare_Leg2_RM) as ThruFare_Leg2_RM,
	sum(BaseFare_RM) as BaseFare_RM, sum(FuelSurcharge_RM) as FuelSurcharge_RM, sum(AncillaryAmount_RM) as AncillaryAmount_RM, sum(ThruFare_RM) as ThruFare_RM, sum(TotalRevenue_RM) as TotalRevenue_RM
	into SAT_AH_Temp_FlyThru_All_v3
	from #_Temp_FlyThru_All_v3
	group by  CapturedDate, Route_Leg1, Route_Leg2, CarrierCode_Leg1, /*new*/FlightNumber_Leg1, CarrierCode_Leg2, /*new*/FlightNumber_Leg2,
	Route, DepartureDate, PurchaseDate, Nationality, AgeBand
	
		
END
	










GO


