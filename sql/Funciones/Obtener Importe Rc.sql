/* 
	Obtener importe de RC anual
	
		Parms: 
				@codTablaRc: Tabla de RC usada (es una por cada tarifa)
				@zona      : Zona
				@capitulo  : Capitulo del Vehiculo a tarifar
				@varianteRC: Variante de RC del Vehiculo (OJO a partir de la 123)
				@moneda    : Moneda en la cual tarifar
				
	Sergio Fernandez
	
	La tabla tauValoresRc:
		codTablaRc numeric(2,0) not null       PK
		zona       numeric(1,0) not null       PK
		capitulo   numeric(2,0) not null       PK
		varianteRc numeric(1,0) not null       PK 
		moneda     char(2)      not null       PK
		importeRC  numeric(15,2)
	
*/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION getImporteRc( @codTablaRc numeric(2,0),
							  @zona numeric(1,0),
							  @capitulo numeric(2,0),
							  @varianteRc numeric(1,0),
							  @moneda char(1)
)
RETURNS numeric(15,2)
AS
BEGIN
	
	DECLARE @importeRc numeric(15,2)

	set @importeRC = ( select importeRc from dbo.tauValoresRc ) 

	RETURN @importeRC

END
GO