USE [REZAKWB01]
GO

/****** Object:  StoredProcedure [wb].[SAT_Finance_RevenueByFlight_v3]    Script Date: 10/26/2015 10:15:29 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO










-- =============================================
-- Author:		<Matthew Oh>
-- Create date: <2013-05-31,,>
-- Description:	<FINANCE - 12 MONTHS INVENTORY + REVENUE>

-- Modified: 2014-6-10. Roosevelt Koh	- Changed from hardcoded list of carriers to a SELECT query.
-- Modified: 2015-2-9. Md. Azimuddin Khan	- Added new columns for USD.


-- =============================================
--ALTER PROCEDURE [wb].[SAT_Finance_RevenueByFlight_v3]

--AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
		
		
	DECLARE @startDateUTC     datetime,
			@endDateUTC       datetime,
			@MYDateUTC     datetime,
			@departureStart     datetime,
			@departureEnd    datetime,
			@timeZone         varchar(4),
			@date varchar(20) 

	SET @timeZone         = GETDATE()
	select @MYDateUTC  = ods.ConvertDate( 'MY', GETDATE(),0,0)
	SET @departureStart = CAST(CONVERT(VARCHAR, DATEADD(month, DATEDIFF(month, 0, @MYDateUTC)-2, 0),101) as datetime)
	SET @departureEnd   = CAST(CONVERT(VARCHAR, DATEADD(month, DATEDIFF(month, 0, @MYDateUTC)+5, 0),101) as datetime)
	print @MYDateUTC 
	print @departureStart
	print @departureEnd



	BEGIN TRY TRUNCATE TABLE #SeatsSold_BaseRevRM DROP TABLE #SeatsSold_BaseRevRM END TRY BEGIN CATCH END CATCH 
	select distinct @MYDateUTC as CapturedDate,
	count(A.PassengerID) as SeatsSold, DepartureDate, CarrierCode, FlightNumber, Route, CurrencyCode,
	sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))/ISNULL(L.ConversionRate,1)) as BaseFare_RM,
	sum((ISNULL(Fuel_Amt,0))/ISNULL(L.ConversionRate,1)) as FuelSurcharge_RM,
	sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))/ISNULL(M.ConversionRate,1)) as BaseFare_IDR,
	sum((ISNULL(Fuel_Amt,0))/ISNULL(M.ConversionRate,1)) as FuelSurcharge_IDR,
	sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))/ISNULL(N.ConversionRate,1)) as BaseFare_THB,
	sum((ISNULL(Fuel_Amt,0))/ISNULL(N.ConversionRate,1)) as FuelSurcharge_THB,
	sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))/ISNULL(O.ConversionRate,1)) as BaseFare_JPY,
	sum((ISNULL(Fuel_Amt,0))/ISNULL(O.ConversionRate,1)) as FuelSurcharge_JPY,
	sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))/ISNULL(P.ConversionRate,1)) as BaseFare_PHP,
	sum((ISNULL(Fuel_Amt,0))/ISNULL(P.ConversionRate,1)) as FuelSurcharge_PHP,
	sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))/ISNULL(INR.ConversionRate,1)) as BaseFare_INR,
	sum((ISNULL(Fuel_Amt,0))/ISNULL(INR.ConversionRate,1)) as FuelSurcharge_INR,	
	sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))/ISNULL(USD.ConversionRate,1)) as BaseFare_USD,
	sum((ISNULL(Fuel_Amt,0))/ISNULL(USD.ConversionRate,1)) as FuelSurcharge_USD		
	into #SeatsSold_BaseRevRM
	from
		(select 
		PassengerID, SegmentID, DepartureDate, 
		DepartureStation+ArrivalStation as Route, CarrierCode, FlightNumber
		from vw_PassengerJourneySegment
		where BookingStatus = 'HK' 
		and DepartureDate > @departureStart 
		and DepartureDate <= @departureEnd
		and CarrierCode in (select CarrierCode from ods.carrier where carriertype = 'H' and carriercode <> 'BF') --('AK','FD','QZ','D7','JW','PQ','Z2')
		) A
	left join
		(select PassengerID, BookingID
		from ods.BookingPassenger) B
		on A.PassengerID = B.PassengerID
	left join
		(select BookingID, BookingDate, currencycode
		from ods.Booking) CC
		on B.bookingID = CC.BookingID	
	left join
		(select PassengerID, SegmentID, sum(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as Fare_Amt
		from
			(select PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge
			where ChargeType in ('0','8')) C
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix) D
			on C.ChargeType = D.ChargeTypeID
		group by PassengerID, SegmentID	) E
		on A.SegmentID = E.SegmentID and A.PassengerID = E.PassengerID
	left join 
		(select PassengerID, SegmentID, sum(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as Disc_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge
			where ChargeType = '1') F
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix) G
			on F.ChargeType = G.ChargeTypeID
		group by PassengerID, SegmentID) H
		on A.SegmentID = H.SegmentID and A.PassengerID = H.PassengerID
	left join 
		(select PassengerID, SegmentID, sum(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as Promo_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge
			where ChargeType = '7') I	
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix) J
			on I.ChargeType = J.ChargeTypeID
		group by PassengerID, SegmentID) K		
		on A.SegmentID = K.SegmentID and A.PassengerID = K.PassengerID 	
	left join 
		(select PassengerID, SegmentID, sum(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as Fuel_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge
			where ChargeCode in ('FUEL','DOMS','FUEX')) O	
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix) P
			on O.ChargeType = P.ChargeTypeID
		group by PassengerID, SegmentID	) Q		
		on A.SegmentID = Q.SegmentID and A.PassengerID = Q.PassengerID 		
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from dw.CurrencyconversionHistoryDecompressed with (nolock)
		where FromCurrencyCode = 'MYR') L
		on L.ToCurrencyCode = CC.CurrencyCode 
		and CAST(CONVERT(VARCHAR, CC.BookingDate,110) as datetime) = L.ConversionDate
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from dw.CurrencyconversionHistoryDecompressed with (nolock)
		where FromCurrencyCode = 'IDR') M
		on M.ToCurrencyCode = CC.CurrencyCode 
		and CAST(CONVERT(VARCHAR,CC.BookingDate,110) as datetime) = M.ConversionDate	
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from dw.CurrencyconversionHistoryDecompressed with (nolock)
		where FromCurrencyCode = 'THB') N
		on N.ToCurrencyCode = CC.CurrencyCode 
		and CAST(CONVERT(VARCHAR, CC.BookingDate,110) as datetime) = N.ConversionDate	
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from dw.CurrencyconversionHistoryDecompressed with (nolock)
		where FromCurrencyCode = 'JPY') O
		on O.ToCurrencyCode = CC.CurrencyCode 
		and CAST(CONVERT(VARCHAR, CC.BookingDate,110) as datetime) = O.ConversionDate			
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from dw.CurrencyconversionHistoryDecompressed with (nolock)
		where FromCurrencyCode = 'PHP') P
		on P.ToCurrencyCode = CC.CurrencyCode 
		and CAST(CONVERT(VARCHAR, CC.BookingDate,110) as datetime) = P.ConversionDate
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from dw.CurrencyconversionHistoryDecompressed with (nolock)
		where FromCurrencyCode = 'INR') INR
		on INR.ToCurrencyCode = CC.CurrencyCode 
		and CAST(CONVERT(VARCHAR, CC.BookingDate,110) as datetime) = INR.ConversionDate		
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from dw.CurrencyconversionHistoryDecompressed with (nolock)
		where FromCurrencyCode = 'USD') USD
		on USD.ToCurrencyCode = CC.CurrencyCode 
		and CAST(CONVERT(VARCHAR, CC.BookingDate,110) as datetime) = USD.ConversionDate			
	group by DepartureDate, CarrierCode, FlightNumber, Route, CurrencyCode
	

	--select * from #SeatsSold_BaseRevRM
	
		
	BEGIN TRY TRUNCATE TABLE #SeatsSold_BaseRevRM_RowNum DROP TABLE #SeatsSold_BaseRevRM_RowNum END TRY BEGIN CATCH END CATCH 
	select distinct CapturedDate, SeatsSold, DepartureDate, CarrierCode, FlightNumber, Route, CurrencyCode,
	BaseFare_RM, FuelSurcharge_RM, BaseFare_IDR, FuelSurcharge_IDR,	BaseFare_THB, FuelSurcharge_THB,
	BaseFare_JPY, FuelSurcharge_JPY, BaseFare_PHP, FuelSurcharge_PHP, BaseFare_INR, FuelSurcharge_INR,BaseFare_USD, FuelSurcharge_USD,
	ROW_NUMBER() over (partition by CarrierCode, FlightNumber, DepartureDate,Route Order By CarrierCode, FlightNumber, DepartureDate,Route)  As RowNO	
	into #SeatsSold_BaseRevRM_RowNum
	from  #SeatsSold_BaseRevRM
	order by CarrierCode, FlightNumber, DepartureDate,Route
			
	--select top 100*	from #SeatsSold_BaseRevRM_RowNum 
	--where FlightNumber = 1380
	--order by CarrierCode, FlightNumber, DepartureDate, RowNO	
	
		
	BEGIN TRY TRUNCATE TABLE #SeatsSold_BaseRevRM_Capacity_RowNum DROP TABLE #SeatsSold_BaseRevRM_Capacity_RowNum END TRY BEGIN CATCH END CATCH 
	select distinct CapturedDate, SeatsSold, Capacity, ISNULL(C.ActualDistance,C2.ActualDistance) ActualDistance, ISNULL(C.ActualDistanceUnit,C2.ActualDistanceUnit) ActualDistanceUnit, 
	A.DepartureDate, A.CarrierCode, A.FlightNumber, A.Route, CurrencyCode,
	BaseFare_RM, FuelSurcharge_RM, BaseFare_IDR, FuelSurcharge_IDR,	BaseFare_THB, FuelSurcharge_THB,
	BaseFare_JPY, FuelSurcharge_JPY, BaseFare_PHP, FuelSurcharge_PHP, BaseFare_INR, FuelSurcharge_INR,BaseFare_USD, FuelSurcharge_USD, RowNO	
	into #SeatsSold_BaseRevRM_Capacity_RowNum
	from #SeatsSold_BaseRevRM_RowNum A
	left join ods.InventoryLeg B on A.CarrierCode = B.CarrierCode and A.FlightNumber = B.FlightNumber
		and A.Route = B.DepartureStation+B.ArrivalStation and A.DepartureDate = B.DepartureDate
	left join ods.distance C on B.DepartureStation = C.DepartureStation and B.ArrivalStation = C.ArrivalStation
	left join dw.citypair C2 on B.DepartureStation = C2.DepartureStation and B.ArrivalStation = C2.ArrivalStation --added citypair, used in case distance table don't have data
	where A.RowNO = 1
	and B.Lid > 0
	and B.Status <> 2
	union
	select distinct CapturedDate, SeatsSold, 0, 0, 0, DepartureDate, CarrierCode, FlightNumber, Route, CurrencyCode,
	BaseFare_RM, FuelSurcharge_RM, BaseFare_IDR, FuelSurcharge_IDR,	BaseFare_THB, FuelSurcharge_THB,
	BaseFare_JPY, FuelSurcharge_JPY, BaseFare_PHP, FuelSurcharge_PHP, BaseFare_INR, FuelSurcharge_INR,BaseFare_USD, FuelSurcharge_USD, RowNO	
	from #SeatsSold_BaseRevRM_RowNum
	where RowNO >= 2
	order by CarrierCode, FlightNumber, DepartureDate, RowNo

	
	
	BEGIN TRY TRUNCATE TABLE #SeatsSold_BaseRevRM_Capacity_RowNum_agg DROP TABLE #SeatsSold_BaseRevRM_Capacity_RowNum_agg END TRY BEGIN CATCH END CATCH 
	select SUM(SeatsSold) as SeatsSold, SUM(Capacity) as Capacity, sum(ActualDistance) as ActualDistance,
	DepartureDate, CarrierCode, FlightNumber, Route
	into #SeatsSold_BaseRevRM_Capacity_RowNum_agg	
	from #SeatsSold_BaseRevRM_Capacity_RowNum
	group by DepartureDate, CarrierCode, FlightNumber, Route
			
	--select *
	--from #SeatsSold_BaseRevRM_Lid_RowNum
	--where flightNumber = 1329
	--order by CarrierCode, FlightNumber, DepartureDate, RowNo
	
	--select *
	--from #SeatsSold_BaseRevRM_Lid_RowNum_agg
	--where flightNumber = 1329
	--order by CarrierCode, FlightNumber, DepartureDate
	
	
	
	BEGIN TRY TRUNCATE TABLE SAT_RevenueByFlight_v3 DROP TABLE SAT_RevenueByFlight_v3 END TRY BEGIN CATCH END CATCH 
	select distinct CapturedDate, YearInt, MonthInt, Month, 
	A.DepartureDate, A.CarrierCode, A.FlightNumber, A.Route, CurrencyCode,
	SeatsSold, Capacity, ActualDistance, ActualDistanceUnit, FlightCount = ActualDistanceUnit,
	BaseFare_RM, FuelSurcharge_RM, BaseFare_IDR, FuelSurcharge_IDR,	BaseFare_THB, FuelSurcharge_THB,
	BaseFare_JPY, FuelSurcharge_JPY, BaseFare_PHP, FuelSurcharge_PHP, BaseFare_INR, FuelSurcharge_INR, BaseFare_USD, FuelSurcharge_USD, 
	PassengerMiles, ASM	
	into SAT_RevenueByFlight_v3
	from	
		(select distinct CapturedDate, Year(DepartureDate) as YearInt, MONTH(DepartureDate) as MonthInt, 
		LEFT(DATENAME(MM,DepartureDate),3)+'-'+RIGHT(Year(DepartureDate),2) as Month, 
		SeatsSold, Capacity, ActualDistance, ActualDistanceUnit, 
		DepartureDate, CarrierCode, FlightNumber, Route, CurrencyCode,
		BaseFare_RM, FuelSurcharge_RM, BaseFare_IDR, FuelSurcharge_IDR,	BaseFare_THB, FuelSurcharge_THB,
		BaseFare_JPY, FuelSurcharge_JPY, BaseFare_PHP, FuelSurcharge_PHP, BaseFare_INR, FuelSurcharge_INR,BaseFare_USD, FuelSurcharge_USD,  RowNO
		from #SeatsSold_BaseRevRM_Capacity_RowNum
		where RowNo = 1) A
	left join
		(select DepartureDate, CarrierCode, FlightNumber, Route, 
		SUM(SeatsSold*ActualDistance) as PassengerMiles, SUM(Capacity*ActualDistance) as ASM
		from #SeatsSold_BaseRevRM_Capacity_RowNum_agg
		group by DepartureDate, CarrierCode, FlightNumber, ActualDistance, Route) B
		on A.DepartureDate = B.DepartureDate and A.CarrierCode = B.CarrierCode and A.FlightNumber = B.flightNumber
		and A.Route = B.Route 
	union
	select distinct CapturedDate, Year(DepartureDate) as YearInt, MONTH(DepartureDate) as MonthInt, 
	LEFT(DATENAME(MM,DepartureDate),3)+'-'+RIGHT(Year(DepartureDate),2) as Month, 
	DepartureDate, CarrierCode, FlightNumber, Route, CurrencyCode,
	SeatsSold, Capacity, ActualDistance, ActualDistanceUnit, FlightCount = ActualDistanceUnit,
	BaseFare_RM, FuelSurcharge_RM, BaseFare_IDR, FuelSurcharge_IDR,	BaseFare_THB, FuelSurcharge_THB,
	BaseFare_JPY, FuelSurcharge_JPY, BaseFare_PHP, FuelSurcharge_PHP, BaseFare_INR, FuelSurcharge_INR,BaseFare_USD, FuelSurcharge_USD, 0,0
	from #SeatsSold_BaseRevRM_Capacity_RowNum
	where RowNo > 1		
	order by CarrierCode, FlightNumber, DepartureDate
	
END








GO


