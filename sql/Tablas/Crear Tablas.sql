/*	SET2222 (Tarifa: ctre tarc tair)
	SET2202 (RC)
	SET2221 (AIR)
	SET287  (Factor antig)
	SET215  (vhca vhv1 vhv2)
	SET225  (Coberturas)
	ANTIG   (antig tipo_antig)
	RANGOS  (id rango)
	
*/

CREATE TABLE PowerBI.dbo.tauTarifa (
	tarifa      numeric(5,0) not null,
	fechaInicio date not null,
	codTablaRc  numeric(2, 0) not null,
	codTablaAir numeric(2, 0) not null
)

ALTER TABLE PowerBI.dbo.tauTarifa ADD PRIMARY KEY(tarifa)

CREATE TABLE PowerBI.dbo.tauValoresRc (
	codTablaRc  numeric(2, 0) not null,
	moneda		char(2) not null,
	capitulo    numeric(2, 0) not null,
	varianteRc  numeric(1, 0) not null,
	zona		numeric(1, 0) not null,
	importeRc	numeric(15, 2) not null
)

ALTER TABLE PowerBI.dbo.tauValoresRc ADD PRIMARY KEY(codTablaRc, moneda, capitulo, varianteRc, zona)

CREATE TABLE PowerBI.dbo.tauTasasAir (
	codTablaAir        numeric(2, 0) not null,
	zona		       numeric(1, 0) not null,
	moneda		       char(2)       not null,
	capitulo           numeric(2, 0) not null,
	varianteAir        numeric(1, 0) not null,
	cobertura          char(2)       not null,
	sumaAseguradaHasta numeric(15, 2) not null,
	tasa			   numeric(7, 4) not null
)

ALTER TABLE PowerBI.dbo.tauTasasAir ADD PRIMARY KEY(codTablaAir, zona, moneda, capitulo, varianteAir, cobertura, sumaAseguradaHasta)