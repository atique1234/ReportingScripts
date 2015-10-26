USE [REZAKWB01]
GO

/****** Object:  StoredProcedure [dbo].[AAII_AU_GRID_V1]    Script Date: 10/22/2015 15:46:15 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO





--ALTER PROCEDURE [dbo].[AAII_AU_GRID_V1]
--AS

DECLARE @pivotClause1 nvarchar(4000),
		@selectClause1 nvarchar(4000),
		@pivotClause2 nvarchar(4000),
		@selectClause2 nvarchar(4000),
		@pivotClause3 nvarchar(max),
		@selectClause3 nvarchar(max),
		@pivotClause4 nvarchar(max),
		@selectClause4 nvarchar(max),
		@query	nvarchar(MAX),
		@MYDateUTC	DATETIME, 
		@STARTDATE DATETIME,
		@CAPDATE DATETIME,
		@ENDDATE DATETIME


--SET @MYDateUTC = '2015-05-15'
select @MYDateUTC  = ods.ConvertDate( 'MY', GETDATE(),0,0)				
--select @MYDateUTC  = DATEADD(HH,+8,GetDate()) --CONVERT(DATE,DOWNLOADDATE) FROM SAT_AA_L_DOWNLOADDATE	
SET @STARTDATE= CAST(CONVERT(VARCHAR, DateAdd(day,0,@MYDateUTC), 101) AS DateTime)
SET @ENDDATE= CAST(CONVERT(VARCHAR, @MYDateUTC, 101) AS DateTime)
--SET @STARTDATE= ods.convertdate('my',CAST(CONVERT(VARCHAR, DATEADD(s, 1,DATEADD(mm, DATEDIFF(m,0,DateAdd(month,-6,@MYDateUTC)),0)), 101) AS DateTime), 1, 0)
--SET @ENDDATE=CAST(CONVERT(VARCHAR, DATEADD(s, 1,DATEADD(mm, DATEDIFF(m,0,DateAdd(month,0,@MYDateUTC)),0)), 101) AS DateTime)


print @MYDateUTC
print @STARTDATE
print @ENDDATE

BEGIN TRY TRUNCATE TABLE #Inventory DROP TABLE #Inventory END TRY BEGIN CATCH END CATCH 
BEGIN TRY TRUNCATE TABLE REZAKWB01.DBO.AAII_AU_GRID_MAIN DROP TABLE REZAKWB01.DBO.AAII_AU_GRID_MAIN END TRY BEGIN CATCH END CATCH 

Select DISTINCT 
	Il.InventoryLegId,
	IL.InventoryLegKey,
	CP.CityPairGroup,
	CONVERT (DATE, IL.DepartureDate, 110) DepartureDate,isnull(carr_map.mappedcarrier ,IL.CARRIERCODE) CarrierCode,
	LTrim(RTrim(IL.FlightNumber)) As FlightNumber,
	IL.DepartureStation,
	IL.ArrivalStation,IL.OpSuffix,
	IL.Lid,
	IL.AdjustedCapacity,
	IL.Capacity,
	ILC.ClassNest,
	ILC.ClassOfService,
	ILC.ClassAU,
	ILC.ClassSold,
	ISNULL(CASE WHEN ILC.ClassOfService ='DI' THEN ILC.ClassSold END,0) AS DICount, -- ADDED MATHEW 9th May
	ISNULL(CASE WHEN ILC.ClassOfService ='A1' THEN ILC.ClassSold END,0) AS A1Count, -- ADDED MATHEW 9th May
	ISNULL(CASE WHEN ILC.ClassOfService ='A2' THEN ILC.ClassSold END,0) AS A2Count,
	ISNULL(CASE WHEN ILC.ClassOfService ='W' THEN ILC.ClassSold END,0) AS WCount
Into 
	#Inventory
From 
	ods.InventoryLeg  IL 
LEFT JOIN 
AAII_CARRIER_MAPPING carr_map
on carr_map.carriercode = il.carriercode
and ltrim(RTRIM(carr_map.flightnumber)) = ltrim(RTRIM(il.flightnumber))
	
Inner Join ods.InventoryLegCLass ILC 
	ON IL.InventorylegId = ILC.InventorylegId 
Inner Join dw.CityPair CP 
	On IL.DepartureStation = CP.DepartureStation 
	And IL.ArrivalStation = CP.ArrivalStation
--Inner Join #Carrier CR 
--	On IL.CarrierCode = CR.Value
Where 
	IL.Status <> 2 
	--And  
	--(
	--	(IL.DepartureStation = COALESCE( @departureStation, IL.DepartureStation) And IL.ArrivalStation = COALESCE( @arrivalStation, IL.ArrivalStation))
	--	Or 
	--	(IL.DepartureStation =  COALESCE( @arrivalStation, IL.DepartureStation) And IL.ArrivalStation =  COALESCE( @departureStation, IL.ArrivalStation))
	--)
	And 
	IL.DepartureDate >= @STARTDATE
	--And IL.DepartureDate < @ENDDATE
	--IL.DepartureDate < @STARTDATE
	--and IL.InventoryLegkey ='20130704 JW 865 NGOICN'
GROUP BY 
	Il.InventoryLegId,
	IL.InventoryLegKey,
	CP.CityPairGroup,
	CONVERT (DATE, IL.DepartureDate, 110),
	isnull(carr_map.mappedcarrier ,IL.CARRIERCODE),
	IL.FlightNumber,
	IL.DepartureStation,
	IL.ArrivalStation,
	IL.OpSuffix,
	IL.Lid,
	IL.AdjustedCapacity,
	IL.Capacity,
	ILC.ClassNest,
	ILC.ClassOfService,
	ILC.ClassAU,
	ILC.ClassSold,
	ILC.ClassOfService

--select * from #Inventory where classofservice  in ('y','yf' )

BEGIN TRY TRUNCATE TABLE #InventorySeatSold DROP TABLE #InventorySeatSold END TRY BEGIN CATCH END CATCH 
Select distinct InventoryLegId,ClassNest,sum(ClassSold) As SeatSold,
SUM(DICount) as DICount, -- added mathew
SUM(A1Count) as A1Count, -- added Mathew 21 June 2013
SUM(A2Count) as A2Count,
SUM(WCount) as WCount
Into #InventorySeatSold
From #Inventory
Group By InventoryLegId,ClassNest

--select * from #InventorySeatSold where InventoryLegid ='1871007'


BEGIN TRY TRUNCATE TABLE #InventorySeatSold2 DROP TABLE #InventorySeatSold2 END TRY BEGIN CATCH END CATCH 
Select distinct InventoryLegId,SUM(ClassSold) As SeatSold,
SUM(DICount) as DICount, -- added mathew
SUM(A1Count) as A1Count, -- added Mathew 21 June 2013
SUM(A2Count) as A2Count,
SUM(WCount) as WCount
Into #InventorySeatSold2
From #Inventory
Group By InventoryLegId

--select * from #InventorySeatSold2 where inventorylegid='1871007'

BEGIN TRY TRUNCATE TABLE #InventoryLid DROP TABLE #InventoryLid END TRY BEGIN CATCH END CATCH 
Select Distinct InventoryLegId,Lid
Into #InventoryLid 
From #Inventory
Where ClassOfService = 'Y'

BEGIN TRY TRUNCATE TABLE #InventoryAvail DROP TABLE #InventoryAvail END TRY BEGIN CATCH END CATCH
Select distinct A.*,B.SeatSold,CASE WHEN A.ClassAU > B.SeatSold THEN A.ClassAU - B.SeatSold Else 0 End As ClassAvail 
Into #InventoryAvail
From #Inventory  A
Inner Join #InventorySeatSold B On A.InventoryLegId = B.InventoryLegId And A.ClassNest = B.ClassNest


--select * from #InventoryAvail where classofservice='y' 

BEGIN TRY TRUNCATE TABLE #InventoryAvail2 DROP TABLE #InventoryAvail2 END TRY BEGIN CATCH END CATCH
Select distinct @MYDateUTC CAPTUREDATE, A.InventoryLegId,InventoryLegKey,CityPairGroup,DepartureDate,
CarrierCode,FlightNumber,DepartureStation,ArrivalStation,OpSuffix,Lid,AdjustedCapacity,Capacity,
ClassOfService,ClassAU,ClassSold,B.SeatSold,ClassAvail,a.DICount,a.A1Count,a.A2Count,a.WCount
Into #InventoryAvail2
From #InventoryAvail A 
Inner Join #InventorySeatSold2 B On A.InventoryLegId = B.InventoryLegId

EXEC [dw].[ScriptPivotFields] 
	'SELECT ClassOfServiceCode From ods.ClassofService 
	Where Len(ClassOfServiceCode) = 1
	Or ClassOfServiceCode in (''A1'' ,''A2'',''DI'',''IF'',''AF'',''VF'',''PF'',''LF'',''UF'',''TF'',''QF'',''MF'',''OB'',''O1'',''YF'')
	Order By ClassOfServiceCode ',--Where Len(ClassOfServiceCode) = 1 Order By ClassOfServiceCode', 
	@pivotClause1 OUTPUT, 
	@selectClause1 OUTPUT;
	
	
EXEC [dw].[ScriptPivotFields] 
	'SELECT ClassOfServiceCode + ''-AU'' From ods.ClassofService
	Where Len(ClassOfServiceCode) = 1
	Or ClassOfServiceCode in (''A1'',''A2'',''DI'',''IF'',''AF'',''VF'',''PF'',''LF'',''UF'',''TF'',''QF'',''MF'',''OB'',''O1'',''YF'')
	Order By ClassOfServiceCode ',--Where Len(ClassOfServiceCode) = 1 Order By ClassOfServiceCode', 
	@pivotClause2 OUTPUT, 
	@selectClause2 OUTPUT;	

	
Set @selectClause3 = @selectClause1 
Set @pivotClause3 = @pivotClause1 
Set @selectClause4 = @selectClause2 
Set @pivotClause4 = @pivotClause2


Set @query ='
BEGIN TRY TRUNCATE TABLE #Final DROP TABLE #Final END TRY BEGIN CATCH END CATCH 
Select distinct PVT.InventoryLegId,'+ @selectClause4 + ','+ @selectClause3 + '
Into #Final 
From
(Select InventoryLegId,ClassOfService,ClassAvail From  #InventoryAvail2) TMP 
PIVOT (Sum(ClassAvail) For ClassOfService In ('+@pivotClause3+ ') ) AS PVT,
(Select InventoryLegId, ClassOfService + ''-AU'' As ClassOfService,ClassAU From  #InventoryAvail2) TMP 
PIVOT (Sum(ClassAU) For  ClassOfService In ('+@pivotClause4+ ') ) AS PVT2
Where PVT.InventoryLegId = PVT2.InventoryLegId
BEGIN TRY TRUNCATE TABLE #Final2 DROP TABLE #Final2 END TRY BEGIN CATCH END CATCH 
Select Distinct CAPTUREDATE, A.InventoryLegId,InventoryLegKey,CityPairGroup,DepartureDate,CarrierCode,FlightNumber,DepartureStation,ArrivalStation,OpSuffix,
Lid,AdjustedCapacity,Capacity,SeatSold,'+ @selectClause4 + ','+ @selectClause3 + '
Into #Final2
From #InventoryAvail2 A 
Inner Join #Final B On A.InventoryLegId = B.InventoryLegId 
--DICount,A1Count

BEGIN TRY TRUNCATE TABLE #Final3 DROP TABLE #Final3 END TRY BEGIN CATCH END CATCH 
Select * 
INTO #Final3 
From 
#Final2 
Order by DepartureDate,InventoryLegId 

UPDATE A
SET DI = [di-au]-[DICOUNT]
FROM #Final3 A
INNER JOIN #InventoryAvail2 B
ON A.InventoryLegId = B.InventoryLegId 
WHERE B.Classofservice =''DI''

uPDATE A
SET A1 = [A1-AU]-[A1COUNT] --commented by mathew 27 Mac 2014
--SET A1 = [A1COUNT]
FROM #Final3 A
INNER JOIN #InventoryAvail2 B
ON A.InventoryLegId = B.InventoryLegId 
WHERE B.Classofservice =''A1''


uPDATE A
SET A2 = [A2-AU]-[A2COUNT] --
FROM #Final3 A
INNER JOIN #InventoryAvail2 B
ON A.InventoryLegId = B.InventoryLegId 
WHERE B.Classofservice =''A2''

uPDATE A
SET W = [W-AU]-[WCOUNT] --
FROM #Final3 A
INNER JOIN #InventoryAvail2 B
ON A.InventoryLegId = B.InventoryLegId 
WHERE B.Classofservice =''W''

--INSERT INTO REZAKWB01.DBO.AAII_AU_GRID_MAIN
SELECT DISTINCT CAPTUREDATE, InventoryLegId,InventoryLegKey,CityPairGroup, DepartureDate,CarrierCode,FlightNumber,DepartureStation,ArrivalStation,OpSuffix,Lid,AdjustedCapacity,Capacity,SeatSold,
[A-AU],[A1-AU],[B-AU],[C-AU],[D-AU],[DI-AU],[E-AU],[F-AU],[G-AU],[H-AU],[I-AU],[J-AU],[K-AU],[L-AU],[M-AU],[N-AU],[O-AU],[P-AU],[Q-AU],[R-AU],[S-AU],[T-AU],[U-AU],
[V-AU],[W-AU],[X-AU],[Y-AU],[Z-AU],[A],[A1],[B],[C],[D],case when DI < 0 then 0 else [DI] end as DI,[E],[F],[G],[H],[I],[J],[K],[L],[M],[N],[O],[P],[Q],[R],[S],[T],[U],[V],[W],[X],[Y],[Z],
[AF-AU],[A2-AU],[IF-AU],[LF-AU],[MF-AU],[OB-AU],[O1-AU],[PF-AU],[QF-AU],[TF-AU],[UF-AU],[VF-AU],[YF-AU],[AF],[A2],[IF],[LF],[MF],[OB],[O1],[PF],[QF],[TF],[UF],[VF],[YF]
INTO REZAKWB01.DBO.AAII_AU_GRID_MAIN
FROM #Final3 
Order by DepartureDate,InventoryLegId 

'

EXEC ( @query) 








GO


