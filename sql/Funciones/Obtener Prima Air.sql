/* 
	Obtener importe de AIR anual
	
		Parms: 
				@codTablaAir: Tabla de AIR usada (es una por cada tarifa)
				@zona       : Zona
				@capitulo   : Capitulo del Vehiculo a tarifar
				@varianteAir: Variante de AIR del Vehiculo (OJO a partir de la 123 para las 4x4)
				@moneda     : Moneda en la cual tarifar (siempre va ** porque GAUS la tiene asi)
				
	Sergio Fernandez
	
	La tabla tauTasasAir:
	codTablaAir        numeric(2, 0)  not null    PK
	zona		       numeric(1, 0)  not null    PK
	moneda		       char(2)        not null    PK
	capitulo           numeric(2, 0)  not null    PK
	varianteAir        numeric(1, 0)  not null    PK
	cobertura          char(2)        not null    PK 
	sumaAseguradaHasta numeric(15, 2) not null    PK
	tasa			   numeric(7, 4)  not null
	
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION getImportePrimaAir( @codTablaAir numeric(2,0),
							        @zona numeric(1,0),
									@capitulo numeric(2,0),
									@varianteAir numeric(1,0),
									@moneda char(2),
									@sumaAsegurada numeric(15, 2),
									@cobertura char(2)
)
RETURNS numeric(15,2)
AS
BEGIN
	
	declare @tasa       numeric(7,4)
	declare @importeAir numeric(15,2)
	
	set @tasa = (select top 1 tasa
					from dbo.tauTasasAir
						where codTablaAir = @codTablaAir           and zona = @zona               and 
							  capitulo = @capitulo                 and varianteAir = @varianteAir and
							  sumaAseguradaHasta >= @sumaAsegurada and moneda = @moneda           and
							  cobertura = @cobertura
						order by sumaAseguradaHasta
				)
	set @importeAir = ( @sumaAsegurada * @tasa ) / 1000

	RETURN @importeAir

END
GO