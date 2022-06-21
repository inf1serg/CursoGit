SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION getTasaAir( @codTablaAir numeric(2,0),
							@zona numeric(1,0),
							@capitulo numeric(2,0),
							@varianteAir numeric(1,0),
							@moneda char(2),
							@sumaAsegurada numeric(15, 2),
							@cobertura char(2)
)
RETURNS numeric(7,4)
AS
BEGIN
	
	declare @tasa       numeric(7,4)
	
	set @tasa = (select top 1 tasa
					from dbo.tauTasasAir
						where codTablaAir = @codTablaAir           and zona = @zona               and 
							  capitulo = @capitulo                 and varianteAir = @varianteAir and
							  sumaAseguradaHasta >= @sumaAsegurada and moneda = @moneda           and
							  cobertura = @cobertura
						order by sumaAseguradaHasta
				)
				
	RETURN @tasa

END
GO