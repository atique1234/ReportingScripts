USE [REZAKWB01]
GO

/****** Object:  StoredProcedure [dbo].[AAII_FLIGHT_PAX_CAPACITY_BY_DEPARTURE]    Script Date: 10/22/2015 12:45:43 ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO






--ALTER PROCEDURE [dbo].[AAII_FLIGHT_PAX_CAPACITY_BY_DEPARTURE]

--AS

DECLARE @startDateUTC   date,
		@endDateUTC		date,
		@MYDateUTC		datetime
	
select @MYDateUTC  = CAST(CONVERT(VARCHAR,GETDATE(), 101) AS DateTime) 
SET @startDateUTC = DATEADD(month,-1,(DATEADD(month, DATEDIFF(month, 0, @MYDateUTC), 0)))
SET @endDateUTC   =  DATEADD(year, DATEDIFF(year,0,getdate()) + 1, -1)
	  
--print @MYDateUTC 
print @startDateUTC
print @endDateUTC

BEGIN TRY DROP TABLE #inventorylegList END TRY BEGIN CATCH END CATCH

select
departuredate,inventorylegid,carriercode,rtrim(ltrim(flightnumber)) flightnumber,
departurestation,arrivalstation,adjustedcapacity capacity
  into #inventorylegList
 from
ods.inventoryleg il
where 
    --departuredate >= '2015-09-27' and departuredate < '2015-09-28'
    departuredate >= @startDateUTC and departuredate < @endDateUTC
    AND IL.CARRIERCODE <> 'BF'
	AND IL.STATUS <> 2
	AND IL.LID > 0
	

	--AAII_FLIGHT_PAX_BY_DEPARTUREDATE

--select top 100 * from ods.passengerjourneysegment



BEGIN TRY DROP TABLE #inventoryPax END TRY BEGIN CATCH END CATCH
	
select 
il.departuredate,isnull(carr_map.mappedcarrier ,IL.CARRIERCODE) carriercode,
il.flightnumber,il.departurestation,il.arrivalstation, pjs.international, il.capacity,
COUNT(distinct pjs.segmentid) pax
into #inventoryPax
 from 
#inventorylegList il
JOIN ods.passengerjourneyleg pjl
on PJL.INVENTORYLEGID = IL.INVENTORYLEGID
JOIN ods.passengerjourneysegment PJS
on PJL.Passengerid = PJS.Passengerid
and PJL.segmentid = PJS.Segmentid
JOIN
ODS.BOOKINGPASSENGER BP
ON
BP.PASSENGERID = PJS.PASSENGERID
JOIN 
ODS.BOOKING BK
on
BK.BOOKINGID = BP.BOOKINGID
AND BK.STATUS IN (2,3)
LEFT JOIN 
AAII_CARRIER_MAPPING carr_map
on carr_map.carriercode = il.carriercode
and ltrim(RTRIM(carr_map.flightnumber)) = ltrim(RTRIM(il.flightnumber))

group by il.departuredate,isnull(carr_map.mappedcarrier ,IL.CARRIERCODE),il.flightnumber,
il.departurestation,il.arrivalstation, pjs.international, il.capacity


BEGIN TRY DROP TABLE #final END TRY BEGIN CATCH END CATCH
	
SELECT P.*,
(CASE WHEN ASCII(SUBSTRING(p.DEPARTURESTATION,1,1)) < ASCII(SUBSTRING(p.ARRIVALSTATION,1,1)) THEN p.DEPARTURESTATION + p.ARRIVALSTATION
	  WHEN ASCII(SUBSTRING(p.DEPARTURESTATION,1,1)) > ASCII(SUBSTRING(p.ARRIVALSTATION,1,1)) THEN p.ArrivalStation + p.DepartureStation
	  ELSE 
		CASE WHEN ASCII(SUBSTRING(p.DEPARTURESTATION,2,1)) < ASCII(SUBSTRING(p.ARRIVALSTATION,2,1)) THEN p.DEPARTURESTATION + p.ARRIVALSTATION
		WHEN ASCII(SUBSTRING(p.DEPARTURESTATION,2,1)) > ASCII(SUBSTRING(p.ARRIVALSTATION,2,1)) THEN p.ArrivalStation + p.DepartureStation
		ELSE
			CASE WHEN ASCII(SUBSTRING(p.DEPARTURESTATION,3,1)) < ASCII(SUBSTRING(p.ARRIVALSTATION,3,1)) THEN p.DEPARTURESTATION + p.ARRIVALSTATION
			WHEN ASCII(SUBSTRING(p.DEPARTURESTATION,3,1)) > ASCII(SUBSTRING(p.ARRIVALSTATION,3,1)) THEN p.ArrivalStation + p.DepartureStation
			ELSE p.DEPARTURESTATION+p.ARRIVALSTATION 
			END
		END
	 END) ROUTE

,p.DEPARTURESTATION+p.ARRIVALSTATION SECTOR, '        ' hub

into #final

from #inventoryPax p


UPDATE A
	SET  A.Hub=B.Hub
	  FROM #final A
	INNER JOIN SAT_Hub_info_version_v3 B ON  A.CARRIERCODE=B.CARRIERCODE AND ltrim(rtrim(A.FLIGHTNUMBER))=ltrim(rtrim(B.FLIGHTNUMBER))
	AND (route=MarketGroup or (LEFT(route,3)=right(marketgroup,3) and RIGHT(route,3)=LEFT(marketgroup,3)))
     

	 
UPDATE A
		SET  A.Hub=isnull(B.Hub,'hub')
	FROM #final A
		inner JOIN SAT_Hub_info_version_v3 B ON  A.CARRIERCODE=B.CARRIERCODE --AND ltrim(rtrim(A.FLIGHTNUMBER))=ltrim(rtrim(B.FLIGHTNUMBER))
	 AND (route=MarketGroup or (LEFT(route,3)=right(marketgroup,3) and RIGHT(route,3)=LEFT(marketgroup,3)))
	  where A.hub = '        '

UPDATE A
		SET  A.Hub='hub'
	FROM #final A	 
	  where A.hub = '        ' 
	  
BEGIN TRY DROP TABLE AAII_FLIGHT_PAX_BY_DEPARTUREDATE END TRY BEGIN CATCH END CATCH

select p.*
INTO AAII_FLIGHT_PAX_BY_DEPARTUREDATE

from
#final p

	  


GO


