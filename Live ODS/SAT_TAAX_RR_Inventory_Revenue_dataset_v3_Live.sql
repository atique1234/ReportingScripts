USE [REZAKWB01]
GO

/****** Object:  StoredProcedure [wb].[SAT_TAAX_RR_Inventory_Revenue_dataset_v3_Live]    Script Date: 10/23/2015 12:08:51 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO















-- =============================================
-- Author:		<Matthew Oh> <Jenn Kok>
-- Create date: <2014-03-04,,> <2014-04-23>
-- Description:	<ROUTE REVENUE AAX - 12 MONTHS INVENTORY + REVENUE>
-- =============================================

--ALTER PROCEDURE [wb].[SAT_TAAX_RR_Inventory_Revenue_dataset_v3_Live]

--AS
BEGIN
	-- SET NOCOUNT ON added to prevent extra result sets from
	-- interfering with SELECT statements.
	SET NOCOUNT ON;
	

	DECLARE @endDateUTC			 datetime,
			@MYDateUTC			 datetime,
			@departureStart      datetime,
			@departureEnd		 datetime
 

	--SET @MYDateUTC ='2015-06-05'
	--AK:it should be getdate
	select @MYDateUTC  = ods.ConvertDate( 'MY', GETDATE(),0,0)
	SET @endDateUTC   = CAST(CONVERT(VARCHAR, DATEADD(day, 1, @MYDateUTC-1), 101) AS DateTime)
	  
	 --SET @departureStart =CAST(CONVERT(VARCHAR, DATEADD(s, 1,DATEADD(mm, DATEDIFF(m,0,DateAdd(month,0,@MYDateUTC)),0)), 101) AS DateTime) 
	SET @departureStart =CAST(CONVERT(VARCHAR, DATEADD(YEAR, DATEDIFF(YEAR, 0, @MYDateUTC-2), 0), 101) AS DateTime) 
	SET @departureEnd   =CAST(CONVERT(VARCHAR,DATEADD(s, -1,DATEADD(mm, DATEDIFF(m,12,DateAdd(month,12,@MYDateUTC)),0))) AS DateTime) 
	print @MYDateUTC 
	print @endDateUTC
	print @departureStart
	print @departureEnd
	
	
--SeatsSold, BaseRevenue_RM --	

	--drop table #SeatsSold_BaseRevRM
	
	
	BEGIN TRY TRUNCATE TABLE SAT_PassengerID_TAAX_v3_BaseRevRM DROP TABLE SAT_PassengerID_TAAX_v3_BaseRevRM END TRY BEGIN CATCH END CATCH 
	select distinct CAST(Convert(VARCHAR,@MYDateUTC-1, 112) as datetime) as CapturedDate,
	DATEPART(DAYOFYEAR,@MYDateUTC-1) as dayOfYear,
	DATEPART(DW,@MYDateUTC-1) as dayOfWeek,
	A.PassengerID, RecordLocator, DepartureDate, 
	(CASE WHEN CarrierCode = 'D7' THEN 'XJ' ELSE CarrierCode END) CarrierCode, FlightNumber, Route, Cabin, 
	FareClassOfService, FareClass, CurrencyCode, CreatedAgentID,
	sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))/ISNULL(L.ConversionRate,1)) as BaseFare_THB,
	sum(ISNULL(Fuel_Amt,0)/(ISNULL(L.ConversionRate,1))) as FuelSurcharge_THB,
	sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))/ISNULL(MY.ConversionRate,1)) as BaseFare_MYR,
	sum(ISNULL(Fuel_Amt,0)/(ISNULL(MY.ConversionRate,1))) as FuelSurcharge_MYR
	--SUM(SSRAmount/ISNULL(ConversionRate,1))
	into SAT_PassengerID_TAAX_v3_BaseRevRM
	from
		(
		select t.PassengerID, t.SegmentID, t.DepartureDate,t.Route,
		isnull(carr_map.mappedcarrier ,t.CARRIERCODE) CarrierCode,
		t.FlightNumber, t.FareClassOfService,t.Cabin,t.CreatedDate, t.CreatedAgentID
		 from
		(select 
			PassengerID, SegmentID, DepartureDate, 
			DepartureStation+ArrivalStation as Route, CarrierCode, FlightNumber, FareClassOfService,
			Cabin = case when FareClassofService in ('C','D','G','J','G1') then 'Premium'
			Else 'Economy' End,	CreatedDate, CreatedAgentID
			from vw_PassengerJourneySegment
			where BookingStatus = 'HK' 
			and DATEADD(HH,8,CreatedDate) < @endDateUTC
			--and DepartureDate between '2013-12-01' and @departureEnd
			and DepartureDate between @departureStart and @departureEnd
			
		)t
		LEFT JOIN 
		AAII_CARRIER_MAPPING carr_map
		on carr_map.carriercode = t.carriercode
		and ltrim(RTRIM(carr_map.flightnumber)) = ltrim(RTRIM(t.flightnumber))
		Where  (isnull(carr_map.mappedcarrier ,t.CARRIERCODE) = 'XJ' OR
			ltrim(rtrim(isnull(carr_map.mappedcarrier ,t.CARRIERCODE)))+ltrim(rtrim(t.FlightNumber)) = 'D7620' OR 
			ltrim(rtrim(isnull(carr_map.mappedcarrier ,t.CARRIERCODE)))+ltrim(rtrim(t.FlightNumber)) = 'D7621')
		) A
	left join
		(select PassengerID, SegmentID, (ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as Fare_Amt
		from
			(select PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge
			where ChargeType in ('0')) C
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix) D
			on C.ChargeType = D.ChargeTypeID) E
		on A.SegmentID = E.SegmentID and A.PassengerID = E.PassengerID
	left join 
		(select PassengerID, SegmentID, (ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as Disc_Amt
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
		(select PassengerID, SegmentID, (ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as Promo_Amt
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
		group by PassengerID, SegmentID) Q		
		on A.SegmentID = Q.SegmentID and A.PassengerID = Q.PassengerID 	
	left join
		(select PassengerID, BookingID
		from ods.BookingPassenger) M
		on A.PassengerID = M.PassengerID
	left join
		(Select BookingID, RecordLocator, CurrencyCode
		from ods.Booking) N
		on M.BookingID = N.BookingID
	/*
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionDate, ConversionRate
		from SAT_AAX_CurrencyConversion_BNM with (nolock)
		where ToCurrencyCode = 'THB')  L
		on CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = L.ConversionDate and L.FromCurrencyCode = N.CurrencyCode
	*/

	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionDate, ConversionRate
		from dw.CurrencyconversionHistoryDecompressed with (nolock)	
		where FromCurrencyCode = 'THB') L
		on CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = L.ConversionDate and N.CurrencyCode = L.ToCurrencyCode

	-- NEWLY ADDED ---
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionDate, ConversionRate
		from dw.CurrencyconversionHistoryDecompressed with (nolock)	
		where FromCurrencyCode = 'MYR') MY
		on CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = MY.ConversionDate and N.CurrencyCode = MY.ToCurrencyCode
		
	left join
		(select distinct ClassOfService, FareClass
		from SAT_FareClasOfService) O
		on A.FareClassOfService = O.ClassOfService
	group by A.PassengerID, DepartureDate, CarrierCode, FlightNumber, Route, RecordLocator, CurrencyCode, FareClassOfService,
	FareClass, CurrencyCode, Cabin, CreatedAgentID
	
	
	--select distinct a.carriercode,a.flightnumber,a.route,a.cabin,a.basefare_rm
	--from SAT_PassengerID_TAAX_v3_BaseRevRM a
	--join SAT_PassengerID_TAAX_v3_BaseRevRM b on a.flightnumber = b.flightnumber and a.route = b.route and a.cabin = b.cabin
	
	--where ltrim(rtrim(a.flightnumber)) = '621' and datepart (mm, a.departuredate) = '06'
	--and a.flightnumber = b.flightnumber and a.route = b.route and a.cabin = b.cabin and a.basefare_rm = b.basefare_rm
	--and a.carriercode <> b.carriercode
	----and a.passengerid = '256953804'
	--order by a.flightnumber, a.route, a.cabin
	
	
	--AncillaryRevenue_Amount--	

	--SELECT TOP 100 * FROM SAT_PassengerID_TAAX_v3_BaseRevRM
	--WHERE LTRIM(RTRIM(FLIGHTNUMBER)) = '621' 
		
	BEGIN TRY TRUNCATE TABLE #SeatsSold_AAX_Ancillaries DROP TABLE #SeatsSold_AAX_Ancillaries END TRY BEGIN CATCH END CATCH
	Select distinct A.PassengerId,B.FeeNumber,B.FeeCode,B.DepartureDate,
	(CASE WHEN B.CarrierCode = 'D7' THEN 'XJ' ELSE B.CarrierCode END) CarrierCode,B.FlightNumber,B.DepartureStation,B.ArrivalStation,
	C.CurrencyCode, C.CreatedDate, (C.ChargeAmount * D.PositiveNegativeFlag) As ChargeAmount
	Into #SeatsSold_AAX_Ancillaries
	From SAT_PassengerID_TAAX_v3_BaseRevRM A 
	left Join vw_PassengerFee B  With (NoLock) On A.PassengerId = B.PassengerId 
	left Join ods.PassengerFeeCharge C With (NoLock)  On B.PassengerId = C.PassengerId  And B.FeeNumber = C.FeeNumber
	left Join dw.ChargeTypeMatrix D With (NoLock) On C.ChargeType = D.ChargeTypeID
	where (B.CarrierCode = 'XJ' OR
	ltrim(rtrim(B.CarrierCode))+ltrim(rtrim(B.FlightNumber)) = 'D7620' OR 
		ltrim(rtrim(B.CarrierCode))+ltrim(rtrim(B.FlightNumber)) = 'D7621')
	--Group By A.PassengerId,B.FeeNumber,B.FeeCode,B.DepartureDate,B.CarrierCode,B.FlightNumber,
	--B.DepartureStation,B.ArrivalStation,C.CurrencyCode, C.CreatedDate

	
	--select * from #SeatsSold_AAX_Ancillaries where carriercode = 'D7'
	
	
	BEGIN TRY TRUNCATE TABLE #SeatsSold_AAX_AncillariesRM DROP TABLE #SeatsSold_AAX_AncillariesRM END TRY BEGIN CATCH END CATCH
	Select A.PassengerId,A.DepartureDate,A.CarrierCode,A.FlightNumber,A.DepartureStation+A.ArrivalStation as route,A.CurrencyCode,
	Sum(ISNULL(A.ChargeAmount,0)/ISNULL(B.ConversionRate,1)) AS AncillaryAmount_THB,
	Sum(ISNULL(A.ChargeAmount,0)/ISNULL(MY.ConversionRate,1)) AS AncillaryAmount_MYR
	Into #SeatsSold_AAX_AncillariesRM
	from
		(select PassengerId,DepartureDate,CarrierCode,FlightNumber,DepartureStation,ArrivalStation,CurrencyCode,
		ChargeAmount, CreatedDate
		from #SeatsSold_AAX_Ancillaries
		where CarrierCode = 'XJ'
		and Flightnumber <> ' ' 
		and DepartureStation <> ' ' 
		and ArrivalStation <> ' ') A 
	/*
	left Join 
		(select ConversionDate, FromCurrencyCode, ToCurrencyCode, ConversionRate
		from SAT_AAX_CurrencyConversion_BNM with (nolock)
		where ToCurrencyCode = 'THB') B
		on CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = B.ConversionDate and B.FromCurrencyCode = A.CurrencyCode
	*/	
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionDate, ConversionRate
		from dw.CurrencyconversionHistoryDecompressed with (nolock)	
		where FromCurrencyCode = 'THB') B
		on CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = B.ConversionDate and A.CurrencyCode = B.ToCurrencyCode
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionDate, ConversionRate
		from dw.CurrencyconversionHistoryDecompressed with (nolock)	
		where FromCurrencyCode = 'MYR') MY
		on CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = MY.ConversionDate and A.CurrencyCode = MY.ToCurrencyCode
	group by A.PassengerId,A.DepartureDate,A.CarrierCode,A.FlightNumber,A.DepartureStation,A.ArrivalStation, A.CurrencyCode
	

	--select top 1000* from #SeatsSold_AAX_AncillariesRM where PassengerID = 198810636
	
	BEGIN TRY TRUNCATE TABLE #SeatsSold_AAX_ALLRM DROP TABLE #SeatsSold_AAX_ALLRM END TRY BEGIN CATCH END CATCH
	select distinct CapturedDate, dayOfYear, dayOfWeek, count(A.PassengerID)as SeatsSold, RecordLocator, 
	A.DepartureDate, A.CarrierCode, A.FlightNumber, A.Route, FareClassOfService, FareClass, Cabin, CurrencyCode,
	sum(BaseFare_THB) as BaseFare_THB, sum(FuelSurcharge_THB) as FuelSurcharge_THB, 
	sum(BaseFare_MYR) as BaseFare_MYR, sum(FuelSurcharge_MYR) as FuelSurcharge_MYR,
	ISNULL(SUM(AncillaryAmount_THB),0) as AncillaryAmount_THB,
	ISNULL(SUM(AncillaryAmount_MYR),0) as AncillaryAmount_MYR
	into #SeatsSold_AAX_ALLRM
	from
		(select distinct CapturedDate, dayOfYear, dayOfWeek, PassengerID, RecordLocator, 
		DepartureDate, CarrierCode, FlightNumber, Route, FareClassOfService, FareClass, Cabin, CurrencyCode,
		BaseFare_THB, FuelSurcharge_THB, BaseFare_MYR, FuelSurcharge_MYR
		from SAT_PassengerID_TAAX_v3_BaseRevRM) A
	left join
		(select distinct PassengerID, DepartureDate, CarrierCode, FlightNumber, route,
		AncillaryAmount_THB as AncillaryAmount_THB, AncillaryAmount_MYR as AncillaryAmount_MYR
		from #SeatsSold_AAX_AncillariesRM) B
		on A.PassengerID = B.PassengerID and A.Carriercode = B.CarrierCode and A.FlightNumber = B.Flightnumber
		and A.DepartureDate = B.DepartureDate and A.Route = B.Route
	group by CapturedDate, dayOfYear, dayOfWeek,RecordLocator, 
	A.DepartureDate, A.CarrierCode, A.FlightNumber, A.Route, FareClassOfService, FareClass, Cabin, CurrencyCode
	
	
	
	--select top 10000*
	--from #SeatsSold_AAX_ALLRM
	--where RecordLocator = 'A198ML'
	

	
		----* Capacity *----
			
	BEGIN TRY TRUNCATE TABLE #Inventory_AAX DROP TABLE  #Inventory_AAX  END TRY BEGIN CATCH END CATCH
	select distinct InventoryLegKey, Convert(datetime,Convert(varchar(12),DateAdd(day,0,@MYDateUTC-1),113)) AS CapturedDate,
	DATEPART(DAYOFYEAR,@MYDateUTC-1) as dayOfYear,	DATEPART(DW,@MYDateUTC-1) as dayOfWeek,
	Year(DepartureDate) as DepartureYear, DATENAME(MM,DepartureDate) as DepartureMonth, departureDate,
	(CASE WHEN isnull(carr_map.mappedcarrier ,A.CARRIERCODE) = 'D7' THEN 'XJ' ELSE isnull(carr_map.mappedcarrier ,A.CARRIERCODE) END) CarrierCode, 
	A.FlightNumber, A.DepartureStation, A.ArrivalStation,
	substring(citypairgroup,1,3) + SUBSTRING(CityPairGroup,5,3) as ODPAIR,
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
	when EquipmentType = 333 and EquipmentTypeSuffix = 'A' then 12
	Else '0' End
	into #Inventory_AAX
	from ods.InventoryLeg A
	LEFT JOIN 
	AAII_CARRIER_MAPPING carr_map
	on carr_map.carriercode = A.carriercode
	and ltrim(RTRIM(carr_map.flightnumber)) = ltrim(RTRIM(A.flightnumber))
	
	left join dw.CityPair B on A.DepartureStation = B.DEpartureStation and A.ArrivalStation = B.ArrivalStation
	--where DepartureDate between '2013-12-01' and @DepartureEnd
	where DepartureDate between @departureStart and @departureEnd
	and (isnull(carr_map.mappedcarrier ,A.CARRIERCODE) = 'XJ' OR
	ltrim(rtrim(isnull(carr_map.mappedcarrier ,A.CARRIERCODE)))+ltrim(rtrim(A.FlightNumber)) = 'D7620' OR 
		ltrim(rtrim(isnull(carr_map.mappedcarrier ,A.CARRIERCODE)))+ltrim(rtrim(A.FlightNumber)) = 'D7621')
	--and FlightNumber not in ('2994','2995','2996','2997','2998','2999')
	and Lid >0
	and status <>2
	union
	select distinct InventoryLegKey, Convert(datetime,Convert(varchar(12),DateAdd(day,0,@MYDateUTC-1),113)) AS CapturedDate,
	DATEPART(DAYOFYEAR,@MYDateUTC-1) as dayOfYear,	DATEPART(DW,@MYDateUTC-1) as dayOfWeek,
	Year(DepartureDate) as DepartureYear, DATENAME(MM,DepartureDate) as DepartureMonth, departureDate,
	(CASE WHEN isnull(carr_map.mappedcarrier ,A.CARRIERCODE) = 'D7' THEN 'XJ' ELSE isnull(carr_map.mappedcarrier ,A.CARRIERCODE) END) CarrierCode, 
	A.FlightNumber, A.DepartureStation, A.ArrivalStation,
	substring(citypairgroup,1,3) + SUBSTRING(CityPairGroup,5,3) as ODPAIR,
	EquipmentType, EquipmentTypeSuffix, Cabin = 'Economy',
	Capacity = case when EquipmentType = 320 and EquipmentTypeSuffix = 'A' then Capacity
	when EquipmentType = 733 and EquipmentTypeSuffix = 'A' then Capacity
	when EquipmentType = 330 and EquipmentTypeSuffix = 'A' then (Capacity - 12)
	when EquipmentType = 330 and EquipmentTypeSuffix = 'B' then (Capacity - 12)
	when EquipmentType = 330 and EquipmentTypeSuffix = 'C' then (Capacity - 12)
	when EquipmentType = 330 and EquipmentTypeSuffix = 'D' then (Capacity - 10)
	when EquipmentType = 330 and EquipmentTypeSuffix = 'E' then (Capacity - 12)
	when EquipmentType = 330 and EquipmentTypeSuffix = 'F' then (Capacity - 12)
	when EquipmentType = 340 and EquipmentTypeSuffix = 'A' then (Capacity - 18)
	when EquipmentType = 340 and EquipmentTypeSuffix = 'B' then (Capacity - 18)
	when EquipmentType = 332 and EquipmentTypeSuffix = 'A' then (Capacity - 24)
	when EquipmentType = 333 and EquipmentTypeSuffix = 'A' then (Capacity - 12)
	Else '0' End
	from ods.InventoryLeg A
	LEFT JOIN 
	AAII_CARRIER_MAPPING carr_map
	on carr_map.carriercode = A.carriercode
	and ltrim(RTRIM(carr_map.flightnumber)) = ltrim(RTRIM(A.flightnumber))
	
	left join dw.CityPair B on A.DepartureStation = B.DEpartureStation and A.ArrivalStation = B.ArrivalStation
	--where DepartureDate between '2013-12-01' and @DepartureEnd
	where DepartureDate between @departureStart and @departureEnd
	and (isnull(carr_map.mappedcarrier ,A.CARRIERCODE) = 'XJ' OR
	ltrim(rtrim(isnull(carr_map.mappedcarrier ,A.CARRIERCODE)))+ltrim(rtrim(A.FlightNumber)) = 'D7620' OR 
		ltrim(rtrim(isnull(carr_map.mappedcarrier ,A.CARRIERCODE)))+ltrim(rtrim(A.FlightNumber)) = 'D7621')
	--and FlightNumber not in ('2994','2995','2996','2997','2998','2999')
	and Lid >0
	and status <>2


	--select sum(Capacity) as Lid, CarrierCode, FlightNumber, DepartureStation+ArrivalStation as Route,
	--Cabin, DepartureDate, Year(DepartureDate) as Year, DATENAME(WW,DepartureDate) as WeekNum
	--from #temp_Inventory
	--where DepartureStation+ArrivalStation in ('AORKUL','KULAOR')
	--and DepartureDate between '2012-01-01' and '2012-01-31'
	--group by  CarrierCode, FlightNumber, DepartureStation+ArrivalStation,Cabin, DepartureDate

		
	
	BEGIN TRY TRUNCATE TABLE #FlightInfo_AAX DROP TABLE #FlightInfo_AAX END TRY BEGIN CATCH END CATCH 
	Select Distinct InventoryLegKey,DepartureDate,CarrierCode,FlightNumber,DepartureStation,ArrivalStation
	Into #FlightInfo_AAX
	From #Inventory_AAX 
	

	
	
	
	
	BEGIN TRY TRUNCATE TABLE #SeatSoldRevenue_AAX DROP TABLE #SeatSoldRevenue_AAX END TRY BEGIN CATCH END CATCH 
	select substring(J.citypairgroup,1,3) + SUBSTRING(J.CityPairGroup,5,3) as ODPAIR, I.InventoryLegKey, f.DepartureDate, DATENAME(MM,f.DepartureDate) as DepartureMonth, 
	YEAR(f.DepartureDate) as DepartureYear, f.CarrierCode, f.FlightNumber, Route, f.FareClassOfService,
	f.FareClass, f.Cabin, f.CurrencyCode,
	SUM(SeatsSold) as SeatSold ,sum(BaseFare_THB) as BaseFare_THB, SUM(FuelSurcharge_THB) as FuelSurcharge_THB,
	sum(BaseFare_MYR) as BaseFare_MYR, SUM(FuelSurcharge_MYR) as FuelSurcharge_MYR,
	SUM(AncillaryAmount_THB) as AncillaryAmount_THB, SUM(AncillaryAmount_MYR) as AncillaryAmount_MYR
	into #SeatSoldRevenue_AAX
	from #SeatsSold_AAX_ALLRM f
	inner join #FlightInfo_AAX I ON I.departureDate=f.DepartureDate and I.CarrierCode = f.CarrierCode
	and I.Flightnumber = f.FlightNumber
	inner join dw.CityPair J ON I.DepartureStation = J.DepartureStation And I.ArrivalStation = J.ArrivalStation
	group by substring(J.citypairgroup,1,3) + SUBSTRING(J.CityPairGroup,5,3), I.InventoryLegKey,DATENAME(MM,f.DepartureDate), YEAR(f.DepartureDate), 
	f.CarrierCode,f.flightNumber, route, f.DepartureDate, f.FareClassOfService,
	f.FareClass, f.Cabin, f.CurrencyCode
	
	--select top 100*
	--from #SeatSoldRevenue_AAX
	--where ODPair = 'JEDKUL'
	--and FlightNumber = 172
	--and DepartureMonth = 'October'
	--and DepartureYEar = 2013
	
		
					
	BEGIN TRY TRUNCATE TABLE #AAX_TaxRM DROP TABLE #AAX_TaxRM END TRY BEGIN CATCH END CATCH 
	select BB.Route, BB.odpair,BB.inventorylegkey,BB.carrierCode,BB.DepartureDate,BB.flightNumber,
	BB.Cabin, SUM(SeatSold * FeeMYR) as AptchargeRM 
	into #AAX_TaxRM
	from #SeatSoldRevenue_AAX BB
	--inner join #FlightInfo_AAX I ON I.InventoryLegKey=BB.InventoryLegKey
	LEFT JOIN SAT_L_RR_AIRPORT_FEE FEE ON BB.CARRIERCODE=FEE.CARRIERCODE AND FEE.SECTOR=BB.Route
		AND  CONVERT(VARCHAR, @MYDateUTC-1, 101) BETWEEN  VERSIONSTARTDATE AND VERSIONENDDATE
	WHERE (BB.CarrierCode = 'XJ') 
	--OR
	--ltrim(rtrim(BB.CarrierCode))+ltrim(rtrim(BB.FlightNumber)) = 'D7620' OR 
	--	ltrim(rtrim(BB.CarrierCode))+ltrim(rtrim(BB.FlightNumber)) = 'D7621')
	 group by  BB.Route, BB.odpair,BB.inventorylegkey,BB.carrierCode,BB.DepartureDate,BB.flightNumber, BB.Cabin



	--select top 100* from #AAX_TaxRM


	
	BEGIN TRY TRUNCATE TABLE Temp_RR_Daily_Revenue_FareClass_v3_TAAX DROP TABLE Temp_RR_Daily_Revenue_FareClass_v3_TAAX END TRY BEGIN CATCH END CATCH 
	select 'hub' AS hub, substring(J.citypairgroup,1,3) + SUBSTRING(J.CityPairGroup,5,3) as ODPAIR, CapturedDate, DATENAME(MM,f.DepartureDate) as DepartureMonth, 
	YEAR(f.DepartureDate) as DepartureYear, f.CarrierCode, f.FlightNumber, f.Route, f.FareClassOfService,
	f.FareClass, f.Cabin, f.CurrencyCode,
	SUM(SeatsSold) as SeatSold ,
	sum(BaseFare_THB) as BaseFare_THB, SUM(FuelSurcharge_THB) as FuelSurcharge_THB,
	sum(BaseFare_MYR) as BaseFare_MYR, SUM(FuelSurcharge_MYR) as FuelSurcharge_MYR,
	SUM(AncillaryAmount_THB) as AncillaryAmount_THB,
	SUM(AncillaryAmount_MYR) as AncillaryAmount_MYR
	into Temp_RR_Daily_Revenue_FareClass_v3_TAAX
	from #SeatsSold_AAX_ALLRM  f
	inner join #FlightInfo_AAX I ON I.departureDate=f.DepartureDate and I.CarrierCode = f.CarrierCode
	and I.Flightnumber = f.FlightNumber
	inner join dw.CityPair J ON I.DepartureStation = J.DepartureStation And I.ArrivalStation = J.ArrivalStation
	group by substring(J.citypairgroup,1,3) + SUBSTRING(J.CityPairGroup,5,3), DATENAME(MM,f.DepartureDate), YEAR(f.DepartureDate), 
	f.CarrierCode,f.flightNumber, f.Route, f.FareClassOfService,
	f.FareClass, f.Cabin, f.CurrencyCode, CapturedDate
		
		
								
				
	 BEGIN TRY TRUNCATE TABLE Temp_RR_Daily_InventoryRevenue_v3_TAAX DROP TABLE Temp_RR_Daily_InventoryRevenue_v3_TAAX END TRY BEGIN CATCH END CATCH 
	 SELECT  distinct Z.hub,Z.ODPAIR, INVENTORY.CapturedDate, DayOfYear, DayOfWeek,
	 INVENTORY.DepartureMonth,INVENTORY.DepartureYear,INVENTORY.Flightnumber,
	 INVENTORY.CarrierCode, INVENTORY.Route, INVENTORY.Cabin,
	 ISNULL(S.seatSold,0) as SeatsSold,ISNULL(S.FuelSurcharge_THB,0) as FuelSurcharge_THB, ISNULL(S.FuelSurcharge_MYR,0) as FuelSurcharge_MYR,
	 ISNULL(S.BaseFare_THB,0) as BaseFare_THB, ISNULL(S.BaseFare_MYR,0) as BaseFare_MYR,ISNULL(S.AncillaryAmount_THB,0) as AncillaryAmount_THB, ISNULL(S.AncillaryAmount_MYR,0) as AncillaryAmount_MYR,capacity,
	 0 as AptchargeTHB, 0 as AptEnabled--,
	 into  Temp_RR_Daily_InventoryRevenue_v3_TAAX
	 FROM
	 ( select  Cabin, CAPTUREDDATE,DayOfYear,DayOfWeek,DepartureMonth, DepartureYear, Flightnumber, CarrierCode,
	 DepartureStation+ArrivalStation as Route, ODPAir,
	--SUM(SeatSold) AS SeatSold,
	sum(capacity) as capacity 
	  from #Inventory_AAX I --where odpair='AORKUL'
	  --where CarrierCode = 'XJ'
	 group by Cabin, CAPTUREDDATE, DayOfYear,DayOfWeek,DepartureMonth,DepartureYear, Flightnumber, CarrierCode,
	 DepartureStation+ArrivalStation, ODPAir
	 )INVENTORY 
 LEFT JOIN
	(select distinct 'hub' AS hub, DepartureStation, ArrivalStation, substring(citypairgroup,1,3) + SUBSTRING(CityPairGroup,5,3) as ODPAIR
	from dw.CityPair) Z
	on INVENTORY.Route = Z.DepartureStation+ArrivalStation	 
 LEFT JOIN 
	 (
	 select ODPAir, CapturedDate, DepartureMonth, DepartureYear, Carriercode, FlightNumber, Route, Cabin,
	 sum(SeatSold) as SeatSold, 
	 Sum(BaseFare_THB) as BaseFare_THB, sum(FuelSurcharge_THB) as FuelSurcharge_THB, 
	 Sum(BaseFare_MYR) as BaseFare_MYR, sum(FuelSurcharge_MYR) as FuelSurcharge_MYR, 
	 sum(AncillaryAmount_THB) as AncillaryAmount_THB,
	  sum(AncillaryAmount_MYR) as AncillaryAmount_MYR
	 from Temp_RR_Daily_Revenue_FareClass_v3_TAAX
	 --where CarrierCode = 'XJ'
	 group by cabin, odpair, CapturedDate, DepartureMonth, DepartureYear, Carriercode, FlightNumber, Route) S
	 ON INVENTORY.DEPARTUREMONTH=S.DEPARTUREMONTH 
	 AND INVENTORY.DEPARTUREYEAR=S.DEPARTUREYEAR AND INVENTORY.FLIGHTNUMBER=S.FLIGHTNUMBER
	 AND S.CABIN = INVENTORY.CABIN AND S.ROUTE = INVENTORY.ROUTE and S.ODPAIR = INVENTORY.ODPAIR
  LEFT JOIN 
	 (
	 select Route, odpair,DATENAME(m,f.DepartureDate) as DepartureMonth, 
	convert(varchar(4),datepart(YYYY,f.DepartureDate)) as DepartureYear,f.carrierCode,f.flightNumber,
	 f.Cabin, sum(AptchargeRM) as AptchargeRM
	 from #AAX_TaxRM f
	 --inner join #FlightInfo I ON I.InventoryLegKey=f.InventoryLegKey
	 group by Route, odpair,DATENAME(m,f.DepartureDate),convert(varchar(4),datepart(YYYY,f.DepartureDate)),
	 f.carrierCode,f.flightNumber, f.cabin
	  ) FARE ON FARE.DEPARTUREMONTH=INVENTORY.DEPARTUREMONTH 
			AND FARE.DEPARTUREYEAR=INVENTORY.DEPARTUREYEAR AND FARE.FLIGHTNUMBER=INVENTORY.FLIGHTNUMBER 
			AND FARE.CABIN = INVENTORY.CABIN AND FARE.ROUTE = INVENTORY.Route and FARE.ODPAir = INVENTORY.ODPAIR
		
				
	BEGIN TRY TRUNCATE TABLE Temp_RR_Daily_InventoryRevenue_FareClass_v3_TAAX DROP TABLE Temp_RR_Daily_InventoryRevenue_FareClass_v3_TAAX END TRY BEGIN CATCH END CATCH 
	 --insert into Temp_RR_Daily_InventoryRevenue
	 SELECT  distinct hub,S.ODPAIR, S.CAPTUREDDATE,DayOfYear,DayOfWeek,INVENTORY.DepartureMonth,INVENTORY.DepartureYear,INVENTORY.Flightnumber,
	 INVENTORY.CarrierCode, S.Route, S.FareClass, S.FareClassOfService,
	 S.seatSold, S.FuelSurcharge_THB, S.BaseFare_THB, S.AncillaryAmount_THB,S.FuelSurcharge_MYR, S.BaseFare_MYR, S.AncillaryAmount_MYR,
	 0 as AptchargeTHB, 0 as AptEnabled--,
	 into  Temp_RR_Daily_InventoryRevenue_FareClass_v3_TAAX
	 FROM
	 ( select  DepartureStation+ArrivalStation as Route,DayOfYear,DayOfWeek,DepartureMonth,DepartureYear, Flightnumber, CarrierCode
	  from #Inventory_AAX I --where odpair='AORKUL'
	 group by  DepartureStation+ArrivalStation, CAPTUREDDATE,DayOfYear,DayOfWeek,DepartureMonth,DepartureYear, Flightnumber,CarrierCode
	 )INVENTORY 
	 /*
	 INNER JOIN 
	 (
	 select DATENAME(m,f.DepartureDate) as DepartureMonth,
	convert(varchar(4),datepart(YYYY,f.DepartureDate)) as DepartureYear,f.carrierCode,f.flightNumber,
	sum(AptchargeRM) as AptchargeRM
	 from #AAX_TaxRM f
	 --inner join #FlightInfo I ON I.InventoryLegKey=f.InventoryLegKey
	 group by DATENAME(m,f.DepartureDate), convert(varchar(4),datepart(YYYY,f.DepartureDate)),
	 f.carrierCode,f.flightNumber
	  ) FARE ON FARE.DEPARTUREMONTH=INVENTORY.DEPARTUREMONTH 
			AND FARE.DEPARTUREYEAR=INVENTORY.DEPARTUREYEAR AND FARE.FLIGHTNUMBER=INVENTORY.FLIGHTNUMBER 
	 */
	 LEFT JOIN 
	 Temp_RR_Daily_Revenue_FareClass_v3_TAAX S ON INVENTORY.ROUTE=S.ROUTE AND INVENTORY.DEPARTUREMONTH=S.DEPARTUREMONTH 
			AND INVENTORY.DEPARTUREYEAR=S.DEPARTUREYEAR AND INVENTORY.FLIGHTNUMBER=S.FLIGHTNUMBER
	

	--select top 100*
	--from Temp_RR_Daily_InventoryRevenue_v2_AAX
	--where ODPair = 'JEDKUL'
	--and FlightNumber = 172
	--and DepartureMonth = 'October'
	--and DepartureYEar = 2013

alter table Temp_RR_Daily_InventoryRevenue_v3_TAAX alter column Hub varchar(5)
alter table Temp_RR_Daily_InventoryRevenue_FareClass_v3_TAAX alter column Hub varchar(5)

		 
	 UPDATE A
		SET  A.Hub=B.Hub
		  FROM Temp_RR_Daily_InventoryRevenue_v3_TAAX A
		INNER JOIN SAT_Hub_info_version_v3 B ON  A.CARRIERCODE=B.CARRIERCODE AND ltrim(rtrim(A.FLIGHTNUMBER))=ltrim(rtrim(B.FLIGHTNUMBER))
	 AND (odpair=MarketGroup or (LEFT(odpair,3)=right(marketgroup,3) and RIGHT(odpair,3)=LEFT(marketgroup,3)))
	 
	 UPDATE A
		SET  A.Hub=B.Hub
	FROM Temp_RR_Daily_InventoryRevenue_v3_TAAX A
		inner JOIN SAT_Hub_info_version_v3 B ON  A.CARRIERCODE=B.CARRIERCODE --AND ltrim(rtrim(A.FLIGHTNUMBER))=ltrim(rtrim(B.FLIGHTNUMBER))
	 AND (odpair=MarketGroup or (LEFT(odpair,3)=right(marketgroup,3) and RIGHT(odpair,3)=LEFT(marketgroup,3)))
	  where A.hub='HUB'
	  
	  
	 UPDATE A
		SET  A.Hub=B.Hub
		  FROM Temp_RR_Daily_InventoryRevenue_FareClass_v3_TAAX A
		INNER JOIN SAT_Hub_info_version_v3 B ON  A.CARRIERCODE=B.CARRIERCODE AND ltrim(rtrim(A.FLIGHTNUMBER))=ltrim(rtrim(B.FLIGHTNUMBER))
	 AND (odpair=MarketGroup or (LEFT(odpair,3)=right(marketgroup,3) and RIGHT(odpair,3)=LEFT(marketgroup,3)))
	 
	 UPDATE A
		SET  A.Hub=B.Hub
	FROM Temp_RR_Daily_InventoryRevenue_FareClass_v3_TAAX A
		inner JOIN SAT_Hub_info_version_v3 B ON  A.CARRIERCODE=B.CARRIERCODE --AND ltrim(rtrim(A.FLIGHTNUMBER))=ltrim(rtrim(B.FLIGHTNUMBER))
	 AND (odpair=MarketGroup or (LEFT(odpair,3)=right(marketgroup,3) and RIGHT(odpair,3)=LEFT(marketgroup,3)))
	  where A.hub='HUB'
	    
	 --select top 100* from Temp_RR_Daily_InventoryRevenue_FareClass_v3_AAX where FareClass is null
	 

	    
END



--SELECT TOP 100 * FROM Temp_RR_Daily_InventoryRevenue_v3_TAAX
--WHERE LTRIM(RTRIM(FLIGHTNUMBER)) = '621'









GO


