SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION dbo.getTarifaActual()
RETURNS numeric(5, 0)
BEGIN
	
	DECLARE @tarifaActual numeric(5,0)

	set @tarifaActual = (select MAX(tarifa) from dbo.tauTarifa where fechaInicio < CONVERT( date , GETDATE() ) )

	RETURN @tarifaActual

END
GO