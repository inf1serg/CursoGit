SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION dbo.getDescripcionCapVar(@capitulo numeric(2,0), @varRc numeric(1,0), @varAir numeric(1,0) )
RETURNS varchar(20)
AS 
BEGIN
	 declare @salida varchar(20) 
	 set @salida = (select t@cvde 
					from dbo.set215 
					where t@vhca = @capitulo and t@vhv1 = @varRc and t@vhv2 = @varAir )
	 return @salida 	 
END
GO