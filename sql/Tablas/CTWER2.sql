CREATE TABLE PowerBI.dbo.ctwer2 (
R2EMPR char(1) NOT NULL,R2SUCU char(2) NOT NULL,R2NIVT numeric(1,0) NOT NULL,R2NIVC numeric(5,0) NOT NULL,R2NCTW numeric(7,0) NOT NULL,R2RAMA numeric(2,0) NOT NULL,R2ARSE numeric(2,0) NOT NULL,R2POCO numeric(4,0) NOT NULL,R2RIEC char(3) ,R2XCOB numeric(3,0) ,R2SACO numeric(15,2) ,R2PTCO numeric(15,2) ,R2XPRI numeric(9,6) ,R2PRSA numeric(5,2) ,R2PTCA numeric(15,2) ,R2XPRA numeric(9,6) ,R2MA01 char(1) ,R2MA02 char(1) ,R2MA03 char(1) ,R2MA04 char(1) ,R2MA05 char(1) )
ALTER TABLE PowerBI.dbo.ctwer2 ADD PRIMARY KEY(R2EMPR,R2SUCU,R2NIVT,R2NIVC,R2NCTW,R2RAMA,R2POCO,R2ARSE)