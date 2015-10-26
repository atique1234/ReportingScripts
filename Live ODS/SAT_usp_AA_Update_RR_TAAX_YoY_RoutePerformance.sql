USE [REZAKWB01]
GO

/****** Object:  StoredProcedure [wb].[SAT_usp_AA_Update_RR_TAAX_YoY_RoutePerformance]    Script Date: 10/23/2015 12:23:17 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO











-- =============================================
-- Author:		<Matthew Oh>
-- Create date: <2011-08-28,,>
-- Description:	<ROUTE REVENUE YoY AAX - FORWARD MONTHS INVENTORY + REVENUE>
-- =============================================

--ALTER PROCEDURE [wb].[SAT_usp_AA_Update_RR_TAAX_YoY_RoutePerformance]

--AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	
	
	
	DECLARE @CapturedDate datetime,
			@BookingEnd     datetime,
			@BookingEnd_Y1    datetime,
			@BookingEnd_Y1M    datetime,
			@departureStart     datetime,
			@departureEnd    datetime,
			@departureStart_Y1     datetime,
			@departureEnd_Y1    datetime,
			@date varchar(20),
			@MYDateUTC datetime
			 
	select @MYDateUTC  = ods.ConvertDate( 'MY', GETDATE(),0,0)

	SET @CapturedDate = CAST(CONVERT(VARCHAR,@MYDateUTC, 101) AS DateTime)
	--SET @CapturedDate = CAST(CONVERT(VARCHAR,DATEADD(HH,8,GetDate()), 101) AS DateTime)
	SET @BookingEnd = CAST(CONVERT(VARCHAR,@MYDateUTC, 101) AS DateTime)
	SET @BookingEnd_Y1   = CAST(CONVERT(VARCHAR, DATEADD(Year, -1, @MYDateUTC), 101) AS DateTime) 
	SET @BookingEnd_Y1M =CAST(CONVERT(VARCHAR(25),DATEADD(YEAR, DATEDIFF(YEAR, -1, @BookingEnd_Y1), -1),101) AS DateTime) 
	print @CapturedDate
	print @BookingEnd
	print @BookingEnd_Y1
	print @BookingEnd_Y1M

	SET @departureStart =CAST(CONVERT(VARCHAR, DATEADD(YEAR, DATEDIFF(YEAR, 0, @BookingEnd), 0), 101) AS DateTime) 
	SET @departureEnd =CAST(CONVERT(VARCHAR,DATEADD(dd,-1,DATEADD(yy, DATEDIFF(yy,0,@BookingEnd)+2,0))) AS DateTime)
	print @departureStart
	print @departureEnd
	

	--SET @departureStart Y1 =CAST(CONVERT(VARCHAR, DATEADD(s, 1,DATEADD(mm, DATEDIFF(m,0,DateAdd(month,0,GetDate())),0)), 101) AS DateTime)
	SET @departureStart_Y1 =CAST(CONVERT(VARCHAR, DATEADD(YEAR, DATEDIFF(YEAR, 0, @BookingEnd_Y1), 0), 101) AS DateTime) 
	SET @departureEnd_Y1 =CAST(CONVERT(VARCHAR,DATEADD(dd,-1,DATEADD(yy, DATEDIFF(yy,0,@BookingEnd_y1)+2,0))) AS DateTime)
	print @departureStart_Y1
	print @departureEnd_Y1
	
	
	
	----* Seat count, BaseRev_THB *----

		----* Seat count, BaseRev_THB @ ExtractionDate,Current Year *----
		
	BEGIN TRY TRUNCATE TABLE Temp_TAAX_Weekly_Route_BaseRevRM DROP TABLE Temp_TAAX_Weekly_Route_BaseRevRM END TRY BEGIN CATCH END CATCH 
	select CAST(Convert(VARCHAR,@CapturedDate, 112) as datetime) as CapturedDate, Year, Month, WeekNumber, 
	DATEPART(DW,@CapturedDate-1) as dayOfWeek, Cabin,
	A.PassengerID, RecordLocator, DepartureDate, CarrierCode, FlightNumber, Route,
	sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))*ISNULL(1/ConversionRate,1)) as BaseFare_THB,
	sum(ISNULL(Fuel_Amt,0)*ISNULL(1/ConversionRate,1)) as FuelSurcharge_THB,
	--newly added
	sum(ISNULL(ThruFare_Amt,0)*ISNULL(1/ConversionRate,1)) as ThruFare_THB,
	sum(ISNULL(XHISEA_Amt,0)*ISNULL(1/ConversionRate,1)) as XHISEA_THB,
	sum(ISNULL(ADM_Amt,0)*ISNULL(1/ConversionRate,1)) as ADM_THB
	--newly added
	into Temp_TAAX_Weekly_Route_BaseRevRM
	from
	    ( select t.PassengerID, t.SegmentID,isnull(carr_map.mappedcarrier ,t.CARRIERCODE) CarrierCode,
	     t.FlightNumber,t.Year,t.Month,t.WeekNumber,t.DepartureDate,t.Route,
	     t.Cabin,t.CreatedDate
	     from 
	    
		(select PassengerID, SegmentID, CarrierCode, FlightNumber, 
			YEAR(DepartureDate) as Year, DATENAME(MM,DepartureDate) as Month, DATENAME(Week,DepartureDate) as WeekNumber,
			DepartureDate, DepartureStation+ArrivalStation as Route,
			Cabin = case when FareClassofService in ('C','D','G','J','G1') then 'Premium'
			Else 'Economy' End,  CreatedDate
			from vw_PassengerJourneySegment with (nolock)
			where BookingStatus = 'HK' 
			and DATEADD(HH,8,CreatedDate) < @BookingEnd
			and DepartureDate >= @departureStart
			and DepartureDate <= @departureEnd
			
			and ltrim(rtrim(FlightNumber)) not in ('2994','2995','2996','2997','2998','2999')
		) t
		LEFT JOIN 
		AAII_CARRIER_MAPPING carr_map
		on carr_map.carriercode = t.carriercode
		and ltrim(RTRIM(carr_map.flightnumber)) = ltrim(RTRIM(t.flightnumber))
		Where  isnull(carr_map.mappedcarrier ,t.CARRIERCODE)  in ('XJ')
		
		)A
	left join
		(select 
		PassengerID, SegmentID, CurrencyCode
		from ods.PassengerJourneySegment with (nolock)) B
		on A.PassengerID = B.PassengerID and A.SegmentID = B.SegmentID
	left join
		(select PassengerID, SegmentID, --(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) 
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as Fare_Amt
		from
			(select PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge with (nolock)
			where ChargeType in ('0','8')) C
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix with (nolock)) D
			on C.ChargeType = D.ChargeTypeID
		group by PassengerID, SegmentID) E
		on A.SegmentID = E.SegmentID and A.PassengerID = E.PassengerID
	left join 
		(select PassengerID, SegmentID, --(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as 
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as Disc_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge with (nolock)
			where ChargeType = '1') F
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix with (nolock)) G
			on F.ChargeType = G.ChargeTypeID
		group by PassengerID, SegmentID) H
		on A.SegmentID = H.SegmentID and A.PassengerID = H.PassengerID
	left join 
		(select PassengerID, SegmentID, --(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as 
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as Promo_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge with (nolock)
			where ChargeType = '7') I	
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix with (nolock)) J
			on I.ChargeType = J.ChargeTypeID
		group by PassengerID, SegmentID) K		
		on A.SegmentID = K.SegmentID and A.PassengerID = K.PassengerID 	
	left join 
		(select PassengerID, SegmentID, --sum(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as 
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as Fuel_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge with (nolock)
			where ChargeCode in ('FUEL','DOMS','FUEX')) O	
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix with (nolock)) P
			on O.ChargeType = P.ChargeTypeID
		group by PassengerID, SegmentID) Q		
		on A.SegmentID = Q.SegmentID and A.PassengerID = Q.PassengerID 	
		
	--newly added	
	left join 
		(select PassengerID, SegmentID, 
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
		group by PassengerID, SegmentID) THRU		
		on A.SegmentID = THRU.SegmentID and A.PassengerID = THRU.PassengerID 	
	--newly added
	left join 
		(select PassengerID, SegmentID, 
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as XHISEA_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge
			where ChargeCode in ('XHISEA')) XHISEA1
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix) XHISEA2
			on XHISEA1.ChargeType = XHISEA2.ChargeTypeID
		group by PassengerID, SegmentID) XHISEA		
		on A.SegmentID = XHISEA.SegmentID and A.PassengerID = XHISEA.PassengerID 	
	--newly added	
	left join 
		(select PassengerID, SegmentID, 
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as ADM_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge
			where ChargeCode in ('ADM')) ADM1	
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix) ADM2
			on ADM1.ChargeType = ADM2.ChargeTypeID
		group by PassengerID, SegmentID) ADM		
		on A.SegmentID = ADM.SegmentID and A.PassengerID = ADM.PassengerID	
		
	left join
		(select PassengerID, BookingID
		from ods.BookingPassenger with (nolock)) M
		on A.PassengerID = M.PassengerID
	left join
		(Select BookingID, RecordLocator, CurrencyCode
		from ods.Booking with (nolock)) N
		on M.BookingID = N.BookingID
	
	left join
	(select FromCurrencyCode, ToCurrencyCode, ConversionDate, ConversionRate
	from dw.CurrencyconversionHistoryDecompressed with (nolock)	
	where FromCurrencyCode = 'THB') F
	on CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = F.ConversionDate and N.CurrencyCode = F.ToCurrencyCode	
	/*
	left join
		(select distinct FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from SAT_TAAX_CurrencyConversion_BNM with (nolock)
		where ToCurrencyCode = 'MYR') L
		on L.FromCurrencyCode = N.CurrencyCode 
		and CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = L.ConversionDate
	*/
	group by A.PassengerID, Year, Month, WeekNumber, RecordLocator, DepartureDate, CarrierCode, FlightNumber, Route,
	cabin

	--select top 100* from #Temp_TAAX_Weekly_Route_BaseRevRM

		

		----* Seat count, BaseRev_THB @ ExtractionDate, Last Year *----
				
	BEGIN TRY TRUNCATE TABLE Temp_TAAX_Weekly_Route_Y1_BaseRevRM DROP TABLE Temp_TAAX_Weekly_Route_Y1_BaseRevRM END TRY BEGIN CATCH END CATCH 
	select CAST(Convert(VARCHAR,@CapturedDate, 112) as datetime) as CapturedDate,Year, Month, WeekNumber, 
	DATEPART(DW,@CapturedDate-1) as dayOfWeek, Cabin,
	A.PassengerID, RecordLocator, DepartureDate, CarrierCode, FlightNumber, Route,
	sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))*ISNULL(1/ConversionRate,1)) as BaseFare_THB,
	sum(ISNULL(Fuel_Amt,0)*ISNULL(1/ConversionRate,1)) as FuelSurcharge_THB,
	--newly added
	sum(ISNULL(ThruFare_Amt,0)*ISNULL(1/ConversionRate,1)) as ThruFare_THB,
	sum(ISNULL(XHISEA_Amt,0)*ISNULL(1/ConversionRate,1)) as XHISEA_THB,
	sum(ISNULL(ADM_Amt,0)*ISNULL(1/ConversionRate,1)) as ADM_THB
	--newly added
	into Temp_TAAX_Weekly_Route_Y1_BaseRevRM
	from
		(select  t.PassengerID, t.SegmentID,isnull(carr_map.mappedcarrier ,t.CARRIERCODE) CarrierCode,
	     t.FlightNumber,t.Year,t.Month,t.WeekNumber,t.DepartureDate,t.Route,
	     t.Cabin,t.CreatedDate from
		(select PassengerID, SegmentID, CarrierCode, FlightNumber, 
		YEAR(DepartureDate) as Year, DATENAME(MM,DepartureDate) as Month, DATENAME(Week,DepartureDate) as WeekNumber,
		DepartureDate, DepartureStation+ArrivalStation as Route,
		Cabin = case when FareClassofService in ('C','D','G','J','G1') then 'Premium'
		Else 'Economy' End,  CreatedDate
		from vw_PassengerJourneySegment with (nolock)
		where DATEADD(HH,8,CreatedDate) < @BookingEnd_Y1
		and DepartureDate >= @departureStart_Y1
		and DepartureDate <= @departureEnd_Y1
		
		and ltrim(rtrim(FlightNumber)) not in ('2994','2995','2996','2997','2998','2999')
		) t
		LEFT JOIN 
		AAII_CARRIER_MAPPING carr_map
		on carr_map.carriercode = t.carriercode
		and ltrim(RTRIM(carr_map.flightnumber)) = ltrim(RTRIM(t.flightnumber))
		Where isnull(carr_map.mappedcarrier ,t.CARRIERCODE) in ('XJ')
		)A
	left join
		(select 
		PassengerID, SegmentID, CurrencyCode
		from ods.PassengerJourneySegment with (nolock)) B
		on A.PassengerID = B.PassengerID and A.SegmentID = B.SegmentID
	left join
		(select PassengerID, SegmentID, --(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as 
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as Fare_Amt
		from
			(select PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge with (nolock)
			where ChargeNumber = '0') C
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix with (nolock)) D
			on C.ChargeType = D.ChargeTypeID
		group by PassengerID, SegmentID) E
		on A.SegmentID = E.SegmentID and A.PassengerID = E.PassengerID
	left join 
		(select PassengerID, SegmentID, --(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as 
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as Disc_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge with (nolock)
			where ChargeType = '1') F
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix with (nolock)) G
			on F.ChargeType = G.ChargeTypeID
		group by PassengerID, SegmentID) H
		on A.SegmentID = H.SegmentID and A.PassengerID = H.PassengerID
	left join 
		(select PassengerID, SegmentID, --(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as 
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as Promo_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge with (nolock)
			where ChargeType = '7') I	
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix with (nolock)) J
			on I.ChargeType = J.ChargeTypeID
		group by PassengerID, SegmentID) K		
		on A.SegmentID = K.SegmentID and A.PassengerID = K.PassengerID 	
	left join 
		(select PassengerID, SegmentID, --sum(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as 
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as Fuel_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge with (nolock)
			where ChargeCode in ('FUEL','DOMS','FUEX')) O	
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix with (nolock)) P
			on O.ChargeType = P.ChargeTypeID
		group by PassengerID, SegmentID) Q		
		on A.SegmentID = Q.SegmentID and A.PassengerID = Q.PassengerID 	
		
	--newly added	
	left join 
		(select PassengerID, SegmentID, 
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
		group by PassengerID, SegmentID) THRU		
		on A.SegmentID = THRU.SegmentID and A.PassengerID = THRU.PassengerID 	
	--newly added
	left join 
		(select PassengerID, SegmentID, 
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as XHISEA_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge
			where ChargeCode in ('XHISEA')) XHISEA1
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix) XHISEA2
			on XHISEA1.ChargeType = XHISEA2.ChargeTypeID
		group by PassengerID, SegmentID) XHISEA		
		on A.SegmentID = XHISEA.SegmentID and A.PassengerID = XHISEA.PassengerID 	
	--newly added	
	left join 
		(select PassengerID, SegmentID, 
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as ADM_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge
			where ChargeCode in ('ADM')) ADM1	
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix) ADM2
			on ADM1.ChargeType = ADM2.ChargeTypeID
		group by PassengerID, SegmentID) ADM		
		on A.SegmentID = ADM.SegmentID and A.PassengerID = ADM.PassengerID		
	left join
		(select PassengerID, BookingID
		from ods.BookingPassenger with (nolock)) M
		on A.PassengerID = M.PassengerID
	left join
		(Select BookingID, RecordLocator, CurrencyCode
		from ods.Booking with (nolock)) N
		on M.BookingID = N.BookingID
	
	left join
	(select FromCurrencyCode, ToCurrencyCode, ConversionDate, ConversionRate
	from dw.CurrencyconversionHistoryDecompressed with (nolock)	
	where FromCurrencyCode = 'THB') F
	on CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = F.ConversionDate and N.CurrencyCode = F.ToCurrencyCode
	/*
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from SAT_TAAX_CurrencyConversion_BNM with (nolock)
		where ToCurrencyCode = 'MYR') L
		on L.FromCurrencyCode = N.CurrencyCode 
		and CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = L.ConversionDate
	*/
	group by A.PassengerID, Year, Month, WeekNumber, RecordLocator, DepartureDate, CarrierCode, FlightNumber, Route,
	cabin

	--select top 10000* from #Temp_TAAX_Weekly_Route_Y1_BaseRevRM
	--where CarrierCode = 'AK'
	--and FlightNumber = '5123' 
	--and StartWeek = '2010-01-10 00:00:00.000'
			
		----* Seat count, BaseRev_THB @ MonthEnd, Last Year *----
		
	BEGIN TRY TRUNCATE TABLE Temp_TAAX_Weekly_Route_Y1M_BaseRevRM DROP TABLE Temp_TAAX_Weekly_Route_Y1M_BaseRevRM END TRY BEGIN CATCH END CATCH 
	select CAST(Convert(VARCHAR,@CapturedDate, 112) as datetime) as CapturedDate,Year, Month, WeekNumber, 
	DATEPART(DW,@CapturedDate-1) as dayOfWeek, Cabin,
	A.PassengerID, RecordLocator, DepartureDate, CarrierCode, FlightNumber, Route,
	sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))*ISNULL(1/ConversionRate,1)) as BaseFare_THB,
	sum(ISNULL(Fuel_Amt,0)*ISNULL(1/ConversionRate,1)) as FuelSurcharge_THB,
	--newly added
	sum(ISNULL(ThruFare_Amt,0)*ISNULL(1/ConversionRate,1)) as ThruFare_THB,
	sum(ISNULL(XHISEA_Amt,0)*ISNULL(1/ConversionRate,1)) as XHISEA_THB,
	sum(ISNULL(ADM_Amt,0)*ISNULL(1/ConversionRate,1)) as ADM_THB
	--newly added
	into Temp_TAAX_Weekly_Route_Y1M_BaseRevRM
	from
	    (select  t.PassengerID, t.SegmentID,isnull(carr_map.mappedcarrier ,t.CARRIERCODE) CarrierCode,
	     t.FlightNumber,t.Year,t.Month,t.WeekNumber,t.DepartureDate,t.Route,
	     t.Cabin,t.CreatedDate from
		(select PassengerID, SegmentID, CarrierCode, FlightNumber, 
			YEAR(DepartureDate) as Year, DATENAME(MM,DepartureDate) as Month, DATENAME(Week,DepartureDate) as WeekNumber,
			DepartureDate, DepartureStation+ArrivalStation as Route,
			Cabin = case when FareClassofService in ('C','D','G','J') then 'Premium'
			Else 'Economy' End,  CreatedDate
			from vw_PassengerJourneySegment with (nolock)
			where DATEADD(HH,8,CreatedDate) <= @BookingEnd_Y1M
			and DepartureDate >= @departureStart_Y1
			and DepartureDate <= @departureEnd_Y1
			
			and ltrim(rtrim(FlightNumber)) not in ('2994','2995','2996','2997','2998','2999')
		)t
		LEFT JOIN 
			AAII_CARRIER_MAPPING carr_map
			on carr_map.carriercode = t.carriercode
			and ltrim(RTRIM(carr_map.flightnumber)) = ltrim(RTRIM(t.flightnumber))
			where isnull(carr_map.mappedcarrier ,t.CARRIERCODE) in ('XJ')
		)A
	left join
		(select 
		PassengerID, SegmentID, CurrencyCode
		from ods.PassengerJourneySegment with (nolock)) B
		on A.PassengerID = B.PassengerID and A.SegmentID = B.SegmentID
	left join
		(select PassengerID, SegmentID, --(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as 
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as Fare_Amt
		from
			(select PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge with (nolock)
			where ChargeNumber = '0') C
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix with (nolock)) D
			on C.ChargeType = D.ChargeTypeID
		group by PassengerID, SegmentID) E
		on A.SegmentID = E.SegmentID and A.PassengerID = E.PassengerID
	left join 
		(select PassengerID, SegmentID, --(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as 
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as Disc_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge with (nolock)
			where ChargeType = '1') F
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix with (nolock)) G
			on F.ChargeType = G.ChargeTypeID
		group by PassengerID, SegmentID) H
		on A.SegmentID = H.SegmentID and A.PassengerID = H.PassengerID
	left join 
		(select PassengerID, SegmentID, --(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as 
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as Promo_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge with (nolock)
			where ChargeType = '7') I	
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix with (nolock)) J
			on I.ChargeType = J.ChargeTypeID
		group by PassengerID, SegmentID) K		
		on A.SegmentID = K.SegmentID and A.PassengerID = K.PassengerID 	
	left join 
		(select PassengerID, SegmentID, --sum(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as 
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as Fuel_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge with (nolock)
			where ChargeCode in ('FUEL','FUEX','DOMS')) O	
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix with (nolock)) P
			on O.ChargeType = P.ChargeTypeID
		group by PassengerID, SegmentID) Q		
		on A.SegmentID = Q.SegmentID and A.PassengerID = Q.PassengerID 
	
	--newly added	
	left join 
		(select PassengerID, SegmentID, 
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
		group by PassengerID, SegmentID) THRU		
		on A.SegmentID = THRU.SegmentID and A.PassengerID = THRU.PassengerID 	
	--newly added
	left join 
		(select PassengerID, SegmentID, 
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as XHISEA_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge
			where ChargeCode in ('XHISEA')) XHISEA1
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix) XHISEA2
			on XHISEA1.ChargeType = XHISEA2.ChargeTypeID
		group by PassengerID, SegmentID) XHISEA		
		on A.SegmentID = XHISEA.SegmentID and A.PassengerID = XHISEA.PassengerID 	
	--newly added	
	left join 
		(select PassengerID, SegmentID, 
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as ADM_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge
			where ChargeCode in ('ADM')) ADM1	
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix) ADM2
			on ADM1.ChargeType = ADM2.ChargeTypeID
		group by PassengerID, SegmentID) ADM		
		on A.SegmentID = ADM.SegmentID and A.PassengerID = ADM.PassengerID	
		
		left join
		(select PassengerID, BookingID
		from ods.BookingPassenger with (nolock)) M
		on A.PassengerID = M.PassengerID
	left join
		(Select BookingID, RecordLocator, CurrencyCode
		from ods.Booking with (nolock)) N
		on M.BookingID = N.BookingID
		
	left join
	(select FromCurrencyCode, ToCurrencyCode, ConversionDate, ConversionRate
	from dw.CurrencyconversionHistoryDecompressed with (nolock)	
	where FromCurrencyCode = 'THB') F
	on CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = F.ConversionDate and N.CurrencyCode = F.ToCurrencyCode	
	/*
	left join
		(select distinct FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from SAT_TAAX_CurrencyConversion_BNM with (nolock)
		where ToCurrencyCode = 'MYR') L 
		on L.FromCurrencyCode = N.CurrencyCode 
		and CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = L.ConversionDate
	*/
	group by A.PassengerID, Year, Month, WeekNumber, RecordLocator, DepartureDate, CarrierCode, FlightNumber, Route,
	cabin
	
	--select top 1000* from #Temp_TAAX_Weekly_Route_Y1M_BaseRevRM order by startWeek
		
	
	
	
		----* Ancillary_THB  *----
			
	BEGIN TRY TRUNCATE TABLE #Temp_TAAX_Weekly_Route_Ancillaries DROP TABLE #Temp_TAAX_Weekly_Route_Ancillaries END TRY BEGIN CATCH END CATCH
	Select distinct A.PassengerId,B.FeeNumber,B.FeeCode,B.DepartureDate,B.CarrierCode,B.FlightNumber,B.DepartureStation,B.ArrivalStation,
	C.CurrencyCode, C.CreatedDate, (C.ChargeAmount * D.PositiveNegativeFlag) As ChargeAmount
	Into #Temp_TAAX_Weekly_Route_Ancillaries
	From Temp_TAAX_Weekly_Route_BaseRevRM A 
	left Join vw_PassengerFee B  With (NoLock) On A.PassengerId = B.PassengerId 
	left Join ods.PassengerFeeCharge C With (NoLock)  On B.PassengerId = C.PassengerId  And B.FeeNumber = C.FeeNumber
	left Join dw.ChargeTypeMatrix D With (NoLock) On C.ChargeType = D.ChargeTypeID

	
	
	BEGIN TRY TRUNCATE TABLE #Temp_TAAX_Weekly_Route_AncillariesRM DROP TABLE #Temp_TAAX_Weekly_Route_AncillariesRM END TRY BEGIN CATCH END CATCH
	Select A.PassengerId,A.DepartureDate,A.CarrierCode,A.FlightNumber,A.DepartureStation+A.ArrivalStation as route,A.CurrencyCode,
	Sum(ISNULL(A.ChargeAmount,0) * ISNULL(1/B.ConversionRate,1)) AS AncillaryAmount_THB
	Into #Temp_TAAX_Weekly_Route_AncillariesRM
	from
		(select PassengerId,DepartureDate,CarrierCode,FlightNumber,DepartureStation,ArrivalStation,CurrencyCode,
		ChargeAmount, CreatedDate
		from #Temp_TAAX_Weekly_Route_Ancillaries
		where CarrierCode <> ' ' 
		and Flightnumber <> ' ' 
		and DepartureStation <> ' ' 
		and ArrivalStation <> ' ') A 
	
	left join
	(select FromCurrencyCode, ToCurrencyCode, ConversionDate, ConversionRate
	from dw.CurrencyconversionHistoryDecompressed with (nolock)	
	where FromCurrencyCode = 'THB') B
	on CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = B.ConversionDate and A.CurrencyCode = B.ToCurrencyCode	
	/*
	left Join 
		(select distinct FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from SAT_TAAX_CurrencyConversion_BNM with (nolock)
		where ToCurrencyCode = 'MYR') B
		on A.CurrencyCode = B.FromCurrencyCode 
		and CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = B.ConversionDate
	*/
	group by A.PassengerId,A.DepartureDate,A.CarrierCode,A.FlightNumber,A.DepartureStation,A.ArrivalStation, A.CurrencyCode
	
			
			--select top 100*
			--from #Temp_TAAX_Weekly_Route_AncillariesRM
	
	
	
	----* All Transactions *----

		----* All Transactions @ ExtractionDate, Current Year *----

	
	BEGIN TRY TRUNCATE TABLE #Temp_TAAX_Weekly_Route_ALLRM DROP TABLE #Temp_TAAX_Weekly_Route_ALLRM  END TRY BEGIN CATCH END CATCH
	select distinct CapturedDate, Year, Month, WeekNumber, A.DepartureDate, --RecordLocator, 
	 A.CarrierCode, A.FlightNumber, A.Route, Cabin,
	count(A.PassengerID)as SeatsSold, sum(BaseFare_THB) as BaseFare_THB, sum(FuelSurcharge_THB) as FuelSurcharge_THB, 
	--newly added
	SUM(ThruFare_THB) as ThruFare_THB, SUM(XHISEA_THB) as XHISEA_THB, SUM(ADM_THB) as ADM_THB,
	--newly added
	ISNULL(SUM(AncillaryAmount_THB),0) as AncillaryAmount_THB
	into #Temp_TAAX_Weekly_Route_ALLRM 
	from
		(select distinct CapturedDate, Year, Month, WeekNumber, DepartureDate, RecordLocator, 
		CarrierCode, FlightNumber, Route, Cabin,
		PassengerID, BaseFare_THB, FuelSurcharge_THB,
		--newly added
		ThruFare_THB, XHISEA_THB, ADM_THB
		--newly added
		from Temp_TAAX_Weekly_Route_BaseRevRM) A
	left join
		(select distinct PassengerID, DepartureDate, CarrierCode, FlightNumber, route,
		AncillaryAmount_THB as AncillaryAmount_THB
		from #Temp_TAAX_Weekly_Route_AncillariesRM) B
		on A.PassengerID = B.PassengerID and A.Carriercode = B.CarrierCode and A.FlightNumber = B.Flightnumber
		and A.DepartureDate = B.DepartureDate and A.Route = B.Route
	group by CapturedDate,Year, Month, WeekNumber, A.DepartureDate, --RecordLocator, 
	A.CarrierCode, A.FlightNumber, A.Route, Cabin

		--select top 10000* from #Temp_TAAX_Weekly_Route_ALLRM 


		
		----* All Transactions @ ExtractionDate, Last Year *----
			
	BEGIN TRY TRUNCATE TABLE #Temp_TAAX_Weekly_Route_Y1_ALLRM DROP TABLE #Temp_TAAX_Weekly_Route_Y1_ALLRM  END TRY BEGIN CATCH END CATCH
	select distinct CapturedDate, Year, Month, WeekNumber,  --RecordLocator, 
	 A.CarrierCode, A.FlightNumber, A.Route, Cabin, A.DepartureDate,
	count(A.PassengerID)as SeatsSold, sum(BaseFare_THB) as BaseFare_THB, sum(FuelSurcharge_THB) as FuelSurcharge_THB, 
	--newly added
	SUM(ThruFare_THB) as ThruFare_THB, SUM(XHISEA_THB) as XHISEA_THB, SUM(ADM_THB) as ADM_THB,
	--newly added
	ISNULL(SUM(AncillaryAmount_THB),0) as AncillaryAmount_THB
	into #Temp_TAAX_Weekly_Route_Y1_ALLRM 
	from
		(select distinct CapturedDate, Year, Month, WeekNumber, RecordLocator, 
		CarrierCode, FlightNumber, Route, Cabin, DepartureDate,
		PassengerID, BaseFare_THB, FuelSurcharge_THB,
		--newly added
		ThruFare_THB, XHISEA_THB, ADM_THB
		--newly added
		from Temp_TAAX_Weekly_Route_Y1_BaseRevRM) A
	left join
		(select distinct PassengerID, DepartureDate, CarrierCode, FlightNumber, route,
		AncillaryAmount_THB as AncillaryAmount_THB
		from #Temp_TAAX_Weekly_Route_AncillariesRM) B
		on A.PassengerID = B.PassengerID and A.Carriercode = B.CarrierCode and A.FlightNumber = B.Flightnumber
		and A.DepartureDate = B.DepartureDate and A.Route = B.Route
	group by CapturedDate,Year, Month, WeekNumber, A.DepartureDate, --RecordLocator, 
	A.CarrierCode, A.FlightNumber, A.Route, Cabin

	--select top 10000* from #Temp_TAAX_Weekly_Route_Y1_ALLRM 
	
	

		----* All Transactions @ MonthEnd, Last Year *----
	
	BEGIN TRY TRUNCATE TABLE #Temp_TAAX_Weekly_Route_Y1M_ALLRM DROP TABLE  #Temp_TAAX_Weekly_Route_Y1M_ALLRM  END TRY BEGIN CATCH END CATCH
	select distinct CapturedDate, Year, Month, WeekNumber, A.DepartureDate, --RecordLocator, 
	A.CarrierCode, A.FlightNumber, A.Route, Cabin,
	count(A.PassengerID)as SeatsSold, sum(BaseFare_THB) as BaseFare_THB, sum(FuelSurcharge_THB) as FuelSurcharge_THB, 
	--newly added
	SUM(ThruFare_THB) as ThruFare_THB, SUM(XHISEA_THB) as XHISEA_THB, SUM(ADM_THB) as ADM_THB,
	--newly added
	ISNULL(SUM(AncillaryAmount_THB),0) as AncillaryAmount_THB
	into  #Temp_TAAX_Weekly_Route_Y1M_ALLRM
	from
		(select distinct CapturedDate, Year, Month, WeekNumber, DepartureDate, RecordLocator, 
		CarrierCode, FlightNumber, Route, Cabin,
		PassengerID, BaseFare_THB, FuelSurcharge_THB,
		--newly added
		ThruFare_THB, XHISEA_THB, ADM_THB
		--newly added
		from Temp_TAAX_Weekly_Route_Y1M_BaseRevRM) A
	left join
		(select distinct PassengerID, DepartureDate, CarrierCode, FlightNumber, route,
		AncillaryAmount_THB as AncillaryAmount_THB
		from #Temp_TAAX_Weekly_Route_AncillariesRM) B
		on A.PassengerID = B.PassengerID and A.Carriercode = B.CarrierCode and A.FlightNumber = B.Flightnumber
		and A.DepartureDate = B.DepartureDate and A.Route = B.Route
	group by CapturedDate,Year, Month,WeekNumber, A.DepartureDate, --RecordLocator, 
	A.CarrierCode, A.FlightNumber, A.Route, Cabin





		----* Capacity *----
			
	BEGIN TRY TRUNCATE TABLE #temp_Inventory DROP TABLE  #temp_Inventory  END TRY BEGIN CATCH END CATCH
	select distinct DepartureDate, isnull(carr_map.mappedcarrier ,il.CARRIERCODE) CarrierCode, 
	il.FlightNumber, DepartureStation, ArrivalStation,
	EquipmentType, EquipmentTypeSuffix, Cabin = 'Premium',
	Capacity = case when EquipmentType = 320 and EquipmentTypeSuffix = 'A' then 0
	when EquipmentType = 733 and EquipmentTypeSuffix = 'A' then 0
	when EquipmentType = 330 and EquipmentTypeSuffix = 'A' then 12
	when EquipmentType = 330 and EquipmentTypeSuffix = 'B' then 12
	when EquipmentType = 330 and EquipmentTypeSuffix = 'C' then 12
	when EquipmentType = 330 and EquipmentTypeSuffix = 'D' then 10
	when EquipmentType = 330 and EquipmentTypeSuffix = 'E' then 12
	when EquipmentType = 340 and EquipmentTypeSuffix = 'A' then 18
	when EquipmentType = 340 and EquipmentTypeSuffix = 'B' then 18
	when EquipmentType = 332 and EquipmentTypeSuffix = 'A' then 24
	Else '0' End
	into #temp_Inventory
	from ods.InventoryLeg il
	LEFT JOIN 
	AAII_CARRIER_MAPPING carr_map
	on carr_map.carriercode = il.carriercode
	and ltrim(RTRIM(carr_map.flightnumber)) = ltrim(RTRIM(il.flightnumber))
		
	where DepartureDate between @departureStart_Y1 and @DepartureEnd
	and Status <> 2
	and Lid >0
	and ltrim(rtrim(il.FlightNumber)) not in ('2994','2995','2996','2997','2998','2999')
	union
	select distinct DepartureDate, isnull(carr_map.mappedcarrier ,il.CARRIERCODE) CarrierCode, 
	il.FlightNumber, DepartureStation, ArrivalStation,
	EquipmentType, EquipmentTypeSuffix, Cabin = 'Economy',
	Capacity = case when EquipmentType = 320 and EquipmentTypeSuffix = 'A' then Capacity
	when EquipmentType = 733 and EquipmentTypeSuffix = 'A' then Capacity
	when EquipmentType = 330 and EquipmentTypeSuffix = 'A' then (Capacity - 12)
	when EquipmentType = 330 and EquipmentTypeSuffix = 'B' then (Capacity - 12)
	when EquipmentType = 330 and EquipmentTypeSuffix = 'C' then (Capacity - 12)
	when EquipmentType = 330 and EquipmentTypeSuffix = 'D' then (Capacity - 10)
	when EquipmentType = 330 and EquipmentTypeSuffix = 'E' then (Capacity - 12)
	when EquipmentType = 340 and EquipmentTypeSuffix = 'A' then (Capacity - 18)
	when EquipmentType = 340 and EquipmentTypeSuffix = 'B' then (Capacity - 18)
	when EquipmentType = 332 and EquipmentTypeSuffix = 'A' then (Capacity - 24)
	Else '0' End
	from ods.InventoryLeg il
	LEFT JOIN 
	AAII_CARRIER_MAPPING carr_map
	on carr_map.carriercode = il.carriercode
	and ltrim(RTRIM(carr_map.flightnumber)) = ltrim(RTRIM(il.flightnumber))
	
	where DepartureDate between @departureStart_Y1 and @DepartureEnd
	and Status <> 2
	and Lid >0
	and ltrim(rtrim(il.FlightNumber)) not in ('2994','2995','2996','2997','2998','2999')


	--select sum(Capacity) as Lid, CarrierCode, FlightNumber, DepartureStation+ArrivalStation as Route,
	--Cabin, DepartureDate, Year(DepartureDate) as Year, DATENAME(WW,DepartureDate) as WeekNum
	--from #temp_Inventory
	--where DepartureStation+ArrivalStation in ('AORKUL','KULAOR')
	--and DepartureDate between '2012-01-01' and '2012-01-31'
	--group by  CarrierCode, FlightNumber, DepartureStation+ArrivalStation,Cabin, DepartureDate
	
	
	
	
	----* Aggregation *----

		----* Aggregation @ ExtractionDate, Current Year *----
						
	BEGIN TRY TRUNCATE TABLE #Temp_TAAX_Weekly_Route_ALL DROP TABLE  #Temp_TAAX_Weekly_Route_ALL  END TRY BEGIN CATCH END CATCH
	select CAST(Convert(VARCHAR,@CapturedDate, 112) as datetime) as CapturedDate, A.YEAR, A.MONTH, A.WeekNumber, A.CarrierCode, A.Route, A.Cabin, 
	SUM(ISNULL(SeatsSold,0)) as SeatsSold, SUM(Capacity) as Capacity, SUM(ISNULL(BaseFare_THB,0)) as BaseFare_THB,
	SUM(ISNULL(FuelSurcharge_THB,0)) as FuelSurcharge_THB, 
	--newly added
	SUM(ISNULL(ThruFare_THB,0)) as ThruFare_THB, SUM(ISNULL(XHISEA_THB,0)) as XHISEA_THB, SUM(ISNULL(ADM_THB,0)) as ADM_THB,
	--newly added
	SUM(ISNULL(AncillaryAmount_THB,0)) as AncillaryAmount_THB
	into #Temp_TAAX_Weekly_Route_ALL
	from
		(select CarrierCode, FlightNumber, DepartureStation+ArrivalStation as Route,
		DepartureDate, Year(DepartureDate) as Year, DATENAME(MM, DepartureDate) as Month, DATENAME(WW,DepartureDate) as WeekNumber, 
		Cabin, sum(Capacity) as Capacity
		from #temp_Inventory
		group by CarrierCode, FlightNumber, DepartureStation+ArrivalStation,
		DepartureDate, Cabin) A
	left join	
		(select Year, MONTH, WeekNumber, DepartureDate, CarrierCode, FlightNumber, Route, 
		Cabin, SUM(BaseFare_THB) as BaseFare_THB, SUM(FuelSurcharge_THB) as FuelSurcharge_THB, 
		--newly added
		SUM(ThruFare_THB) as ThruFare_THB, SUM(XHISEA_THB) as XHISEA_THB, SUM(ADM_THB) as ADM_THB,
		--newly added
		SUM(SeatsSold) as SeatsSold, SUM(AncillaryAmount_THB) as AncillaryAmount_THB
		from #Temp_TAAX_Weekly_Route_ALLRM 
		group by CapturedDate, Year, MONTH, WeekNumber, DepartureDate, CarrierCode, FlightNumber, Route, 
		Cabin) B
		on A.CarrierCode = B.CarrierCode and A.FlightNumber = B.FlightNumber 
		and A.route = B.Route and A.DepartureDate = B.DepartureDate
		and A.Cabin = B.Cabin
	group by A.YEAR, A.MONTH, A.WeekNumber, A.CarrierCode, A.Route, A.Cabin
	
		
		--select * from #Temp_TAAX_Weekly_Route_ALL
		--where Route = 'CTUKUL'
		--and Month = 'March'
		--order by WeekNumber
		
			
	
		
		----* Aggregation @ ExtractionDate, Last Year *----
		
	BEGIN TRY TRUNCATE TABLE #Temp_TAAX_Weekly_Route_Y1_ALL DROP TABLE  #Temp_TAAX_Weekly_Route_Y1_ALL  END TRY BEGIN CATCH END CATCH
	select A.YEAR, A.MONTH, A.WeekNumber, A.CarrierCode,A.Route, A.Cabin, 
	SUM(ISNULL(SeatsSold_Y1,0)) as SeatsSold_Y1, SUM(Capacity_Y1) as Capacity_Y1, SUM(ISNULL(BaseFare_Y1_THB,0)) as BaseFare_Y1_THB,
	SUM(ISNULL(FuelSurcharge_Y1_THB,0)) as FuelSurcharge_Y1_THB, 
	--newly added
	SUM(ISNULL(ThruFare_Y1_THB,0)) as ThruFare_Y1_THB, SUM(ISNULL(XHISEA_Y1_THB,0)) as XHISEA_Y1_THB, SUM(ISNULL(ADM_Y1_THB,0)) as ADM_Y1_THB,
	--newly added
	SUM(ISNULL(AncillaryAmount_Y1_THB,0)) as AncillaryAmount_Y1_THB
	into #Temp_TAAX_Weekly_Route_Y1_ALL
	from
		(select CarrierCode, FlightNumber, DepartureStation+ArrivalStation as Route,
		DepartureDate, Year(DepartureDate) as Year, DATENAME(MM, DepartureDate) as Month, DATENAME(WW,DepartureDate) as WeekNumber, 
		Cabin, sum(Capacity) as Capacity_Y1
		from #temp_Inventory
		group by CarrierCode, FlightNumber, DepartureStation+ArrivalStation,
		DepartureDate, Cabin) A
	left join
		(select YEAR, MONTH, WeekNumber, DepartureDate, CarrierCode, FlightNumber, Route, 
		Cabin, SUM(ISNULL(BaseFare_THB,0)) as BaseFare_Y1_THB, SUM(ISNULL(FuelSurcharge_THB,0)) as FuelSurcharge_Y1_THB,
		--newly added
		SUM(ISNULL(ThruFare_THB,0)) as ThruFare_Y1_THB, SUM(ISNULL(XHISEA_THB,0)) as XHISEA_Y1_THB, SUM(ISNULL(ADM_THB,0)) as ADM_Y1_THB,
		--newly added
		SUM(SeatsSold) as SeatsSold_Y1, SUM(ISNULL(AncillaryAmount_THB,0)) as AncillaryAmount_Y1_THB
		from  #Temp_TAAX_Weekly_Route_Y1_ALLRM
		group by CapturedDate, Year, MONTH, WeekNumber, DepartureDate, CarrierCode, FlightNumber, Route, 
		Cabin) B
		on A.CarrierCode = B.CarrierCode and A.FlightNumber = B.FlightNumber 
		and A.DepartureDate = B.DepartureDate and A.Cabin = B.Cabin
		and A.Route = B.Route
	group by A.YEAR, A.MONTH, A.WeekNumber, A.CarrierCode,A.Route, A.Cabin
			
		--select sum(seatsSold_Y1) as SeatsSold_Y1, Route, Cabin, StartWeek
		--from #Temp_TAAX_Weekly_Route_Y1_ALL
		--where Route in ('BDOKUL')
		--and Month = 'January'
		--group by Route, Cabin, StartWeek
		--order by startweek,route
		

	----* Aggregation @ MonthEnd, Last Year *----
		
	BEGIN TRY TRUNCATE TABLE #Temp_TAAX_Weekly_Route_Y1M_ALL DROP TABLE  #Temp_TAAX_Weekly_Route_Y1M_ALL  END TRY BEGIN CATCH END CATCH
	select A.YEAR, A.MONTH, A.WeekNumber, A.CarrierCode, A.Route, A.Cabin,
	SUM(ISNULL(SeatsSold_Y1M,0)) as SeatsSold_Y1M, SUM(Capacity_Y1M) as Capacity_Y1M, SUM(BaseFare_Y1M_THB) as BaseFare_Y1M_THB, 
	SUM(FuelSurcharge_Y1M_THB) as FuelSurcharge_Y1M_THB, 
	--newly added
	SUM(ISNULL(ThruFare_Y1M_THB,0)) as ThruFare_Y1M_THB, SUM(ISNULL(XHISEA_Y1M_THB,0)) as XHISEA_Y1M_THB, SUM(ISNULL(ADM_Y1M_THB,0)) as ADM_Y1M_THB,
	--newly added
	SUM(AncillaryAmount_Y1M_THB) as AncillaryAmount_Y1M_THB
	into #Temp_TAAX_Weekly_Route_Y1M_ALL
	from
		(select CarrierCode, FlightNumber, DepartureStation+ArrivalStation as Route,
		DepartureDate, Year(DepartureDate) as Year, DATENAME(MM, DepartureDate) as Month, DATENAME(WW,DepartureDate) as WeekNumber, 
		Cabin, sum(Capacity) as Capacity_Y1M
		from #temp_Inventory
		group by CarrierCode, FlightNumber, DepartureStation+ArrivalStation,
		DepartureDate, Cabin) A
	left join
		(select YEAR, MONTH, WeekNumber, DepartureDate, CarrierCode, FlightNumber, Route, 
		Cabin, SUM(BaseFare_THB) as BaseFare_Y1M_THB, SUM(FuelSurcharge_THB) as FuelSurcharge_Y1M_THB, 
		--newly added
		SUM(ISNULL(ThruFare_THB,0)) as ThruFare_Y1M_THB, SUM(ISNULL(XHISEA_THB,0)) as XHISEA_Y1M_THB, SUM(ISNULL(ADM_THB,0)) as ADM_Y1M_THB,
		--newly added
		SUM(SeatsSold) as SeatsSold_Y1M, SUM(AncillaryAmount_THB) as AncillaryAmount_Y1M_THB
		from #Temp_TAAX_Weekly_Route_Y1M_ALLRM 
		group by CapturedDate, Year, MONTH, WeekNumber, DepartureDate, CarrierCode, FlightNumber, Route, 
		Cabin) B
		on A.CarrierCode = B.CarrierCode and A.FlightNumber = B.FlightNumber 
		and A.Route = B.Route and A.DepartureDate = B.DepartureDate
		and A.Cabin = B.Cabin
	group by A.YEAR, A.MONTH, A.WeekNumber, A.CarrierCode, A.Route, A.Cabin
		--select sum(seatsSold_Y1M) as SeatsSold_Y1M, sum(Capacity_Y1M) as Capacity_Y1M,
		--CarrierCode, Route, Cabin, Month, WeekNumber
		--from #Temp_TAAX_Weekly_Route_Y1M_ALL
		--where Route in ('BDOKUL')
		--and Year = 2011
		--group by Carriercode, Route, Cabin, Month,  WeekNumber
		--order by WeekNumber, Month, route

	
		--select * from #Temp_TAAX_Weekly_Route_ALL where Capacity is not null and Route = 'AORKUL' order by WeekNumber
		--select * into Temp_TAAX_Weekly_Route_ALL from  #Temp_TAAX_Weekly_Route_ALL  where Route = 'BKIKUL' and FlightNumber = '5123' and StartWeek = '2011-01-10 00:00:00.000'
		--select * into Temp_TAAX_Weekly_Route_Y1_ALL from #Temp_TAAX_Weekly_Route_Y1_ALL  where Route = 'BKIKUL' and FlightNumber = '5123' and StartWeek = '2010-01-10 00:00:00.000'
		--select * into Temp_TAAX_Weekly_Route_Y1M_ALL from #Temp_TAAX_Weekly_Route_Y1M_ALL where Route = 'BKIKUL' and FlightNumber = '5123' and StartWeek = '2010-01-10 00:00:00.000'
		

		
	
	----* Aggregation final *----


	--Note : Aggregate by week (WNum)--

	BEGIN TRY TRUNCATE TABLE SAT_Temp_TAAX_Weekly_Route_final DROP TABLE SAT_Temp_TAAX_Weekly_Route_final  END TRY BEGIN CATCH END CATCH
	select distinct CapturedDate, H.YEAR, H.MONTH, H.WeekNumber, H.CarrierCode, H.Cabin, H.Route2 as Sector, 
	Distance, MarketGroup  as Route, F.Country, G.Region, 
	MonthNumber = CASE WHEN month = 'January' THEN '01'
	WHEN month = 'February' THEN '02' WHEN month = 'March' THEN '03'
	WHEN month = 'April' THEN '04' WHEN month = 'May' THEN '05'
	WHEN month = 'June' THEN '06' WHEN month = 'July' THEN '07'
	WHEN month = 'August' THEN '08' WHEN month = 'September' THEN '09'
	WHEN month = 'October' THEN '10' WHEN month = 'November' THEN '11'
	WHEN month = 'December' THEN '12' ELSE 'unknown' END,
	SeatsSold, Capacity, BaseFare_THB, FuelSurcharge_THB, 
	--newly added
	ThruFare_THB, XHISEA_THB, ADM_THB,
	--newly added
	AncillaryAmount_THB, 
	SeatsSold_Y1,Capacity_Y1, BaseFare_Y1_THB, FuelSurcharge_Y1_THB, 
	--newly added
	ThruFare_Y1_THB, XHISEA_Y1_THB, ADM_Y1_THB,
	--newly added
	AncillaryAmount_Y1_THB,
	SeatsSold_Y1M, Capacity_Y1M, BaseFare_Y1M_THB, FuelSurcharge_Y1M_THB, 
	--newly added
	ThruFare_Y1M_THB, XHISEA_Y1M_THB, ADM_Y1M_THB,
	--newly added
	AncillaryAmount_Y1M_THB
	into SAT_Temp_TAAX_Weekly_Route_final
	from
		(select CapturedDate, A.YEAR, A.MONTH, A.WeekNumber, A.CarrierCode, A.Route2, 
		A.Cabin,  
		SeatsSold, Capacity, BaseFare_THB, FuelSurcharge_THB, /*newly added*/ThruFare_THB, XHISEA_THB, ADM_THB,/*newly added*/ AncillaryAmount_THB, 
		SeatsSold_Y1,Capacity_Y1, BaseFare_Y1_THB, FuelSurcharge_Y1_THB,/*newly added*/ThruFare_Y1_THB, XHISEA_Y1_THB, ADM_Y1_THB, /*newly added*/AncillaryAmount_Y1_THB,
		SeatsSold_Y1M, Capacity_Y1M, BaseFare_Y1M_THB, FuelSurcharge_Y1M_THB, /*newly added*/ThruFare_Y1M_THB, XHISEA_Y1M_THB, ADM_Y1M_THB, /*newly added*/AncillaryAmount_Y1M_THB
		from
			(select CapturedDate, YEAR, MONTH, WeekNumber, CarrierCode, 
			Route2 = case when Route = 'KULSTN' then 'KULLGW'
			when Route = 'STNKUL' then 'LGWKUL' 
			when Route = 'TSNKUL' then 'PEKKUL' 
			when Route = 'KULTSN' then 'KULPEK' 
			Else Route End,
			Cabin, ISNULL(SeatsSold,0) as SeatsSold, Capacity, 
			ISNULL(BaseFare_THB,0) as BaseFare_THB, ISNULL(FuelSurcharge_THB,0) as FuelSurcharge_THB,
			--newly added
			ISNULL(ThruFare_THB,0) as ThruFare_THB, ISNULL(XHISEA_THB,0) as XHISEA_THB, ISNULL(ADM_THB,0) as ADM_THB,
			--newly added
			ISNULL(AncillaryAmount_THB,0) as AncillaryAmount_THB
			from #Temp_TAAX_Weekly_Route_ALL
			where Capacity is not null
			and YEAR = YEAR(CapturedDate)) A
		left join
			(select YEAR, Year+1 as Year1, MONTH, WeekNumber, CarrierCode, 
			Route2 = case when Route = 'KULSTN' then 'KULLGW'
			when Route = 'STNKUL' then 'LGWKUL' 
			when Route = 'TSNKUL' then 'PEKKUL' 
			when Route = 'KULTSN' then 'KULPEK' 
			Else Route End,
			Cabin, ISNULL(SeatsSold_Y1,0) as SeatsSold_Y1, Capacity_Y1, 
			ISNULL(BaseFare_Y1_THB,0) as BaseFare_Y1_THB, 
			ISNULL(FuelSurcharge_Y1_THB,0) as FuelSurcharge_Y1_THB,
			--newly added
			ISNULL(ThruFare_Y1_THB,0) as ThruFare_Y1_THB, ISNULL(XHISEA_Y1_THB,0) as XHISEA_Y1_THB, ISNULL(ADM_Y1_THB,0) as ADM_Y1_THB,
			--newly added
			ISNULL(AncillaryAmount_Y1_THB,0) as AncillaryAmount_Y1_THB
			from #Temp_TAAX_Weekly_Route_Y1_ALL
			where Capacity_Y1 is not null) B
			on A.CarrierCode = B.Carriercode and A.Cabin = B.Cabin
			and A.WeekNumber =  B.WeekNumber and A.Route2 = B.Route2
			and A.Month = B.Month and A.Year = B.Year1
		left join
			(select YEAR, Year+1 as Year1, MONTH, WeekNumber, CarrierCode,
			Route2 = case when Route = 'KULSTN' then 'KULLGW'
			when Route = 'STNKUL' then 'LGWKUL' 
			when Route = 'TSNKUL' then 'PEKKUL' 
			when Route = 'KULTSN' then 'KULPEK'
			Else Route End, 
			Cabin, ISNULL(SeatsSold_Y1M,0) as SeatsSold_Y1M, Capacity_Y1M, 
			ISNULL(BaseFare_Y1M_THB,0) as BaseFare_Y1M_THB, 
			ISNULL(FuelSurcharge_Y1M_THB,0) as FuelSurcharge_Y1M_THB,
			--newly added
			ISNULL(ThruFare_Y1M_THB,0) as ThruFare_Y1M_THB, ISNULL(XHISEA_Y1M_THB,0) as XHISEA_Y1M_THB, ISNULL(ADM_Y1M_THB,0) as ADM_Y1M_THB,
			--newly added
			ISNULL(AncillaryAmount_Y1M_THB,0) as AncillaryAmount_Y1M_THB
			from #Temp_TAAX_Weekly_Route_Y1M_ALL
			where Capacity_Y1M is not null) C
			on A.CarrierCode = C.CarrierCode and A.Cabin = C.Cabin
			and A.WeekNumber = C.WeekNumber and A.Route2 = C.Route2
			and A.Month = C.Month and A.YEAR = C.Year1
			
			
		union
		select CapturedDate, A.YEAR, A.MONTH, A.WeekNumber, A.CarrierCode, A.Route2, 
		A.Cabin,
		/*  
		SeatsSold, Capacity, BaseFare_THB, FuelSurcharge_THB, AncillaryAmount_THB, 
		SeatsSold_Y1,Capacity_Y1, BaseFare_Y1_THB, FuelSurcharge_Y1_THB, AncillaryAmount_Y1_THB,
		SeatsSold_Y1M, Capacity_Y1M, BaseFare_Y1M_THB, FuelSurcharge_Y1M_THB, AncillaryAmount_Y1M_THB
		*/
		SeatsSold, Capacity, BaseFare_THB, FuelSurcharge_THB, /*newly added*/ThruFare_THB, XHISEA_THB, ADM_THB,/*newly added*/ AncillaryAmount_THB, 
		SeatsSold_Y1,Capacity_Y1, BaseFare_Y1_THB, FuelSurcharge_Y1_THB,/*newly added*/ThruFare_Y1_THB, XHISEA_Y1_THB, ADM_Y1_THB, /*newly added*/AncillaryAmount_Y1_THB,
		SeatsSold_Y1M, Capacity_Y1M, BaseFare_Y1M_THB, FuelSurcharge_Y1M_THB, /*newly added*/ThruFare_Y1M_THB, XHISEA_Y1M_THB, ADM_Y1M_THB, /*newly added*/AncillaryAmount_Y1M_THB
		
		from
			(select 
			CapturedDate, YEAR, MONTH, WeekNumber, CarrierCode, 
			Route2 = case when Route = 'KULSTN' then 'KULLGW'
			when Route = 'STNKUL' then 'LGWKUL' 
			when Route = 'TSNKUL' then 'PEKKUL' 
			when Route = 'KULTSN' then 'KULPEK' 
			Else Route End, 
			Cabin, ISNULL(SeatsSold,0) as SeatsSold, Capacity, 
			ISNULL(BaseFare_THB,0) as BaseFare_THB, ISNULL(FuelSurcharge_THB,0) as FuelSurcharge_THB,
			--newly added
			ISNULL(ThruFare_THB,0) as ThruFare_THB, ISNULL(XHISEA_THB,0) as XHISEA_THB, ISNULL(ADM_THB,0) as ADM_THB,
			--newly added
			ISNULL(AncillaryAmount_THB,0) as AncillaryAmount_THB
			from #Temp_TAAX_Weekly_Route_ALL
			where Capacity is not null
			and YEAR = YEAR(CapturedDate)+1) A
		left join
			(select YEAR, Year+1 as Year1, MONTH, WeekNumber, CarrierCode,
			Route2 = case 
			when Route = 'KULSTN' then 'KULLGW'
			when Route = 'STNKUL' then 'LGWKUL' 
			when Route = 'TSNKUL' then 'PEKKUL' 
			when Route = 'KULTSN' then 'KULPEK' 
			Else Route End, 
			Cabin, ISNULL(SeatsSold_Y1,0) as SeatsSold_Y1, Capacity_Y1, 
			ISNULL(BaseFare_Y1_THB,0) as BaseFare_Y1_THB, 
			ISNULL(FuelSurcharge_Y1_THB,0) as FuelSurcharge_Y1_THB,
			--newly added
			ISNULL(ThruFare_Y1_THB,0) as ThruFare_Y1_THB, ISNULL(XHISEA_Y1_THB,0) as XHISEA_Y1_THB, ISNULL(ADM_Y1_THB,0) as ADM_Y1_THB,
			--newly added
			ISNULL(AncillaryAmount_Y1_THB,0) as AncillaryAmount_Y1_THB
			from #Temp_TAAX_Weekly_Route_Y1_ALL
			where Capacity_Y1 is not null) B
			on A.CarrierCode = B.Carriercode and A.Cabin = B.Cabin
			and A.WeekNumber =  B.WeekNumber and A.Route2 = B.Route2
			and A.Month = B.Month and A.Year = B.Year1
		left join
			(select YEAR, Year+1 as Year1, MONTH, WeekNumber, CarrierCode, 
			Route2 = case when Route = 'KULSTN' then 'KULLGW'
			when Route = 'STNKUL' then 'LGWKUL' 
			when Route = 'TSNKUL' then 'PEKKUL' 
			when Route = 'KULTSN' then 'KULPEK' 
			Else Route End, 
			Cabin, 
			ISNULL(SeatsSold,0) as SeatsSold_Y1M, Capacity as Capacity_Y1M, 
			ISNULL(BaseFare_THB,0) as BaseFare_Y1M_THB, 
			ISNULL(FuelSurcharge_THB,0) as FuelSurcharge_Y1M_THB,
			--newly added
			ISNULL(ThruFare_THB,0) as ThruFare_Y1M_THB, ISNULL(XHISEA_THB,0) as XHISEA_Y1M_THB, ISNULL(ADM_THB,0) as ADM_Y1M_THB,
			--newly added
			ISNULL(AncillaryAmount_THB,0) as AncillaryAmount_Y1M_THB
			from #Temp_TAAX_Weekly_Route_ALL
			where Capacity is not null) C
			on A.CarrierCode = C.CarrierCode and A.Cabin = C.Cabin
			and A.WeekNumber = C.WeekNumber and A.Route2 = C.Route2
			and A.Month = C.Month and A.YEAR = C.Year1) H
	left join
		(select DepartureStation+ArrivalStation as Route, ActualDistance as Distance,
		substring(citypairgroup,1,3) + SUBSTRING(CityPairGroup,5,3) as MarketGroup
		from dw.CityPair) D
		on H.Route2 = D.Route 	
	left join
		(select CarrierCode, DepartureStation+ArrivalStation as Route, TravelCountry as Country
		from SAT_vw_TravelCountry) F
		on H.CarrierCode = F.CarrierCode and H.Route2 = F.Route
	left join
		(select distinct Country, Region
		from SAT_vw_Region) G
		on LTRIM(RTRIM(F.Country)) = LTRIM(RTRIM(G.Country))
		
		update SAT_Temp_TAAX_Weekly_Route_final
		set Distance = Distance_km 
		from  AAX_Distance B
		where Route = ODPair
		
	
		--select * from SAT_Temp_TAAX_Weekly_Route_final where Route = 'HGHKUL'
		--select * from #Temp_TAAX_Weekly_Route_ALL where Capacity is not null and Route = 'AORKUL' order by WeekNumber
		--select * into Temp_TAAX_Weekly_Route_ALL from  #Temp_TAAX_Weekly_Route_ALL  where Route = 'BKIKUL' and FlightNumber = '5123' and StartWeek = '2011-01-10 00:00:00.000'
		--select * into Temp_TAAX_Weekly_Route_Y1_ALL from #Temp_TAAX_Weekly_Route_Y1_ALL  where Route = 'BKIKUL' and FlightNumber = '5123' and StartWeek = '2010-01-10 00:00:00.000'
		--select * into Temp_TAAX_Weekly_Route_Y1M_ALL from #Temp_TAAX_Weekly_Route_Y1M_ALL where Route = 'BKIKUL' and FlightNumber = '5123' and StartWeek = '2010-01-10 00:00:00.000'
		

	
END













GO


