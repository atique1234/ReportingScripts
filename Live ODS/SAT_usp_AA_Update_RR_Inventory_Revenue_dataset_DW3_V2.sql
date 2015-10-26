USE [REZAKWB01]
GO

/****** Object:  StoredProcedure [wb].[SAT_usp_AA_Update_RR_Inventory_Revenue_dataset_DW3_V2]    Script Date: 10/26/2015 10:40:45 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO














-- =============================================
-- Author:		<ABDULLAH AL MAHBUB>
-- Create date: <2015-06-29>
-- Description:	<ROUTE REVENUE - 12 MONTHS INVENTORY + REVENUE, INCLUDING AAX>
-- =============================================


--ALTER PROCEDURE [wb].[SAT_usp_AA_Update_RR_Inventory_Revenue_dataset_DW3_V2]

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
	
	--SET @MYDateUTC ='2015-07-14'
	--SET @startDateUTC = @MYDateUTC-1
	--SET @endDateUTC = @MYDateUTC

	select @MYDateUTC  = ods.ConvertDate( 'MY', GETDATE(),0,0)
	SET @startDateUTC = ods.ConvertDate( @timeZone, CAST(CONVERT(VARCHAR,@MYDateUTC-1, 101) AS DateTime) , 1, 0 )
	SET @endDateUTC   = ods.ConvertDate( @timeZone,CAST(CONVERT(VARCHAR, DATEADD(day, 1, @MYDateUTC-1), 101) AS DateTime) , 1, 0 )
	  
	 --SET @departureStart =CAST(CONVERT(VARCHAR, DATEADD(s, 1,DATEADD(mm, DATEDIFF(m,0,DateAdd(month,0,@MYDateUTC)),0)), 101) AS DateTime) 
	SET @departureStart =CAST(CONVERT(VARCHAR, DATEADD(YEAR, DATEDIFF(YEAR, 0, @MYDateUTC-3), 0), 101) AS DateTime) 
	SET @departureEnd   =CAST(CONVERT(VARCHAR,DATEADD(s, -1,DATEADD(mm, DATEDIFF(m,12,DateAdd(month,12,@MYDateUTC)),0))) AS DateTime) 
	print @MYDateUTC 
	print @startDateUTC
	print @endDateUTC
	print @departureStart
	print @departureEnd
	print @MYDateUTC-1
	
	
--SeatsSold, BaseRevenue_RM --	

	BEGIN TRY TRUNCATE TABLE #SeatsSold_BaseRevRM DROP TABLE #SeatsSold_BaseRevRM END TRY BEGIN CATCH END CATCH 
	select distinct CAST(Convert(VARCHAR,@MYDateUTC-1, 112) as datetime) as CapturedDate,
	DATEPART(DAYOFYEAR,@MYDateUTC-1) as dayOfYear,
	DATEPART(DW,@MYDateUTC-1) as dayOfWeek,
	count(A.PassengerID) as SeatsSold, DepartureDate, CarrierCode, FlightNumber, DepartureStation, ArrivalStation,
	sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))/L.ConversionRate) as BaseFare_RM,
	sum((ISNULL(Fuel_Amt,0))/L.ConversionRate) as FuelSurcharge_RM,
	sum((ISNULL(Connecting_Amt,0))/L.ConversionRate) as Connecting_RM,
	sum((ISNULL(AptCharges_Amt,0))/L.ConversionRate) as AptCharges_RM,
	-- NEWLY ADDED
	sum((ISNULL(ThruFare_Amt,0))/L.ConversionRate) as ThruFare_RM,
	sum((ISNULL(XHISEA_Amt,0))/L.ConversionRate) as XHISEA_RM,
	sum((ISNULL(ADM_Amt,0))/L.ConversionRate) as ADM_RM,

	BaseFare_AirlineCurrency = 
	case when CarrierCode = 'QZ' then sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))/ISNULL(M.ConversionRate,1))
	when CarrierCode = 'FD' then sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))/ISNULL(N.ConversionRate,1))
	when CarrierCode = 'PQ' then sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))/ISNULL(OO.ConversionRate,1))
	when CarrierCode = 'Z2' then sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))/ISNULL(OO.ConversionRate,1))
	when CarrierCode = 'JW' then sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))/ISNULL(PP.ConversionRate,1))
	when CarrierCode = 'AK' then sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))/ISNULL(L.ConversionRate,1)) 
	when CarrierCode = 'D7' then sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))/ISNULL(L.ConversionRate,1)) 
	when CarrierCode = 'XJ' then sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))/ISNULL(XJ.ConversionRate,1)) 
	when CarrierCode = 'I5' then sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))/ISNULL(I5.ConversionRate,1)) 
	when CarrierCode = 'XT' then sum((ISNULL(Fare_Amt,0) + ISNULL(Disc_Amt,0) + ISNULL(Promo_Amt,0))/ISNULL(XT.ConversionRate,1)) 
	End,
	FuelSurcharge_AirlineCurrency = 
	case when CarrierCode = 'QZ' then sum(ISNULL(Fuel_Amt,0)/ISNULL(M.ConversionRate,1))
	when CarrierCode = 'FD' then sum(ISNULL(Fuel_Amt,0)/ISNULL(N.ConversionRate,1))
	when CarrierCode = 'PQ' then sum(ISNULL(Fuel_Amt,0)/ISNULL(OO.ConversionRate,1))
	when CarrierCode = 'Z2' then sum(ISNULL(Fuel_Amt,0)/ISNULL(OO.ConversionRate,1))
	when CarrierCode = 'JW' then sum(ISNULL(Fuel_Amt,0)/ISNULL(PP.ConversionRate,1))
	when CarrierCode = 'AK' then sum(ISNULL(Fuel_Amt,0)/ISNULL(L.ConversionRate,1)) 
	when CarrierCode = 'D7' then sum(ISNULL(Fuel_Amt,0)/ISNULL(L.ConversionRate,1)) 
	when CarrierCode = 'XJ' then sum(ISNULL(Fuel_Amt,0)/ISNULL(XJ.ConversionRate,1))
	when CarrierCode = 'I5' then sum(ISNULL(Fuel_Amt,0)/ISNULL(I5.ConversionRate,1))  
	when CarrierCode = 'XT' then sum(ISNULL(Fuel_Amt,0)/ISNULL(XT.ConversionRate,1))
	End,
	Connecting_AirlineCurrency =
	case when CarrierCode = 'QZ' then sum(ISNULL(Connecting_Amt,0)/ISNULL(M.ConversionRate,1))
	when CarrierCode = 'FD' then sum(ISNULL(Connecting_Amt,0)/ISNULL(N.ConversionRate,1))
	when CarrierCode = 'PQ' then sum(ISNULL(Connecting_Amt,0)/ISNULL(OO.ConversionRate,1))
	when CarrierCode = 'Z2' then sum(ISNULL(Connecting_Amt,0)/ISNULL(OO.ConversionRate,1))
	when CarrierCode = 'JW' then sum(ISNULL(Connecting_Amt,0)/ISNULL(PP.ConversionRate,1))
	when CarrierCode = 'AK' then sum(ISNULL(Connecting_Amt,0)/ISNULL(L.ConversionRate,1)) 
	when CarrierCode = 'D7' then sum(ISNULL(Connecting_Amt,0)/ISNULL(L.ConversionRate,1))
	when CarrierCode = 'XJ' then sum(ISNULL(Connecting_Amt,0)/ISNULL(XJ.ConversionRate,1))
	when CarrierCode = 'I5' then sum(ISNULL(Connecting_Amt,0)/ISNULL(I5.ConversionRate,1))
	when CarrierCode = 'XT' then sum(ISNULL(Connecting_Amt,0)/ISNULL(XT.ConversionRate,1))
	End,
	AptCharges_AirlineCurrency =
	case when CarrierCode = 'QZ' then sum(ISNULL(AptCharges_Amt,0)/ISNULL(M.ConversionRate,1))
	when CarrierCode = 'FD' then sum(ISNULL(AptCharges_Amt,0)/ISNULL(N.ConversionRate,1))
	when CarrierCode = 'PQ' then sum(ISNULL(AptCharges_Amt,0)/ISNULL(OO.ConversionRate,1))
	when CarrierCode = 'Z2' then sum(ISNULL(AptCharges_Amt,0)/ISNULL(OO.ConversionRate,1))
	when CarrierCode = 'JW' then sum(ISNULL(AptCharges_Amt,0)/ISNULL(PP.ConversionRate,1))
	when CarrierCode = 'AK' then sum(ISNULL(AptCharges_Amt,0)/ISNULL(L.ConversionRate,1)) 
	when CarrierCode = 'D7' then sum(ISNULL(AptCharges_Amt,0)/ISNULL(L.ConversionRate,1))
	when CarrierCode = 'XJ' then sum(ISNULL(AptCharges_Amt,0)/ISNULL(XJ.ConversionRate,1))  
	when CarrierCode = 'I5' then sum(ISNULL(AptCharges_Amt,0)/ISNULL(I5.ConversionRate,1))  
	when CarrierCode = 'XT' then sum(ISNULL(AptCharges_Amt,0)/ISNULL(XT.ConversionRate,1))
	End,
	ThruFare_AirlineCurrency =
	case when CarrierCode = 'QZ' then sum(ISNULL(ThruFare_Amt,0)/ISNULL(M.ConversionRate,1))
	when CarrierCode = 'FD' then sum(ISNULL(ThruFare_Amt,0)/ISNULL(N.ConversionRate,1))
	when CarrierCode = 'PQ' then sum(ISNULL(ThruFare_Amt,0)/ISNULL(OO.ConversionRate,1))
	when CarrierCode = 'Z2' then sum(ISNULL(ThruFare_Amt,0)/ISNULL(OO.ConversionRate,1))
	when CarrierCode = 'JW' then sum(ISNULL(ThruFare_Amt,0)/ISNULL(PP.ConversionRate,1))
	when CarrierCode = 'AK' then sum(ISNULL(ThruFare_Amt,0)/ISNULL(L.ConversionRate,1)) 
	when CarrierCode = 'D7' then sum(ISNULL(ThruFare_Amt,0)/ISNULL(L.ConversionRate,1))
	when CarrierCode = 'XJ' then sum(ISNULL(ThruFare_Amt,0)/ISNULL(XJ.ConversionRate,1))  
	when CarrierCode = 'I5' then sum(ISNULL(ThruFare_Amt,0)/ISNULL(I5.ConversionRate,1))  
	when CarrierCode = 'XT' then sum(ISNULL(ThruFare_Amt,0)/ISNULL(XT.ConversionRate,1))
	End,
	XHISEA_AirlineCurrency =
	case when CarrierCode = 'QZ' then sum(ISNULL(XHISEA_Amt,0)/ISNULL(M.ConversionRate,1))
	when CarrierCode = 'FD' then sum(ISNULL(XHISEA_Amt,0)/ISNULL(N.ConversionRate,1))
	when CarrierCode = 'PQ' then sum(ISNULL(XHISEA_Amt,0)/ISNULL(OO.ConversionRate,1))
	when CarrierCode = 'Z2' then sum(ISNULL(XHISEA_Amt,0)/ISNULL(OO.ConversionRate,1))
	when CarrierCode = 'JW' then sum(ISNULL(XHISEA_Amt,0)/ISNULL(PP.ConversionRate,1))
	when CarrierCode = 'AK' then sum(ISNULL(XHISEA_Amt,0)/ISNULL(L.ConversionRate,1)) 
	when CarrierCode = 'D7' then sum(ISNULL(XHISEA_Amt,0)/ISNULL(L.ConversionRate,1))
	when CarrierCode = 'XJ' then sum(ISNULL(XHISEA_Amt,0)/ISNULL(XJ.ConversionRate,1))  
	when CarrierCode = 'I5' then sum(ISNULL(XHISEA_Amt,0)/ISNULL(I5.ConversionRate,1))  
	when CarrierCode = 'XT' then sum(ISNULL(XHISEA_Amt,0)/ISNULL(XT.ConversionRate,1))
	End,
	ADM_AirlineCurrency =
	case when CarrierCode = 'QZ' then sum(ISNULL(ADM_Amt,0)/ISNULL(M.ConversionRate,1))
	when CarrierCode = 'FD' then sum(ISNULL(ADM_Amt,0)/ISNULL(N.ConversionRate,1))
	when CarrierCode = 'PQ' then sum(ISNULL(ADM_Amt,0)/ISNULL(OO.ConversionRate,1))
	when CarrierCode = 'Z2' then sum(ISNULL(ADM_Amt,0)/ISNULL(OO.ConversionRate,1))
	when CarrierCode = 'JW' then sum(ISNULL(ADM_Amt,0)/ISNULL(PP.ConversionRate,1))
	when CarrierCode = 'AK' then sum(ISNULL(ADM_Amt,0)/ISNULL(L.ConversionRate,1)) 
	when CarrierCode = 'D7' then sum(ISNULL(ADM_Amt,0)/ISNULL(L.ConversionRate,1))
	when CarrierCode = 'XJ' then sum(ISNULL(ADM_Amt,0)/ISNULL(XJ.ConversionRate,1))  
	when CarrierCode = 'I5' then sum(ISNULL(ADM_Amt,0)/ISNULL(I5.ConversionRate,1))  
	when CarrierCode = 'XT' then sum(ISNULL(ADM_Amt,0)/ISNULL(XT.ConversionRate,1))
	End
	into #SeatsSold_BaseRevRM
	from
		(select 
		PassengerID, SegmentID, DepartureDate, DATENAME(YY,DepartureDate) as DepartureYear, DATENAME(MM,DepartureDate) as DepartureMonth,
		DepartureStation, ArrivalStation, 
		CASE WHEN LTRIM(RTRIM(CARRIERCODE))+LTRIM(RTRIM(FLIGHTNUMBER)) IN ('XT7531','XT7532','XT7533','XT7534','XT7681','XT7680','XT7693','XT7692','XT7683','XT7682','XT7620','XT7621','XT7526','XT7527','XT208','XT209','XT7518','XT7519','XT7681','XT7680','XT7693','XT7692','XT7683','XT7682','XT7620','XT7621','XT392','XT393',
		'XT322','XT323','XT326','XT327','XT7628','XT7629','XT324','XT325','XT8297','XT8298') THEN 'QZ' ELSE CarrierCode END as CarrierCode, 
		FlightNumber, CreatedDate, Currencycode
		from vw_PassengerJourneySegment with (nolock)
		where BookingStatus = 'HK' 
		and DATEADD(HH,8,CreatedDate) < @endDateUTC
		and DepartureDate between @departureStart and @departureEnd
		and CarrierCode in ('AK','FD','QZ','JW','PQ','D7','Z2','XJ','I5','XT')
		and CarrierCode+' '+FlightNumber not in ('D7 2994','D7 2995','D7 2998','D7 2999','I5 9001')) A
	left join
		(select PassengerID, SegmentID, --sum(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as Fare_Amt
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as Fare_Amt
		from
			(select PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge with (nolock)
			where ChargeType = '0') C
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix with (nolock)) D
			on C.ChargeType = D.ChargeTypeID
		group by PassengerID, SegmentID	) E
		on A.SegmentID = E.SegmentID and A.PassengerID = E.PassengerID
	left join 
		(select PassengerID, SegmentID, --sum(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as Disc_Amt
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
		group by PassengerID, SegmentID	) H
		on A.SegmentID = H.SegmentID and A.PassengerID = H.PassengerID
	left join 
		(select PassengerID, SegmentID, --sum(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as Promo_Amt
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
		group by PassengerID, SegmentID	) K		
		on A.SegmentID = K.SegmentID and A.PassengerID = K.PassengerID 	
	left join 
		(select PassengerID, SegmentID, --sum(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as Fuel_Amt
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
		group by PassengerID, SegmentID	) Q		
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
		(select PassengerID, SegmentID, --sum(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as Connecting_Amt
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as Connecting_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge with (nolock)
			where ChargeType = '8') R	
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix with (nolock)) S
			on R.ChargeType = S.ChargeTypeID
		group by PassengerID, SegmentID	) T		
		on A.SegmentID = T.SegmentID and A.PassengerID = T.PassengerID 	
	left join 
		(select PassengerID, SegmentID, --sum(ISNULL(ChargeAmount,0)*PositiveNegativeFlag) as AptCharges_Amt
		sum(case when Chargetype in ('1','2','3','7','16') then -1*ISNULL(ChargeAmount,0.00) else ISNULL(ChargeAmount,0.00) end) as AptCharges_Amt
		from
			(select 
			PassengerID, SegmentID, ChargeType, ChargeAmount
			from ods.PassengerJourneyCharge with (nolock)
			where ChargeCode in ('APF')) U	
		left join
			(select ChargeTypeID, PositiveNegativeFlag
			from dw.chargeTypeMatrix with (nolock)) V
			on U.ChargeType = V.ChargeTypeID
		group by PassengerID, SegmentID	) W		
		on A.SegmentID = W.SegmentID and A.PassengerID = W.PassengerID 			
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from dw.CurrencyconversionHistoryDecompressed with (nolock)
		where FromCurrencyCode = 'MYR') L
		on L.ToCurrencyCode = A.CurrencyCode 
		and CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = L.ConversionDate
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from dw.CurrencyconversionHistoryDecompressed with (nolock)
		where FromCurrencyCode = 'IDR') M
		on M.ToCurrencyCode = A.CurrencyCode 
		and CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = M.ConversionDate	
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from dw.CurrencyconversionHistoryDecompressed with (nolock)
		where FromCurrencyCode = 'THB') N 
		on N.ToCurrencyCode = A.CurrencyCode 
		and CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = N.ConversionDate		
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from dw.CurrencyconversionHistoryDecompressed with (nolock)
		where FromCurrencyCode = 'PHP') OO
		on OO.ToCurrencyCode = A.CurrencyCode 
		and CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = OO.ConversionDate		
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from dw.CurrencyconversionHistoryDecompressed with (nolock)
		where FromCurrencyCode = 'JPY') PP
		on PP.ToCurrencyCode = A.CurrencyCode 
		and CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = PP.ConversionDate	
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from dw.CurrencyconversionHistoryDecompressed with (nolock)
		where FromCurrencyCode = 'THB') XJ
		on XJ.ToCurrencyCode = A.CurrencyCode 
		and CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = XJ.ConversionDate	
	--20140530 - Harpreet requested to add in AAI India "I5"
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from dw.CurrencyconversionHistoryDecompressed with (nolock)
		where FromCurrencyCode = 'INR') I5
		on I5.ToCurrencyCode = A.CurrencyCode 
		and CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = I5.ConversionDate
	left join
		(select FromCurrencyCode, ToCurrencyCode, ConversionRate, ConversionDate
		from dw.CurrencyconversionHistoryDecompressed with (nolock)
		where FromCurrencyCode = 'USD') XT
		on XT.ToCurrencyCode = A.CurrencyCode 
		and CAST(CONVERT(VARCHAR,A.CreatedDate,110) as datetime) = XT.ConversionDate	
	--20140530 - Harpreet requested to add in IAAX "XT"		
	group by DepartureDate, CarrierCode, FlightNumber, DepartureStation, ArrivalStation
	
	Update #SeatsSold_BaseRevRM
	set DepartureStation = 'KNO' where DepartureStation = 'MES'
	
	Update #SeatsSold_BaseRevRM
	set ArrivalStation = 'KNO' where ArrivalStation = 'MES'
	
	delete from #SeatsSold_BaseRevRM where CarrierCode = 'FD' and FlightNumber in ('2496','2497') and DepartureDate < '2014-02-21'

	

	--select top 10000* from #SeatsSold_BaseRevRM where DepartureStation = 'KNO'
			
			
	BEGIN TRY TRUNCATE TABLE #Inventorytemp DROP TABLE #Inventorytemp END TRY BEGIN CATCH END CATCH 
	Select  IL.InventoryLegKey,
	Convert(datetime,Convert(varchar(12),DateAdd(day,0,@MYDateUTC-1),113)) AS CapturedDate ,
	DATEPART(DAYOFYEAR,@MYDateUTC-1) as dayOfYear,
	DATEPART(DW,@MYDateUTC-1) as dayOfWeek, 
	DATENAME(m,IL.DepartureDate) as DepartureMonth,
	convert(varchar(4),datepart(YYYY,IL.DepartureDate)) as DepartureYear,
	IL.DepartureDate,
	CASE WHEN LTRIM(RTRIM(IL.CARRIERCODE))+LTRIM(RTRIM(IL.FLIGHTNUMBER)) IN ('XT7531','XT7532','XT7533','XT7534','XT7681','XT7680','XT7693','XT7692','XT7683','XT7682','XT7620','XT7621','XT7526','XT7527','XT208','XT209','XT7518','XT7519','XT7681','XT7680','XT7693','XT7692','XT7683','XT7682','XT7620','XT7621','XT392','XT393',
	'XT322','XT323','XT326','XT327','XT7628','XT7629','XT324','XT325','XT8297','XT8298') THEN 'QZ' ELSE IL.CarrierCode END AS CarrierCode,
	IL.FlightNumber,
	IL.OpSuffix, substring(citypairgroup,1,3) + SUBSTRING(CityPairGroup,5,3) as ODPAIR,
	IL.DepartureStation,
	IL.ArrivalStation,
	IL.lid, 
	IL.Capacity
	Into #Inventorytemp
	From ods.InventoryLeg  IL  with (nolock) 
	left join dw.CityPair CP 
		On IL.DepartureStation = CP.DepartureStation And IL.ArrivalStation = CP.ArrivalStation
	Where IL.Status <> 2 and Lid > 0
	AND IL.DepartureDate >=CONVERT(VARCHAR, @departureStart, 101)   
	AND IL.DepartureDate<= CONVERT(VARCHAR, @departureEnd, 101)  
	AND (IL.createdDate <= @endDateUTC   or IL.modifiedDate <= @endDateUTC)
	and CarrierCode+' '+FlightNumber not in ('D7 2994','D7 2995','D7 2998','D7 2999','I5 9001')

	--select top 100* from #Inventoryleg

	delete from #Inventorytemp where CarrierCode = 'FD' and FlightNumber in ('2496','2497') and DepartureDate < '2014-02-21'
		
	Update #Inventorytemp
	set DEpartureStation = 'KNO' where DepartureStation = 'MES'
	
	Update #Inventorytemp
	set ArrivalStation = 'KNO' where ArrivalStation = 'MES'
	
	Update #Inventorytemp
	set ODPair = substring(citypairgroup,1,3) + SUBSTRING(CityPairGroup,5,3)
	from #Inventorytemp A
	inner join dw.CityPair B on A.DepartureStation = B.DepartureStation and A.ArrivalStation = B.ArrivalStation
	
		
	
	BEGIN TRY TRUNCATE TABLE #Inventory DROP TABLE #Inventory END TRY BEGIN CATCH END CATCH 
	Select distinct InventoryLegKey, CapturedDate , dayOfYear, dayOfWeek,
	DepartureMonth, DepartureYear, DepartureDate, CarrierCode, FlightNumber, OpSuffix, 
	Hub = 'hub', ODPAIR, DepartureStation, ArrivalStation,
	SUM(Lid) as Lid, SUM(Capacity) as Capacity
	into #Inventory
	from #Inventorytemp
	group by InventoryLegKey, CapturedDate , dayOfYear, dayOfWeek,
	DepartureMonth, DepartureYear, DepartureDate, CarrierCode, FlightNumber, OpSuffix, 
	ODPAIR, DepartureStation, ArrivalStation
	
	--select top 100* from #Inventory
	--where DepartureYear = 2013
	--and DepartureMonth = 'April'
	--and ODPair = 'BKIKUL'



	BEGIN TRY TRUNCATE TABLE Temp_RR_Daily_InventoryRevenue_v3_tmp2 DROP TABLE Temp_RR_Daily_InventoryRevenue_v3_tmp2 END TRY BEGIN CATCH END CATCH 
	select A.CapturedDate, A.DayOfYear, A.DayOfWeek, A.DepartureYear, A.DepartureMonth, A.CarrierCode, Hub, A.FlightNumber,
	ODPair, Sum(SeatsSold) as SeatsSold,  SUM(Lid) AS Lid, SUM(Capacity) as Capacity,
	SUM(BaseFare_RM) as BaseFare_RM, SUM(FuelSurcharge_RM) as FuelSurcharge_RM, SUM(Connecting_RM) as Connecting_RM, SUM(AptCharges_RM) as AptCharges_RM,
	--NEWLY ADDED
	SUM(ThruFare_RM) as ThruFare_RM, SUM(XHISEA_RM) as XHISEA_RM, SUM(ADM_RM) as ADM_RM,
	SUM(BaseFare_AirlineCurrency) as BaseFare_AirlineCurrency, SUM(FuelSurcharge_AirlineCurrency) as FuelSurcharge_AirlineCurrency, SUM(Connecting_AirlineCurrency) as Connecting_AirlineCurrency, SUM(AptCharges_AirlineCurrency) as AptCharges_AirlineCurrency,
	--NEWLY ADDED
	SUM(ThruFare_AirlineCurrency) as ThruFare_AirlineCurrency, SUM(XHISEA_AirlineCurrency) as XHISEA_AirlineCurrency, SUM(ADM_AirlineCurrency) as ADM_AirlineCurrency
	into Temp_RR_Daily_InventoryRevenue_v3_tmp2
	from #Inventory A
	left join #SeatsSold_BaseRevRM B 
		on A.CarrierCode = B.CarrierCode and A.FlightNumber = B.flightNumber and A.DepartureDate = B.DepartureDate
		and A.DepartureStation = B.DepartureStation and A.ArrivalStation = B.ArrivalStation
	group by Hub, A.CapturedDate, A.DayOfYear, A.DayOfWeek, A.DepartureYear, A.DepartureMonth, A.CarrierCode, A.FlightNumber,
	ODPair
	
	
	alter table Temp_RR_Daily_InventoryRevenue_v3_tmp2 alter column Hub varchar(5)
					
	UPDATE A
		SET  A.Hub=B.Hub
		  FROM Temp_RR_Daily_InventoryRevenue_v3_tmp2 A
		INNER JOIN SAT_Hub_info_version_v3 B ON  A.CARRIERCODE=B.CARRIERCODE AND ltrim(rtrim(A.FLIGHTNUMBER))=ltrim(rtrim(B.FLIGHTNUMBER))
		AND (odpair=MarketGroup or (LEFT(odpair,3)=right(marketgroup,3) and RIGHT(odpair,3)=LEFT(marketgroup,3)))
	 
	 UPDATE A
		SET  A.Hub=B.Hub
	FROM Temp_RR_Daily_InventoryRevenue_v3_tmp2 A
		inner JOIN SAT_Hub_info_version_v3 B ON  A.CARRIERCODE=B.CARRIERCODE --AND ltrim(rtrim(A.FLIGHTNUMBER))=ltrim(rtrim(B.FLIGHTNUMBER))
	 AND (odpair=MarketGroup or (LEFT(odpair,3)=right(marketgroup,3) and RIGHT(odpair,3)=LEFT(marketgroup,3)))
	  where A.hub = 'hub'

		
	BEGIN TRY TRUNCATE TABLE Temp_RR_Daily_InventoryRevenue_v4 DROP TABLE Temp_RR_Daily_InventoryRevenue_v4 END TRY BEGIN CATCH END CATCH 
	select CapturedDate, DayOfYear, DayOfWeek, DepartureYear, DepartureMonth, 
	case when CarrierCode = 'PQ' then 'Z2' else CarrierCode end as CarrierCode, Hub, FlightNumber, ODPair, 
	Sum(SeatsSold) as SeatsSold,  SUM(Lid) AS Lid, SUM(Capacity) as Capacity,
	SUM(BaseFare_RM) as BaseFare_RM, SUM(FuelSurcharge_RM) as FuelSurcharge_RM, SUM(Connecting_RM) as Connecting_RM, SUM(AptCharges_RM) as AptCharges_RM,
	SUM(ThruFare_RM) as ThruFare_RM, SUM(XHISEA_RM) as XHISEA_RM, SUM(ADM_RM) as ADM_RM,
	SUM(BaseFare_AirlineCurrency) as BaseFare_AirlineCurrency, SUM(FuelSurcharge_AirlineCurrency) as FuelSurcharge_AirlineCurrency, SUM(Connecting_AirlineCurrency) as Connecting_AirlineCurrency, SUM(AptCharges_AirlineCurrency) as AptCharges_AirlineCurrency,
	SUM(ThruFare_AirlineCurrency) as ThruFare_AirlineCurrency, SUM(XHISEA_AirlineCurrency) as XHISEA_AirlineCurrency, SUM(ADM_AirlineCurrency) as ADM_AirlineCurrency
	into Temp_RR_Daily_InventoryRevenue_v4
	from Temp_RR_Daily_InventoryRevenue_v3_tmp2
	group by CapturedDate, DayOfYear, DayOfWeek, DepartureYear, DepartureMonth, 
	case when CarrierCode = 'PQ' then 'Z2' else CarrierCode end, Hub, FlightNumber, ODPair
	
--select top 100 * from Temp_RR_Daily_InventoryRevenue_v4
/*

SELECT * FROM Temp_RR_Daily_InventoryRevenue_v3_tmp2
where Ltrim(Rtrim(flightnumber)) = '326' 

select distinct FlightNumber, SUM(Capacity) from Temp_RR_Daily_InventoryRevenue_v4
where ODPAIR = 'BLRGOI'
and DepartureMonth = 'July' and DepartureYear = 2014
group by FlightNumber order by FlightNumber

select Distinct DepartureDate, Capacity  from vw_PassengerJourneySegment where DepartureStation+ArrivalStation in ('BLRGOI','GOIBLR')
and FlightNumber in (1320,1321) and CarrierCode = 'I5'
order by DepartureDate
*/
	--select * from Temp_RR_Daily_InventoryRevenue_v3 where FLightNumber in ('2496','2497')
	--where DepartureYear = 2013
	--and DepartureMonth = 'April'
	--and ODPair = 'BKIKUL'
	----and hub = 'BKI'

	--select distinct SUM(Lid) as Lid, DepartureYear, DepartureMonth, CarrierCode, FlightNumber,
	--ODPair, hub, CapturedDate
	--from Temp_RR_Daily_InventoryRevenue_v3
	--where DepartureYear = 2014
	--and DepartureMonth = 'April'
	--and ODPair = 'BKIKUL'
	--and hub = 'BKI'
	----and flightnumber in (8297,8298)
	--group by DepartureYear, DepartureMonth, CarrierCode, FlightNumber, ODPair,hub, CapturedDate
	
END

































GO


