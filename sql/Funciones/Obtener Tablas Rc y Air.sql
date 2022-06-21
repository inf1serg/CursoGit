SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION dbo.getTablasRcAir(@tarifa numeric(5, 0) )
RETURNS TABLE 
AS
RETURN 
(
	SELECT codTablaRc, codTablaAir from dbo.tauTarifa where tarifa = @tarifa
)
GO