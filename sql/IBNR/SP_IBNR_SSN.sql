USE [HDI_AR_Actuarial]
GO
/****** Object:  StoredProcedure [dbo].[IBNR_SSN]    Script Date: 09/06/2022 10:47:18 ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO



@CIERRE Date

AS
BEGIN
SET NOCOUNT ON;

--PAGOS MONEDA

DROP TABLE #PMONEDA
SELECT PSRAMA, PSSINI, PSRCCA, PSNIVC, FRONTING=CASE WHEN PSNIVC<11000 THEN 1 ELSE 0 END, PSFSIN, PSJUIN, PSFPAG, PSMONR=CASE WHEN PSMONR=1 THEN 0 ELSE PSMONR END, PSPACP, PAGO, 
	PAGMON=CASE WHEN PSJUIN=0 AND PSMONR<>0 AND PSMONR<>1 THEN HPIMMR ELSE PAGO END,
	AJMON=PAGO-CASE WHEN PSJUIN=0 AND PSMONR<>0 AND PSMONR<>1 THEN HPIMMR*MOCOTV ELSE PAGO END
INTO #PMONEDA
FROM Base_Siniestros a
LEFT JOIN (SELECT HPRAMA, HPPACP, HPIMMR, HPIMAU FROM Pahshp WHERE CAST(CAST (HPFMOD AS VARCHAR)+'/'+CAST(HPFMOM AS VARCHAR)+'/'+CAST(HPFMOA AS VARCHAR) AS DATE)<=@cierre AND HPMONR<>0 AND HPMONR<>1) b ON a.PSPACP=b.HPPACP AND a.PSRAMA=b.HPRAMA
LEFT JOIN (SELECT MOCOMO, MOCOTV, FECHA=CAST(CAST (MOFCOD AS VARCHAR)+'/'+CAST(MOFCOM AS VARCHAR)+'/'+CAST(MOFCOA AS VARCHAR) AS DATE) FROM Gntcmo WHERE MOFCOA<>2100 AND MOFCOA<>1997) c ON a.PSFSIN=c.FECHA AND a.PSMONR=c.MOCOMO
WHERE PSFPAG<=@cierre AND PSFSIN>DATEADD(YEAR, -10, @cierre) AND PSRAMA<>81

--Cuando cruzamos con la base de pagos para traer los montos en moneda tenemos que traer solamente los registros con moneda extranjera porque en pesos puede haber comprobantes de pago duplicados 

--TRAIGO LOS INTERESES EXPLICITOS

DROP TABLE #PEXP
SELECT a.*, AJEXP=CASE WHEN INTEXP IS NULL THEN 0 ELSE INTEXP END, SENT_OCU=CASE WHEN SENT_OCU IS NULL THEN '' ELSE SENT_OCU END
INTO #PEXP
FROM #PMONEDA a
LEFT JOIN InteresesExplicitos b ON a.PSRAMA=b.PSRAMA AND a.PSSINI=b.PSSINI AND a.PSPACP=b.PSPACP

--CALCULO LOS INTERESES IMPLICITOS, PARA LOS QUE TIENEN EXPLICITOS POR UN LADO Y PARA LOS QUE NO POR OTRO

DROP TABLE #PEXPIMP
SELECT PSRAMA, PSSINI, PSRCCA, PSNIVC, FRONTING, PSFSIN, PSJUIN, PSFPAG, PSMONR, PSPACP, PAGO, PAGMON, AJMON, AJEXP, 
		AJIMP=CASE WHEN PSFSIN=SENT_OCU THEN 0 ELSE CASE WHEN SENT_OCU<'01.10.2019' THEN (PAGO-AJMON)-(PAGO-AJMON)*(INDICE_PASIVA_FSIN/INDICE_PASIVA_FSEN) 
		ELSE CASE WHEN SENT_OCU>='01.10.2019' AND PSFSIN>='01.10.2019' THEN (PAGO-AJMON)-(PAGO-AJMON)/(1+TASA_TAP_FSEN-TASA_TAP_FSIN) ELSE 
		((PAGO-AJMON)-(PAGO-AJMON)/(INDICE_PASIVA_ULTIMA/INDICE_PASIVA_FSIN+TASA_TAP_FSEN)) END END END
INTO #PEXPIMP
FROM #PEXP a
LEFT JOIN (SELECT FECHA, INDICE_PASIVA_FSIN=INDICE_PASIVA FROM Indices) b ON a.PSFSIN=b.FECHA
LEFT JOIN (SELECT FECHA, INDICE_PASIVA_FSEN=INDICE_PASIVA FROM Indices) c ON a.SENT_OCU=c.FECHA
LEFT JOIN (SELECT FECHA, INDICE_PASIVA_ULTIMA=INDICE_PASIVA FROM Indices) d ON '30.09.2019'=d.FECHA
LEFT JOIN (SELECT FECHA, TASA_TAP_FSIN=TASA_TAP_ACUMULADA FROM Indices) e ON a.PSFSIN=e.FECHA
LEFT JOIN (SELECT FECHA, TASA_TAP_FSEN=TASA_TAP_ACUMULADA FROM Indices) f ON a.SENT_OCU=f.FECHA
WHERE SENT_OCU<>''

DROP TABLE #PIMP
SELECT PSRAMA, PSSINI, PSRCCA, PSNIVC, FRONTING, PSFSIN, PSJUIN, PSFPAG, PSMONR, PSPACP, PAGO, PAGMON, AJMON, AJEXP,
		AJIMP=CASE WHEN PSFPAG<'01.10.2019' THEN (PAGO-AJMON)-(PAGO-AJMON)*(INDICE_PASIVA_FSIN/INDICE_PASIVA_FPAG) 
		ELSE CASE WHEN PSFPAG>='01.10.2019' AND PSFSIN>='01.10.2019' THEN (PAGO-AJMON)-(PAGO-AJMON)/(1+TASA_TAP_FPAG-TASA_TAP_FSIN) ELSE 
		((PAGO-AJMON)-(PAGO-AJMON)/(INDICE_PASIVA_ULTIMA/INDICE_PASIVA_FSIN+TASA_TAP_FPAG)) END END
INTO #PIMP
FROM #PEXP a
LEFT JOIN (SELECT FECHA, INDICE_PASIVA_FSIN=INDICE_PASIVA FROM Indices) b ON a.PSFSIN=b.FECHA
LEFT JOIN (SELECT FECHA, INDICE_PASIVA_FPAG=INDICE_PASIVA FROM Indices) c ON a.PSFPAG=c.FECHA
LEFT JOIN (SELECT FECHA, INDICE_PASIVA_ULTIMA=INDICE_PASIVA FROM Indices) d ON '30.09.2019'=d.FECHA
LEFT JOIN (SELECT FECHA, TASA_TAP_FSIN=TASA_TAP_ACUMULADA FROM Indices) e ON a.PSFSIN=e.FECHA
LEFT JOIN (SELECT FECHA, TASA_TAP_FPAG=TASA_TAP_ACUMULADA FROM Indices) f ON a.PSFPAG=f.FECHA
WHERE SENT_OCU=''

INSERT INTO #PIMP
SELECT *
FROM #PEXPIMP

--DEJO LIMPIA LA BASE DE PAGOS

DROP TABLE #PAGOS
SELECT RAMA=CASE WHEN PSRAMA<>12 AND PSRCCA='CA' THEN 301 ELSE CASE WHEN PSRAMA<>12 AND (PSRCCA='RC' OR PSRCCA='RP') THEN 302 ELSE CASE WHEN PSRAMA=12 AND PSRCCA='CA' THEN 121 ELSE CASE WHEN PSRAMA=12 AND (PSRCCA='RC' OR PSRCCA='RP') THEN 122 ELSE CASE WHEN (PSNIVC<11000 AND (PSRAMA=8 OR PSRAMA=38)) THEN 81 ELSE CASE WHEN PSRAMA=84 THEN 80 ELSE PSRAMA END END END END END END,
		PSSINI, FRONTING, PSJUIN, PSFSIN=CONVERT(DATE, PSFSIN, 101), PSFPAG=CONVERT(DATE, PSFPAG, 101), PSMONR, PSPACP, PAGO, PAGMON, AJMON=CAST(AJMON AS MONEY), AJEXP=CAST(AJEXP AS MONEY), AJIMP=CAST(AJIMP AS MONEY), PAGODESC=CAST(PAGO-AJMON-AJEXP-AJIMP AS MONEY)
INTO #PAGOS
FROM #PIMP

--SAP MONEDA

--AGRUPO LA TABLA DE RESERVAS DE GAUS

DROP TABLE #SAP0
SELECT HRRAMA,HRSINI, HRNRDF, FECHA=CAST(CAST (HRFMOD AS VARCHAR)+'/'+CAST(HRFMOM AS VARCHAR)+'/'+CAST(HRFMOA AS VARCHAR) AS DATE), 
		HRMONR, HRIMMR, HRIMAU
INTO #SAP0
FROM Pahshr
WHERE HRFMOA>1

--UNIFICO LAS MONEDAS EN PESOS

UPDATE #SAP0
SET HRMONR=CASE WHEN HRMONR=1 THEN 0 ELSE HRMONR END

DROP TABLE #SAP
SELECT HRRAMA,HRSINI, HRNRDF, HRMONR, HRIMMR=SUM(HRIMMR), HRIMAU=SUM(HRIMAU), CIERRE=DATEADD(YEAR, -9, @cierre)
INTO #SAP
FROM #SAP0
WHERE FECHA<=DATEADD(YEAR, -9, @cierre)
GROUP BY HRRAMA,HRSINI, HRNRDF, HRMONR
ORDER BY HRRAMA,HRSINI, HRNRDF, HRMONR

DROP TABLE #SAP2
SELECT HRRAMA,HRSINI, HRNRDF, HRMONR, HRIMMR=SUM(HRIMMR), HRIMAU=SUM(HRIMAU), CIERRE=DATEADD(YEAR, -8, @cierre)
INTO #SAP2
FROM #SAP0
WHERE FECHA<=DATEADD(YEAR, -8, @cierre)
GROUP BY HRRAMA,HRSINI, HRNRDF, HRMONR
ORDER BY HRRAMA,HRSINI, HRNRDF, HRMONR

DROP TABLE #SAP3
SELECT HRRAMA,HRSINI, HRNRDF, HRMONR, HRIMMR=SUM(HRIMMR), HRIMAU=SUM(HRIMAU), CIERRE=DATEADD(YEAR, -7, @cierre)
INTO #SAP3
FROM #SAP0
WHERE FECHA<=DATEADD(YEAR, -7, @cierre)
GROUP BY HRRAMA,HRSINI, HRNRDF, HRMONR
ORDER BY HRRAMA,HRSINI, HRNRDF, HRMONR

DROP TABLE #SAP4
SELECT HRRAMA,HRSINI, HRNRDF, HRMONR, HRIMMR=SUM(HRIMMR), HRIMAU=SUM(HRIMAU), CIERRE=DATEADD(YEAR, -6, @cierre)
INTO #SAP4
FROM #SAP0
WHERE FECHA<=DATEADD(YEAR, -6, @cierre)
GROUP BY HRRAMA,HRSINI, HRNRDF, HRMONR
ORDER BY HRRAMA,HRSINI, HRNRDF, HRMONR

DROP TABLE #SAP5
SELECT HRRAMA,HRSINI, HRNRDF, HRMONR, HRIMMR=SUM(HRIMMR), HRIMAU=SUM(HRIMAU), CIERRE=DATEADD(YEAR, -5, @cierre)
INTO #SAP5
FROM #SAP0
WHERE FECHA<=DATEADD(YEAR, -5, @cierre)
GROUP BY HRRAMA,HRSINI, HRNRDF, HRMONR
ORDER BY HRRAMA,HRSINI, HRNRDF, HRMONR

DROP TABLE #SAP6
SELECT HRRAMA,HRSINI, HRNRDF, HRMONR, HRIMMR=SUM(HRIMMR), HRIMAU=SUM(HRIMAU), CIERRE=DATEADD(YEAR, -4, @cierre)
INTO #SAP6
FROM #SAP0
WHERE FECHA<=DATEADD(YEAR, -4, @cierre)
GROUP BY HRRAMA,HRSINI, HRNRDF, HRMONR
ORDER BY HRRAMA,HRSINI, HRNRDF, HRMONR

DROP TABLE #SAP7
SELECT HRRAMA,HRSINI, HRNRDF, HRMONR, HRIMMR=SUM(HRIMMR), HRIMAU=SUM(HRIMAU), CIERRE=DATEADD(YEAR, -3, @cierre)
INTO #SAP7
FROM #SAP0
WHERE FECHA<=DATEADD(YEAR, -3, @cierre)
GROUP BY HRRAMA,HRSINI, HRNRDF, HRMONR
ORDER BY HRRAMA,HRSINI, HRNRDF, HRMONR

DROP TABLE #SAP8
SELECT HRRAMA,HRSINI, HRNRDF, HRMONR, HRIMMR=SUM(HRIMMR), HRIMAU=SUM(HRIMAU), CIERRE=DATEADD(YEAR, -2, @cierre)
INTO #SAP8
FROM #SAP0
WHERE FECHA<=DATEADD(YEAR, -2, @cierre)
GROUP BY HRRAMA,HRSINI, HRNRDF, HRMONR
ORDER BY HRRAMA,HRSINI, HRNRDF, HRMONR

DROP TABLE #SAP9
SELECT HRRAMA,HRSINI, HRNRDF, HRMONR, HRIMMR=SUM(HRIMMR), HRIMAU=SUM(HRIMAU), CIERRE=DATEADD(YEAR, -1, @cierre)
INTO #SAP9
FROM #SAP0
WHERE FECHA<=DATEADD(YEAR, -1, @cierre)
GROUP BY HRRAMA,HRSINI, HRNRDF, HRMONR
ORDER BY HRRAMA,HRSINI, HRNRDF, HRMONR

DROP TABLE #SAP10
SELECT HRRAMA,HRSINI, HRNRDF, HRMONR, HRIMMR=SUM(HRIMMR), HRIMAU=SUM(HRIMAU), CIERRE=@cierre
INTO #SAP10
FROM #SAP0
WHERE FECHA<=@cierre
GROUP BY HRRAMA,HRSINI, HRNRDF, HRMONR
ORDER BY HRRAMA,HRSINI, HRNRDF, HRMONR

INSERT INTO #SAP
SELECT *
FROM #SAP2
INSERT INTO #SAP
SELECT *
FROM #SAP3
INSERT INTO #SAP
SELECT *
FROM #SAP4
INSERT INTO #SAP
SELECT *
FROM #SAP5
INSERT INTO #SAP
SELECT *
FROM #SAP6
INSERT INTO #SAP
SELECT *
FROM #SAP7
INSERT INTO #SAP
SELECT *
FROM #SAP8
INSERT INTO #SAP
SELECT *
FROM #SAP9
INSERT INTO #SAP
SELECT *
FROM #SAP10

--CRUZO MI RESERVA CON LA TABLA AGREGADA PARA TRAER LA MONEDA Y LOS MONTOS DE RESERVA

DROP TABLE #SMONEDA1
SELECT PSRAMA, PSSINI, PSRCCA, PSNIVC, FRONTING=CASE WHEN PSNIVC<11000 THEN 1 ELSE 0 END, PSFSIN, PSJUIN, PSFPRO, HRMONR, PSBENN, SAP, HRIMMR, HRIMAU
INTO #SMONEDA1
FROM Base_Siniestros a
LEFT JOIN #SAP b ON a.PSBENN=b.HRNRDF AND a.PSRAMA=b.HRRAMA AND a.PSSINI=b.HRSINI AND a.PSFPRO=b.CIERRE
WHERE SAP IS NOT NULL AND PSFSIN>DATEADD(YEAR, -10, @cierre) AND MONTH(PSFPRO)=MONTH(@cierre) AND SAP<>0 AND PSJUIN=0 AND PSBENN IS NOT NULL AND PSFPRO<=@cierre AND PSRAMA<>81

--CHECK PARA CASOS QUE ESTAN EN LA BASE DE SINIESTROS PERO NO EN GAUS

SELECT CasosQueNoCruzan=CAST(PSRAMA AS VARCHAR)+'/'+CAST(PSSINI AS VARCHAR), SAP, ToDo=CASE WHEN SAP<=0 THEN 'Ok, como es negativo no pasa nada' ELSE 'Revisar en que moneda se reservó, el programa le va a poner pesos' END
FROM #SMONEDA1
WHERE HRMONR IS NULL

--ARREGLO LOS CASOS QUE ESTAN EN LA BASE DE SINIESTROS CON SAP NEGATIVA Y NO EN LA DE GAUS

UPDATE #SMONEDA1
SET HRMONR=CASE WHEN HRMONR IS NULL THEN 0 ELSE HRMONR END
UPDATE #SMONEDA1
SET HRIMMR=CASE WHEN HRIMMR IS NULL THEN 0 ELSE HRIMMR END
UPDATE #SMONEDA1
SET HRIMAU=CASE WHEN HRIMAU IS NULL THEN 0 ELSE HRIMAU END

--AGRUPO LA TABLA DE PAGOS DE GAUS

DROP TABLE #PAG0
SELECT HPRAMA,HPSINI, HPNRDF, FECHA=CAST(CAST (HPFMOD AS VARCHAR)+'/'+CAST(HPFMOM AS VARCHAR)+'/'+CAST(HPFMOA AS VARCHAR) AS DATE), 
		HPMONR=CAST(HPMONR AS INT), HPIMMR, HPIMAU
INTO #PAG0
FROM Pahshp

--UNIFICO LAS MONEDAS EN PESOS

UPDATE #PAG0
SET HPMONR=CASE WHEN HPMONR=1 THEN 0 ELSE HPMONR END

DROP TABLE #PAG1
SELECT HPRAMA,HPSINI, HPNRDF, HPMONR, HPIMMR=SUM(HPIMMR), HPIMAU=SUM(HPIMAU), CIERRE=DATEADD(YEAR, -9, @cierre)
INTO #PAG1
FROM #PAG0
WHERE FECHA<=DATEADD(YEAR, -9, @cierre)
GROUP BY HPRAMA,HPSINI, HPNRDF, HPMONR
ORDER BY HPRAMA,HPSINI, HPNRDF, HPMONR

DROP TABLE #PAG2
SELECT HPRAMA,HPSINI, HPNRDF, HPMONR, HPIMMR=SUM(HPIMMR), HPIMAU=SUM(HPIMAU), CIERRE=DATEADD(YEAR, -8, @cierre)
INTO #PAG2
FROM #PAG0
WHERE FECHA<=DATEADD(YEAR, -8, @cierre)
GROUP BY HPRAMA,HPSINI, HPNRDF, HPMONR
ORDER BY HPRAMA,HPSINI, HPNRDF, HPMONR

DROP TABLE #PAG3
SELECT HPRAMA,HPSINI, HPNRDF, HPMONR, HPIMMR=SUM(HPIMMR), HPIMAU=SUM(HPIMAU), CIERRE=DATEADD(YEAR, -7, @cierre)
INTO #PAG3
FROM #PAG0
WHERE FECHA<=DATEADD(YEAR, -7, @cierre)
GROUP BY HPRAMA,HPSINI, HPNRDF, HPMONR
ORDER BY HPRAMA,HPSINI, HPNRDF, HPMONR

DROP TABLE #PAG4
SELECT HPRAMA,HPSINI, HPNRDF, HPMONR, HPIMMR=SUM(HPIMMR), HPIMAU=SUM(HPIMAU), CIERRE=DATEADD(YEAR, -6, @cierre)
INTO #PAG4
FROM #PAG0
WHERE FECHA<=DATEADD(YEAR, -6, @cierre)
GROUP BY HPRAMA,HPSINI, HPNRDF, HPMONR
ORDER BY HPRAMA,HPSINI, HPNRDF, HPMONR

DROP TABLE #PAG5
SELECT HPRAMA,HPSINI, HPNRDF, HPMONR, HPIMMR=SUM(HPIMMR), HPIMAU=SUM(HPIMAU), CIERRE=DATEADD(YEAR, -5, @cierre)
INTO #PAG5
FROM #PAG0
WHERE FECHA<=DATEADD(YEAR, -5, @cierre)
GROUP BY HPRAMA,HPSINI, HPNRDF, HPMONR
ORDER BY HPRAMA,HPSINI, HPNRDF, HPMONR

DROP TABLE #PAG6
SELECT HPRAMA,HPSINI, HPNRDF, HPMONR, HPIMMR=SUM(HPIMMR), HPIMAU=SUM(HPIMAU), CIERRE=DATEADD(YEAR, -4, @cierre)
INTO #PAG6
FROM #PAG0
WHERE FECHA<=DATEADD(YEAR, -4, @cierre)
GROUP BY HPRAMA,HPSINI, HPNRDF, HPMONR
ORDER BY HPRAMA,HPSINI, HPNRDF, HPMONR

DROP TABLE #PAG7
SELECT HPRAMA,HPSINI, HPNRDF, HPMONR, HPIMMR=SUM(HPIMMR), HPIMAU=SUM(HPIMAU), CIERRE=DATEADD(YEAR, -3, @cierre)
INTO #PAG7
FROM #PAG0
WHERE FECHA<=DATEADD(YEAR, -3, @cierre)
GROUP BY HPRAMA,HPSINI, HPNRDF, HPMONR
ORDER BY HPRAMA,HPSINI, HPNRDF, HPMONR

DROP TABLE #PAG8
SELECT HPRAMA,HPSINI, HPNRDF, HPMONR, HPIMMR=SUM(HPIMMR), HPIMAU=SUM(HPIMAU), CIERRE=DATEADD(YEAR, -2, @cierre)
INTO #PAG8
FROM #PAG0
WHERE FECHA<=DATEADD(YEAR, -2, @cierre)
GROUP BY HPRAMA,HPSINI, HPNRDF, HPMONR
ORDER BY HPRAMA,HPSINI, HPNRDF, HPMONR

DROP TABLE #PAG9
SELECT HPRAMA,HPSINI, HPNRDF, HPMONR, HPIMMR=SUM(HPIMMR), HPIMAU=SUM(HPIMAU), CIERRE=DATEADD(YEAR, -1, @cierre)
INTO #PAG9
FROM #PAG0
WHERE FECHA<=DATEADD(YEAR, -1, @cierre)
GROUP BY HPRAMA,HPSINI, HPNRDF, HPMONR
ORDER BY HPRAMA,HPSINI, HPNRDF, HPMONR

DROP TABLE #PAG10
SELECT HPRAMA,HPSINI, HPNRDF, HPMONR, HPIMMR=SUM(HPIMMR), HPIMAU=SUM(HPIMAU), CIERRE=@cierre
INTO #PAG10
FROM #PAG0
WHERE FECHA<=@cierre
GROUP BY HPRAMA,HPSINI, HPNRDF, HPMONR
ORDER BY HPRAMA,HPSINI, HPNRDF, HPMONR

INSERT INTO #PAG1
SELECT *
FROM #PAG2
INSERT INTO #PAG1
SELECT *
FROM #PAG3
INSERT INTO #PAG1
SELECT *
FROM #PAG4
INSERT INTO #PAG1
SELECT *
FROM #PAG5
INSERT INTO #PAG1
SELECT *
FROM #PAG6
INSERT INTO #PAG1
SELECT *
FROM #PAG7
INSERT INTO #PAG1
SELECT *
FROM #PAG8
INSERT INTO #PAG1
SELECT *
FROM #PAG9
INSERT INTO #PAG1
SELECT *
FROM #PAG10


--TRAIGO LOS PAGOS A LA BASE DE RESERVA

DROP TABLE #SYP
SELECT a.*, HPIMMR=CASE WHEN b.HPIMMR IS NULL THEN 0 ELSE b.HPIMMR END, HPIMAU=CASE WHEN b.HPIMAU IS NULL THEN 0 ELSE b.HPIMAU END
INTO #SYP
FROM #SMONEDA1 a
LEFT JOIN #PAG1 b ON a.PSRAMA=b.HPRAMA AND a.PSSINI=b.HPSINI AND a.PSFPRO=b.CIERRE AND a.PSBENN=b.HPNRDF AND a.HRMONR=b.HPMONR

--AGRUPO LA BASE DE FRANQUICIAS DE GAUS

DROP TABLE #FRA0
SELECT FRRAMA,FRSINI, FRNRDF, FECHA=CAST(CAST (FRFMOD AS VARCHAR)+'/'+CAST(FRFMOM AS VARCHAR)+'/'+CAST(FRFMOA AS VARCHAR) AS DATE), 
		FRMONR=CAST(frmonr as int), FRIMMR, FRIMAU
INTO #FRA0
FROM Pahsfr
WHERE FRFMOA>0

--UNIFICO LAS MONEDAS EN PESOS

UPDATE #FRA0
SET FRMONR=CASE WHEN FRMONR=1 THEN 0 ELSE FRMONR END

DROP TABLE #FRA
SELECT FRRAMA,FRSINI, FRNRDF, FRMONR, FRIMMR=SUM(FRIMMR), FRIMAU=SUM(FRIMAU), CIERRE=DATEADD(YEAR, -9, @cierre)
INTO #FRA
FROM #FRA0
WHERE FECHA<=DATEADD(YEAR, -9, @cierre)
GROUP BY FRRAMA,FRSINI, FRNRDF, FRMONR
ORDER BY FRRAMA,FRSINI, FRNRDF, FRMONR

DROP TABLE #FRA2
SELECT FRRAMA,FRSINI, FRNRDF, FRMONR, FRIMMR=SUM(FRIMMR), FRIMAU=SUM(FRIMAU), CIERRE=DATEADD(YEAR, -8, @cierre)
INTO #FRA2
FROM #FRA0
WHERE FECHA<=DATEADD(YEAR, -8, @cierre)
GROUP BY FRRAMA,FRSINI, FRNRDF, FRMONR
ORDER BY FRRAMA,FRSINI, FRNRDF, FRMONR

DROP TABLE #FRA3
SELECT FRRAMA,FRSINI, FRNRDF, FRMONR, FRIMMR=SUM(FRIMMR), FRIMAU=SUM(FRIMAU), CIERRE=DATEADD(YEAR, -7, @cierre)
INTO #FRA3
FROM #FRA0
WHERE FECHA<=DATEADD(YEAR, -7, @cierre)
GROUP BY FRRAMA,FRSINI, FRNRDF, FRMONR
ORDER BY FRRAMA,FRSINI, FRNRDF, FRMONR

DROP TABLE #FRA4
SELECT FRRAMA,FRSINI, FRNRDF, FRMONR, FRIMMR=SUM(FRIMMR), FRIMAU=SUM(FRIMAU), CIERRE=DATEADD(YEAR, -6, @cierre)
INTO #FRA4
FROM #FRA0
WHERE FECHA<=DATEADD(YEAR, -6, @cierre)
GROUP BY FRRAMA,FRSINI, FRNRDF, FRMONR
ORDER BY FRRAMA,FRSINI, FRNRDF, FRMONR

DROP TABLE #FRA5
SELECT FRRAMA,FRSINI, FRNRDF, FRMONR, FRIMMR=SUM(FRIMMR), FRIMAU=SUM(FRIMAU), CIERRE=DATEADD(YEAR, -5, @cierre)
INTO #FRA5
FROM #FRA0
WHERE FECHA<=DATEADD(YEAR, -5, @cierre)
GROUP BY FRRAMA,FRSINI, FRNRDF, FRMONR
ORDER BY FRRAMA,FRSINI, FRNRDF, FRMONR

DROP TABLE #FRA6
SELECT FRRAMA,FRSINI, FRNRDF, FRMONR, FRIMMR=SUM(FRIMMR), FRIMAU=SUM(FRIMAU), CIERRE=DATEADD(YEAR, -4, @cierre)
INTO #FRA6
FROM #FRA0
WHERE FECHA<=DATEADD(YEAR, -4, @cierre)
GROUP BY FRRAMA,FRSINI, FRNRDF, FRMONR
ORDER BY FRRAMA,FRSINI, FRNRDF, FRMONR

DROP TABLE #FRA7
SELECT FRRAMA,FRSINI, FRNRDF, FRMONR, FRIMMR=SUM(FRIMMR), FRIMAU=SUM(FRIMAU), CIERRE=DATEADD(YEAR, -3, @cierre)
INTO #FRA7
FROM #FRA0
WHERE FECHA<=DATEADD(YEAR, -3, @cierre)
GROUP BY FRRAMA,FRSINI, FRNRDF, FRMONR
ORDER BY FRRAMA,FRSINI, FRNRDF, FRMONR

DROP TABLE #FRA8
SELECT FRRAMA,FRSINI, FRNRDF, FRMONR, FRIMMR=SUM(FRIMMR), FRIMAU=SUM(FRIMAU), CIERRE=DATEADD(YEAR, -2, @cierre)
INTO #FRA8
FROM #FRA0
WHERE FECHA<=DATEADD(YEAR, -2, @cierre)
GROUP BY FRRAMA,FRSINI, FRNRDF, FRMONR
ORDER BY FRRAMA,FRSINI, FRNRDF, FRMONR

DROP TABLE #FRA9
SELECT FRRAMA,FRSINI, FRNRDF, FRMONR, FRIMMR=SUM(FRIMMR), FRIMAU=SUM(FRIMAU), CIERRE=DATEADD(YEAR, -1, @cierre)
INTO #FRA9
FROM #FRA0
WHERE FECHA<=DATEADD(YEAR, -1, @cierre)
GROUP BY FRRAMA,FRSINI, FRNRDF, FRMONR
ORDER BY FRRAMA,FRSINI, FRNRDF, FRMONR

DROP TABLE #FRA10
SELECT FRRAMA,FRSINI, FRNRDF, FRMONR, FRIMMR=SUM(FRIMMR), FRIMAU=SUM(FRIMAU), CIERRE=@cierre
INTO #FRA10
FROM #FRA0
WHERE FECHA<=@cierre
GROUP BY FRRAMA,FRSINI, FRNRDF, FRMONR
ORDER BY FRRAMA,FRSINI, FRNRDF, FRMONR

INSERT INTO #FRA
SELECT *
FROM #FRA2
INSERT INTO #FRA
SELECT *
FROM #FRA3
INSERT INTO #FRA
SELECT *
FROM #FRA4
INSERT INTO #FRA
SELECT *
FROM #FRA5
INSERT INTO #FRA
SELECT *
FROM #FRA6
INSERT INTO #FRA
SELECT *
FROM #FRA7
INSERT INTO #FRA
SELECT *
FROM #FRA8
INSERT INTO #FRA
SELECT *
FROM #FRA9
INSERT INTO #FRA
SELECT *
FROM #FRA10

--TRAIGO LAS FRANQUICIAS A LA BASE DE RESERVA Y PAGO

DROP TABLE #SPYF
SELECT a.*, FRIMMR=CASE WHEN b.FRIMMR IS NULL THEN 0 ELSE b.FRIMMR END, FRIMAU=CASE WHEN b.FRIMAU IS NULL THEN 0 ELSE b.FRIMAU END
INTO #SPYF
FROM #SYP a
LEFT JOIN #FRA b ON a.PSRAMA=b.FRRAMA AND a.PSSINI=b.FRSINI AND a.PSFPRO=b.CIERRE AND a.PSBENN=b.FRNRDF AND a.HRMONR=b.FRMONR

DROP TABLE #Z
SELECT PSRAMA, PSSINI, PSBENN, PSFPRO, HRMONR
INTO #Z
FROM #SPYF

DROP TABLE #Y
SELECT PSRAMA, PSSINI, PSBENN=CAST(PSBENN AS INT), PSFPRO, NUM=COUNT(HRMONR)
INTO #Y
FROM #Z
GROUP BY PSRAMA, PSSINI, PSBENN, PSFPRO
HAVING COUNT(HRMONR)>1

SELECT BeneficiariosConVariasMonedas=CAST(PSRAMA AS VARCHAR)+'/'+CAST(PSSINI AS VARCHAR)+'/'+CAST(PSBENN AS VARCHAR), NUM
FROM #Y
WHERE NUM>1

DROP TABLE #X
SELECT a.*, NUM
INTO #X
FROM #SPYF a
LEFT JOIN #Y b ON a.PSRAMA=b.PSRAMA AND a.PSSINI=b.PSSINI AND a.PSBENN=b.PSBENN AND a.PSFPRO=b.PSFPRO


drop table #SMONEDA2
SELECT PSRAMA, PSSINI, PSRCCA, PSNIVC, FRONTING=CASE WHEN PSNIVC<11000 THEN 1 ELSE 0 END, PSFSIN, PSJUIN, PSFPRO, HRMONR, PSBENN, SAP, SAPMON=CASE WHEN HRMONR<2 AND NUM IS NULL THEN SAP ELSE HRIMMR-HPIMMR-FRIMMR END,
	AJMON=SAP-CASE WHEN HRMONR=0 THEN SAP ELSE (HRIMMR-HPIMMR-FRIMMR)*MOCOTV END, F=CASE WHEN (CASE WHEN HRMONR=0 AND NUM IS NULL THEN SAP ELSE HRIMMR-HPIMMR-FRIMMR END)=0 AND NUM IS NOT NULL THEN 1 ELSE 0 END
INTO #SMONEDA2
FROM #X a
LEFT JOIN (SELECT MOCOMO, MOCOTV, FECHA=CAST(CAST (MOFCOD AS VARCHAR)+'/'+CAST(MOFCOM AS VARCHAR)+'/'+CAST(MOFCOA AS VARCHAR) AS DATE) FROM Gntcmo WHERE MOFCOA<>2100 AND MOFCOA<>1997) c ON a.PSFSIN=c.FECHA AND a.HRMONR=c.MOCOMO

DROP TABLE #SMONEDA
SELECT PSRAMA, PSSINI, PSRCCA, PSNIVC, FRONTING, PSFSIN, PSJUIN, PSFPRO, PSMONR=HRMONR, PSBENN, SAP, SAPMON, AJMON
INTO #SMONEDA
FROM #SMONEDA2
WHERE F=0

--AGREGO JUICIOS Y MEDIACIONES A MI BASE

DROP TABLE #JYM
SELECT PSRAMA, PSSINI, PSRCCA, PSNIVC, FRONTING=CASE WHEN PSNIVC<11000 THEN 1 ELSE 0 END, PSFSIN, PSJUIN, PSFPRO, PSMONR=CASE WHEN PSMONR=1 THEN 0 ELSE PSMONR END, PSBENN, SAP, SAPMON=SAP, AJMON=0
INTO #JYM
FROM Base_Siniestros a
WHERE SAP IS NOT NULL AND PSFSIN>DATEADD(YEAR, -10, @cierre) AND MONTH(PSFPRO)=MONTH(@cierre) AND SAP<>0 AND (PSJUIN<>0 OR PSJUIN IS NULL OR (PSJUIN=0 AND PSBENN IS NULL)) AND PSFPRO<=@cierre AND PSRAMA<>81

INSERT INTO #SMONEDA
SELECT *
FROM #JYM

--CALCULO INTERESES IMPLICITOS

DROP TABLE #SIMP
SELECT PSRAMA, PSSINI, PSRCCA, PSNIVC, FRONTING, PSFSIN, PSJUIN, PSFPRO, PSMONR, PSBENN, SAP, SAPMON, AJMON, AJEXP=0,
		AJIMP=CASE WHEN PSFPRO<'01.10.2019' THEN (SAP-AJMON)-(SAP-AJMON)*(INDICE_PASIVA_FSIN/INDICE_PASIVA_FPRO)
		ELSE CASE WHEN PSFPRO>='01.10.2019' AND PSFSIN>='01.10.2019' THEN (SAP-AJMON)-(SAP-AJMON)/(1+TASA_TAP_FPRO-TASA_TAP_FSIN) ELSE 
		((SAP-AJMON)-(SAP-AJMON)/(INDICE_PASIVA_ULTIMA/INDICE_PASIVA_FSIN+TASA_TAP_FPRO)) END END
INTO #SIMP
FROM #SMONEDA a
LEFT JOIN (SELECT FECHA, INDICE_PASIVA_FSIN=INDICE_PASIVA FROM Indices) b ON a.PSFSIN=b.FECHA
LEFT JOIN (SELECT FECHA, INDICE_PASIVA_FPRO=INDICE_PASIVA FROM Indices) c ON a.PSFPRO=c.FECHA
LEFT JOIN (SELECT FECHA, INDICE_PASIVA_ULTIMA=INDICE_PASIVA FROM Indices) d ON '30.09.2019'=d.FECHA
LEFT JOIN (SELECT FECHA, TASA_TAP_FSIN=TASA_TAP_ACUMULADA FROM Indices) e ON a.PSFSIN=e.FECHA
LEFT JOIN (SELECT FECHA, TASA_TAP_FPRO=TASA_TAP_ACUMULADA FROM Indices) f ON a.PSFPRO=f.FECHA


-- INFORMES DE ABOGADO

drop table #Informes
select a.*, Exp=b.[Aj exp]
into #Informes
from #SIMP a
left join DescInformes b on a.psrama=b.Rama and a.pssini=b.Siniestro and a.psjuin=b.juicio and a.psfpro=b.[Fecha cierre]

drop table #Informes2
select PSRAMA, PSSINI, PSRCCA, PSNIVC, FRONTING, PSFSIN, PSJUIN, PSFPRO, PSMONR, PSBENN, SAP, SAPMON, AJMON, AJEXP=CASE WHEN EXP IS NOT NULL THEN EXP ELSE 0 END, AJIMP= CASE WHEN EXP IS NOT NULL THEN 0 ELSE AJIMP END
into #Informes2
from #Informes

--DEJO LIMPIA LA BASE DE RESERVA

DROP TABLE #RESERVA
SELECT RAMA=CASE WHEN PSRAMA<>12 AND PSRCCA='CA' THEN 301 ELSE CASE WHEN PSRAMA<>12 AND (PSRCCA='RC' OR PSRCCA='RP') THEN 302 ELSE CASE WHEN PSRAMA=12 AND PSRCCA='CA' THEN 121 ELSE CASE WHEN PSRAMA=12 AND (PSRCCA='RC' OR PSRCCA='RP') THEN 122 ELSE CASE WHEN (PSNIVC<11000 AND (PSRAMA=8 OR PSRAMA=38)) THEN 81 ELSE CASE WHEN PSRAMA=84 THEN 80 ELSE PSRAMA END END END END END END,
		PSSINI, FRONTING, PSJUIN, PSFSIN=CONVERT(DATE, PSFSIN, 101), PSFPRO=CONVERT(DATE, PSFPRO, 101), PSMONR, PSBENN, SAP, SAPMON, AJMON=CAST(AJMON AS MONEY), AJEXP=CAST(AJEXP AS MONEY), AJIMP=CAST(AJIMP AS MONEY), SAPDESC=CAST(SAP-AJMON-AJEXP-AJIMP AS MONEY)
INTO #RESERVA
FROM #Informes2

--AGRUPO BASE DE PAGOS

DROP TABLE #PAG
SELECT RAMA, PSSINI, FRONTING, PSJUIN=CASE WHEN PSJUIN IS NULL THEN 0 ELSE PSJUIN END, PSFSIN, FDES=PSFPAG, PSMONR=CASE WHEN PSMONR IS NULL THEN 0 ELSE PSMONR END, ID=CAST(PSPACP AS INT), MONTO=PAGO, MONTOMON=PAGMON, AJMON, AJEXP, AJIMP, MONTODESC=PAGODESC, TIPO='Pago', 
		OCU=CASE WHEN MONTH(PSFSIN)>MONTH(@cierre) THEN YEAR(PSFSIN)+1 ELSE YEAR(PSFSIN) END, 
		DEV=(CASE WHEN MONTH(PSFPAG)>MONTH(@cierre) THEN YEAR(PSFPAG)+1 ELSE YEAR(PSFPAG) END)-CASE WHEN MONTH(PSFSIN)>MONTH(@cierre) THEN YEAR(PSFSIN)+1 ELSE YEAR(PSFSIN) END 
INTO #PAG
FROM #PAGOS

DROP TABLE #PAGAC
SELECT RAMA, PSSINI, FRONTING, PSJUIN=9999, PSFSIN, FDES, PSMONR=9999, ID=9999, MONTO=SUM(MONTO), MONTOMON=SUM(MONTOMON), AJMON=SUM(AJMON), AJEXP=SUM(AJEXP), AJIMP=SUM(AJIMP), MONTODESC=SUM(MONTODESC), TIPO, OCU, DEV=0
INTO #PAGAC
FROM #PAG
WHERE DEV<=0 AND OCU<=YEAR(@cierre)
GROUP BY RAMA, PSSINI, FRONTING, PSFSIN, FDES, TIPO, OCU, DEV

DROP TABLE #PAGAC1
SELECT RAMA, PSSINI, FRONTING, PSJUIN=9999, PSFSIN, FDES, PSMONR=9999, ID=9999, MONTO=SUM(MONTO), MONTOMON=SUM(MONTOMON), AJMON=SUM(AJMON), AJEXP=SUM(AJEXP), AJIMP=SUM(AJIMP), MONTODESC=SUM(MONTODESC), TIPO, OCU, DEV=1
INTO #PAGAC1
FROM #PAG
WHERE DEV<=1 AND OCU<=YEAR(@cierre)-1
GROUP BY RAMA, PSSINI, FRONTING, PSFSIN, FDES, TIPO, OCU, DEV

DROP TABLE #PAGAC2
SELECT RAMA, PSSINI, FRONTING, PSJUIN=9999, PSFSIN, FDES, PSMONR=9999, ID=9999, MONTO=SUM(MONTO), MONTOMON=SUM(MONTOMON), AJMON=SUM(AJMON), AJEXP=SUM(AJEXP), AJIMP=SUM(AJIMP), MONTODESC=SUM(MONTODESC), TIPO, OCU, DEV=2
INTO #PAGAC2
FROM #PAG
WHERE DEV<=2 AND OCU<=YEAR(@cierre)-2
GROUP BY RAMA, PSSINI, FRONTING, PSFSIN, FDES, TIPO, OCU, DEV

DROP TABLE #PAGAC3
SELECT RAMA, PSSINI, FRONTING, PSJUIN=9999, PSFSIN, FDES, PSMONR=9999, ID=9999, MONTO=SUM(MONTO), MONTOMON=SUM(MONTOMON), AJMON=SUM(AJMON), AJEXP=SUM(AJEXP), AJIMP=SUM(AJIMP), MONTODESC=SUM(MONTODESC), TIPO, OCU, DEV=3
INTO #PAGAC3
FROM #PAG
WHERE DEV<4 AND  OCU<=YEAR(@cierre)-3
GROUP BY RAMA, PSSINI, FRONTING, PSFSIN, FDES, TIPO, OCU, DEV

DROP TABLE #PAGAC4
SELECT RAMA, PSSINI, FRONTING, PSJUIN=9999, PSFSIN, FDES, PSMONR=9999, ID=9999, MONTO=SUM(MONTO), MONTOMON=SUM(MONTOMON), AJMON=SUM(AJMON), AJEXP=SUM(AJEXP), AJIMP=SUM(AJIMP), MONTODESC=SUM(MONTODESC), TIPO, OCU, DEV=4
INTO #PAGAC4
FROM #PAG
WHERE DEV<5 AND  OCU<=YEAR(@cierre)-4
GROUP BY RAMA, PSSINI, FRONTING, PSFSIN, FDES, TIPO, OCU, DEV

DROP TABLE #PAGAC5
SELECT RAMA, PSSINI, FRONTING, PSJUIN=9999, PSFSIN, FDES, PSMONR=9999, ID=9999, MONTO=SUM(MONTO), MONTOMON=SUM(MONTOMON), AJMON=SUM(AJMON), AJEXP=SUM(AJEXP), AJIMP=SUM(AJIMP), MONTODESC=SUM(MONTODESC), TIPO, OCU, DEV=5
INTO #PAGAC5
FROM #PAG
WHERE DEV<6 AND  OCU<=YEAR(@cierre)-5
GROUP BY RAMA, PSSINI, FRONTING, PSFSIN, FDES, TIPO, OCU, DEV

DROP TABLE #PAGAC6
SELECT RAMA, PSSINI, FRONTING, PSJUIN=9999, PSFSIN, FDES, PSMONR=9999, ID=9999, MONTO=SUM(MONTO), MONTOMON=SUM(MONTOMON), AJMON=SUM(AJMON), AJEXP=SUM(AJEXP), AJIMP=SUM(AJIMP), MONTODESC=SUM(MONTODESC), TIPO, OCU, DEV=6
INTO #PAGAC6
FROM #PAG
WHERE DEV<7 AND  OCU<=YEAR(@cierre)-6
GROUP BY RAMA, PSSINI, FRONTING, PSFSIN, FDES, TIPO, OCU, DEV

DROP TABLE #PAGAC7
SELECT RAMA, PSSINI, FRONTING, PSJUIN=9999, PSFSIN, FDES, PSMONR=9999, ID=9999, MONTO=SUM(MONTO), MONTOMON=SUM(MONTOMON), AJMON=SUM(AJMON), AJEXP=SUM(AJEXP), AJIMP=SUM(AJIMP), MONTODESC=SUM(MONTODESC), TIPO, OCU, DEV=7
INTO #PAGAC7
FROM #PAG
WHERE DEV<8 AND  OCU<=YEAR(@cierre)-7
GROUP BY RAMA, PSSINI, FRONTING, PSFSIN, FDES, TIPO, OCU, DEV

DROP TABLE #PAGAC8
SELECT RAMA, PSSINI, FRONTING, PSJUIN=9999, PSFSIN, FDES, PSMONR=9999, ID=9999, MONTO=SUM(MONTO), MONTOMON=SUM(MONTOMON), AJMON=SUM(AJMON), AJEXP=SUM(AJEXP), AJIMP=SUM(AJIMP), MONTODESC=SUM(MONTODESC), TIPO, OCU, DEV=8
INTO #PAGAC8
FROM #PAG
WHERE DEV<9 AND  OCU<=YEAR(@cierre)-8
GROUP BY RAMA, PSSINI, FRONTING, PSFSIN, FDES, TIPO, OCU, DEV

DROP TABLE #PAGAC9
SELECT RAMA, PSSINI, FRONTING, PSJUIN=9999, PSFSIN, FDES, PSMONR=9999, ID=9999, MONTO=SUM(MONTO), MONTOMON=SUM(MONTOMON), AJMON=SUM(AJMON), AJEXP=SUM(AJEXP), AJIMP=SUM(AJIMP), MONTODESC=SUM(MONTODESC), TIPO, OCU, DEV=9
INTO #PAGAC9
FROM #PAG
WHERE DEV<10 AND  OCU<=YEAR(@cierre)-9
GROUP BY RAMA, PSSINI, FRONTING, PSFSIN, FDES, TIPO, OCU, DEV

INSERT INTO #PAGAC
SELECT *
FROM #PAGAC1
INSERT INTO #PAGAC
SELECT *
FROM #PAGAC2
INSERT INTO #PAGAC
SELECT *
FROM #PAGAC3
INSERT INTO #PAGAC
SELECT *
FROM #PAGAC4
INSERT INTO #PAGAC
SELECT *
FROM #PAGAC5
INSERT INTO #PAGAC
SELECT *
FROM #PAGAC6
INSERT INTO #PAGAC
SELECT *
FROM #PAGAC7
INSERT INTO #PAGAC
SELECT *
FROM #PAGAC8
INSERT INTO #PAGAC
SELECT *
FROM #PAGAC9

DROP TABLE #RES
SELECT RAMA, PSSINI, FRONTING, PSJUIN=CASE WHEN PSJUIN IS NULL THEN 0 ELSE PSJUIN END, PSFSIN, FDES=PSFPRO, PSMONR=CASE WHEN PSMONR IS NULL THEN 0 ELSE PSMONR END, ID=CASE WHEN PSBENN IS NULL THEN 0 ELSE CAST(PSBENN AS INT) END, MONTO=SAP, MONTOMON=SAPMON, AJMON, AJEXP, AJIMP, MONTODESC=SAPDESC, TIPO='Reserva',
		OCU=CASE WHEN MONTH(PSFSIN)>MONTH(@cierre) THEN YEAR(PSFSIN)+1 ELSE YEAR(PSFSIN) END, 
		DEV=(CASE WHEN MONTH(PSFPRO)>MONTH(@cierre) THEN YEAR(PSFPRO)+1 ELSE YEAR(PSFPRO) END)-CASE WHEN MONTH(PSFSIN)>MONTH(@cierre) THEN YEAR(PSFSIN)+1 ELSE YEAR(PSFSIN) END 
INTO #RES
FROM #RESERVA

DROP TABLE #SAPAC
SELECT RAMA, PSSINI, FRONTING, PSJUIN=9999, PSFSIN, FDES, PSMONR=9999, ID=9999, MONTO=SUM(MONTO), MONTOMON=SUM(MONTOMON), AJMON=SUM(AJMON), AJEXP=SUM(AJEXP), AJIMP=SUM(AJIMP), MONTODESC=SUM(MONTODESC), TIPO, OCU, DEV
INTO #SAPAC
FROM #RES
GROUP BY RAMA, PSSINI, FRONTING, PSFSIN, FDES, TIPO, OCU, DEV

INSERT INTO #SAPAC
SELECT *
FROM #PAGAC

DROP TABLE #INC
SELECT RAMA, PSSINI, FRONTING, PSJUIN, PSFSIN, FDES=CONVERT(DATE, DATEADD(YEAR, -(YEAR(@cierre)-OCU-DEV), @cierre), 101), PSMONR, ID, MONTO=SUM(MONTO), MONTOMON=SUM(MONTOMON), AJMON=SUM(AJMON), AJEXP=SUM(AJEXP), AJIMP=SUM(AJIMP), MONTODESC=SUM(MONTODESC), TIPO='Incurrido', OCU, DEV
INTO #INC
FROM #SAPAC
GROUP BY RAMA, PSSINI, FRONTING, PSJUIN, PSFSIN, PSMONR, ID, OCU, DEV

INSERT INTO #INC
SELECT *
FROM #PAG
INSERT INTO #INC
SELECT *
FROM #RES

DROP TABLE #CELL
SELECT RAMA, OCU, DEV, CELL=SUM(MONTODESC)
INTO #CELL
FROM #INC
WHERE TIPO='INCURRIDO'
GROUP BY RAMA, OCU, DEV

DROP TABLE #PUNTA
SELECT a.*, PUNTA=CASE WHEN (MONTODESC/CELL)>0.095 THEN 1 ELSE 0 END 
INTO #PUNTA
FROM #INC a
LEFT JOIN #CELL b ON a.RAMA=b.RAMA AND a.OCU=b.OCU AND a.DEV=b.DEV
WHERE TIPO='INCURRIDO'

DROP TABLE #PUNTAS
SELECT DISTINCT RAMA, PSSINI, PUNTA
INTO #PUNTAS
FROM #PUNTA
WHERE PUNTA=1
ORDER BY RAMA, PSSINI

DROP TABLE #RAMAS
SELECT DISTINCT PSRAMA, PSSINI, PSRCCA=CASE WHEN PSRCCA='RP' THEN 'RC' ELSE PSRCCA END, PSNIVC, RAMA=CASE WHEN PSRAMA<>12 AND PSRCCA='CA' THEN 301 ELSE CASE WHEN PSRAMA<>12 AND (PSRCCA='RC' OR PSRCCA='RP') THEN 302 ELSE CASE WHEN PSRAMA=12 AND PSRCCA='CA' THEN 121 ELSE CASE WHEN PSRAMA=12 AND (PSRCCA='RC' OR PSRCCA='RP') THEN 122 ELSE CASE WHEN (PSNIVC<11000 AND (PSRAMA=8 OR PSRAMA=38)) THEN 81 ELSE CASE WHEN PSRAMA=84 THEN 80 ELSE PSRAMA END END END END END END
INTO #RAMAS
FROM Base_Siniestros
ORDER BY PSRAMA, PSSINI

DROP TABLE dbo.Base_IBNR_SSN_porSini
SELECT PSRAMA, PSRCCA, PSNIVC, a.*, PUNTA=CASE WHEN PUNTA IS NULL THEN 0 ELSE PUNTA END
INTO dbo.Base_IBNR_SSN_porSini
FROM #INC a
LEFT JOIN #PUNTAS b ON a.RAMA=b.RAMA AND a.PSSINI=b.PSSINI
LEFT JOIN #RAMAS c ON a.RAMA=c.RAMA AND a.PSSINI=c.PSSINI

DROP TABLE dbo.Base_IBNR_SSN
SELECT RAMA, TIPO, FRONTING, OCU, DEV, MONTO=SUM(MONTO), MONTODESC=SUM(MONTODESC), PUNTA
INTO dbo.Base_IBNR_SSN
FROM dbo.Base_IBNR_SSN_porSini
GROUP BY RAMA, TIPO, FRONTING, OCU, DEV, PUNTA
ORDER BY RAMA, TIPO, FRONTING, OCU, DEV, PUNTA

DROP TABLE dbo.Base_IBNR_SSN_Auditores
select PSRAMA, PSRCCA, PSNIVC, PSSINI, FRONTING, PSFSIN, FDES, PSMONR, ID, MONTO, MONTOMON, AJEXP, TIPO
INTO dbo.Base_IBNR_SSN_Auditores
from Base_IBNR_SSN_porSini
WHERE TIPO<>'INCURRIDO' AND PSMONR<>0

DROP TABLE #EXP
select PSRAMA, PSRCCA, PSNIVC, PSSINI, FRONTING, PSFSIN, FDES, PSMONR, ID, MONTO, MONTOMON, AJEXP, TIPO
INTO #EXP
from Base_IBNR_SSN_porSini
WHERE TIPO<>'INCURRIDO' AND AJEXP<>0

INSERT INTO Base_IBNR_SSN_Auditores
SELECT *
FROM #EXP


/*Base de emision PWC*/

DROP TABLE dbo.Base_Emision_PWC
SELECT P0RAMA AS RAMA, P0POLI AS POLIZA, P0ENDO AS ENDOSO, CASE WHEN PROD>=10000 aND PROD<11000 THEN 1 ELSE 0 END AS PM, P0MONE AS MONEDA, P1FEMI AS FEMI, P1VIGD AS FVIGD, P1VIGH AS FVIGH, SUM(P1PRIMA) AS PRIMA, SUM(P1READ) AS 'READ', SUM(P1DERE) AS DERE, SUM(P1REFI) AS REFI, SUM(P1COMI) AS COMI, P0COME AS TCEMI
INTO dbo.Base_Emision_PWC
FROM Base_Emision 
WHERE P1FEMI>DATEADD(YEAR, -2, @cierre) and P0RAMA<>89
GROUP BY P0RAMA, P0POLI, P0ENDO, P0MONE, CASE WHEN PROD>=10000 aND PROD<11000 THEN 1 ELSE 0 END, P1FEMI, P1VIGD, P1VIGH, P0COME
ORDER BY P0RAMA, P0POLI, P0ENDO, P0MONE, CASE WHEN PROD>=10000 aND PROD<11000 THEN 1 ELSE 0 END, P1FEMI, P1VIGD, P1VIGH, P0COME

/*Base IBNR PWC*/

--PAGOS

DROP TABLE #P
SELECT PSRAMA, PSSINI, PSRCCA, PSNIVC, FRONTING=CASE WHEN PSNIVC<11000 THEN 1 ELSE 0 END, PSFSIN, PSJUIN, PSFPAG, PSMONR=CASE WHEN PSMONR=1 THEN 0 ELSE PSMONR END, PSPACP, PAGO
INTO #P
FROM Base_Siniestros a
LEFT JOIN (SELECT HPRAMA, HPPACP, HPIMMR, HPIMAU FROM Pahshp WHERE CAST(CAST (HPFMOD AS VARCHAR)+'/'+CAST(HPFMOM AS VARCHAR)+'/'+CAST(HPFMOA AS VARCHAR) AS DATE)<=@cierre AND HPMONR<>0 AND HPMONR<>1) b ON a.PSPACP=b.HPPACP AND a.PSRAMA=b.HPRAMA
LEFT JOIN (SELECT MOCOMO, MOCOTV, FECHA=CAST(CAST (MOFCOD AS VARCHAR)+'/'+CAST(MOFCOM AS VARCHAR)+'/'+CAST(MOFCOA AS VARCHAR) AS DATE) FROM Gntcmo WHERE MOFCOA<>2100 AND MOFCOA<>1997) c ON a.PSFSIN=c.FECHA AND a.PSMONR=c.MOCOMO
WHERE PSFPAG<=@cierre AND PSRAMA<>81

--DEJO LIMPIA LA BASE DE PAGOS

DROP TABLE #P1
SELECT PSRAMA, PSSINI, PSRCCA, PSNIVC, FRONTING, PSJUIN, PSFSIN=CONVERT(DATE, PSFSIN, 101), PSFPAG=CONVERT(DATE, PSFPAG, 101), PSMONR, PSPACP, PAGO, TIPO='Pago'
INTO #P1
FROM #P

--RESERVA

DROP TABLE #S
SELECT PSRAMA, PSSINI, PSRCCA, PSNIVC, FRONTING=CASE WHEN PSNIVC<11000 THEN 1 ELSE 0 END, PSFSIN, PSJUIN, PSFPRO, PSMONR, PSBENN, SAP
INTO #S
FROM Base_Siniestros
WHERE SAP IS NOT NULL AND MONTH(PSFPRO)=MONTH(@cierre) AND SAP<>0 AND PSFPRO<=@cierre AND PSRAMA<>81

--DEJO LIMPIA LA BASE DE RESERVA

DROP TABLE #R
SELECT RAMA=PSRAMA, PSSINI, PSRCCA, PSNIVC, FRONTING, PSJUIN, PSFSIN=CONVERT(DATE, PSFSIN, 101), PSFPRO=CONVERT(DATE, PSFPRO, 101), PSMONR, PSBENN, SAP, TIPO='Reserva'
INTO #R
FROM #S

--AGRUPO

INSERT INTO #R
SELECT *
FROM #P1

DROP TABLE #BaseporSini
SELECT RAMA, PSSINI, PSRCCA=CASE WHEN PSRCCA<>'CA' AND PSRCCA<>'' THEN 'RC' ELSE PSRCCA END, PSNIVC, FRONTING, PSJUIN, ID=PSBENN, PSFSIN, FDES=PSFPRO, MONTO=SAP, TIPO
INTO #BaseporSini
FROM #R

DROP TABLE #BASE
SELECT RAMA, PSRCCA, SINIESTRO=PSSINI, JUICIO=CASE WHEN PSJUIN=0 THEN 0 ELSE 1 END, ID, PM=FRONTING, FSIN=PSFSIN, FDES, MONTO, TIPO
INTO #BASE
FROM #BaseporSini
WHERE RAMA<>89 AND FDES>DATEADD(YEAR, -10, @cierre)
ORDER BY RAMA, PSSINI

--ARREGLO POLIZA DE FRONTING CON PSNIVC=14000

UPDATE #BASE
SET PM=CASE WHEN RAMA=8 AND (SINIESTRO=708 OR SINIESTRO=778 OR SINIESTRO=1505 OR SINIESTRO=608) THEN 1 ELSE 0 END

--AGREGO PUNTAS

DROP TABLE #E
SELECT R=CASE WHEN RAMA<>12 AND PSRCCA='CA' THEN 301 ELSE CASE WHEN RAMA<>12 AND (PSRCCA='RC' OR PSRCCA='RP') THEN 302 ELSE CASE WHEN RAMA=12 AND PSRCCA='CA' THEN 121 ELSE CASE WHEN RAMA=12 AND (PSRCCA='RC' OR PSRCCA='RP') THEN 122 ELSE CASE WHEN (PM=1 AND (RAMA=8 OR RAMA=38)) THEN 81 ELSE CASE WHEN RAMA=84 THEN 80 ELSE RAMA END END END END END END, *
INTO #E 
FROM #BASE

DROP TABLE Base_IBNR_SSN_PWC
SELECT a.RAMA, PSRCCA, SINIESTRO, JUICIO, ID, PM, FSIN, FDES, MONTO, TIPO, PUNTA=CASE WHEN PUNTA IS NULL THEN 0 ELSE PUNTA END
INTO Base_IBNR_SSN_PWC
FROM #E a
LEFT JOIN #PUNTAS b ON a.R=b.RAMA AND a.SINIESTRO=b.PSSINI

DROP TABLE #PMONEDA
DROP TABLE #PEXP
DROP TABLE #PEXPIMP
DROP TABLE #PIMP
DROP TABLE #PAGOS
DROP TABLE #SAP0
DROP TABLE #SAP
DROP TABLE #SAP2
DROP TABLE #SAP3
DROP TABLE #SAP4
DROP TABLE #SAP5
DROP TABLE #SAP6
DROP TABLE #SAP7
DROP TABLE #SAP8
DROP TABLE #SAP9
DROP TABLE #SAP10
DROP TABLE #SMONEDA1
DROP TABLE #PAG0
DROP TABLE #PAG1
DROP TABLE #PAG2
DROP TABLE #PAG3
DROP TABLE #PAG4
DROP TABLE #PAG5
DROP TABLE #PAG6
DROP TABLE #PAG7
DROP TABLE #PAG8
DROP TABLE #PAG9
DROP TABLE #PAG10
DROP TABLE #SYP
DROP TABLE #FRA0
DROP TABLE #FRA
DROP TABLE #FRA2
DROP TABLE #FRA3
DROP TABLE #FRA4
DROP TABLE #FRA5
DROP TABLE #FRA6
DROP TABLE #FRA7
DROP TABLE #FRA8
DROP TABLE #FRA9
DROP TABLE #FRA10
DROP TABLE #SPYF
DROP TABLE #Z
DROP TABLE #Y
DROP TABLE #X
DROP TABLE #SMONEDA2
DROP TABLE #SMONEDA
DROP TABLE #JYM
DROP TABLE #SIMP
DROP TABLE #RESERVA
DROP TABLE #PAG
DROP TABLE #PAGAC
DROP TABLE #PAGAC1
DROP TABLE #PAGAC2
DROP TABLE #PAGAC3
DROP TABLE #PAGAC4
DROP TABLE #PAGAC5
DROP TABLE #PAGAC6
DROP TABLE #PAGAC7
DROP TABLE #PAGAC8
DROP TABLE #PAGAC9
DROP TABLE #RES
DROP TABLE #SAPAC
DROP TABLE #INC
DROP TABLE #CELL
DROP TABLE #PUNTA
DROP TABLE #PUNTAS
DROP TABLE #RAMAS
DROP TABLE #EXP
DROP TABLE #P
DROP TABLE #P1
DROP TABLE #S
DROP TABLE #R
DROP TABLE #BaseporSini
DROP TABLE #BASE
DROP TABLE #E

Print 'Finalizacion Stored Procedure IBNR'


