USE [FEDERACION]
GO
drop procedure if exists [DATOSENVIADOSXMLPRO]
/****** Object:  StoredProcedure [dbo].[PLANTILLANOMINAREP3]    Script Date: 14/07/2021 12:56:23 p. m. ******/
SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

create PROCEDURE [dbo].[DATOSENVIADOSXMLPRO] (   
                                                @Par_Periodo varchar(7),  -- Formato mm/yyyy
                                                @Par_TipoPeriodo varchar(2) ,-- Toma solo los primeros 1000 Registros para procesar (Para pruebas de salida) 0 = sin limite (todos)
                                                @Par_Salida char -- S= Si(Completa) , M=Minimal , N=No 
)
WITH EXEC AS CALLER
AS
BEGIN 

SET NOCOUNT ON
declare @Var_i  int=1
declare @Var_NumConceptos int
declare @Var_TipoConcepto char
declare @Var_Concepto varchar(5)
declare @Var_PeriodoID int

DECLARE @Var_PivColumnas varchar(MAX);
DECLARE @Var_NodosXML varchar(MAX)
DECLARE @Var_PivHeader varchar(MAX);
DECLARE @Var_PivSQL nvarchar(MAX);
DECLARE @Var_XmlSQL NVARCHAR(MAX)

  drop table if exists tmp_comprobanteconceptos
  create TABLE tmp_comprobanteconceptos
  (
      NumComprobante int,
      Plaza varchar(30),
      CURP varchar(30),
      Conceptos xml
  )



truncate table TMP_CONCEPTOS

drop table if exists #CAT_CONCEPTOS
create table #CAT_CONCEPTOS

(
    ConceptoID int IDENTITY(1,1),
    TipoConcepto char,
    Concepto varchar(5),
    ColConcepto varchar(5)
)

SET @Var_PeriodoID=(select PeriodoID from TMP_PERIODOSNOMINA where Periodo=@Par_Periodo)

-- select count(*) from TMP_CONCEPTOS


-- carga detalle

insert into TMP_CONCEPTOS(  NumComprobante,     Plaza,  CURP,   TipoConcepto,   Concepto,
                            Importe,            Consecutivo)
                        
                        
                        select  [NUM_COMPROBANTE],  [PLAZA],    [CURP], [TIPO_CONCEPTO],    [CONCEPTO],	  	
                                coalesce([IMPORTE],0),   row_number() over(partition by [NUM_COMPROBANTE], [PLAZA], [CURP] order by [NUM_COMPROBANTE])  
                        from  Datos_Enviados_Ctos whit(nolock) where PERIODO=  @Par_Periodo  and TIPO_NOMINA=@Par_TipoPeriodo order by CURP asc

insert into  #CAT_CONCEPTOS (TipoConcepto,Concepto)
select   distinct TipoConcepto,Concepto from TMP_CONCEPTOS order by TipoConcepto desc,Concepto asc --226 / 1.130
-- select * from TMP_CONCEPTOS where TipoConcepto='P' and Concepto='43'
-- select * from #CAT_CONCEPTOS

update  #CAT_CONCEPTOS set ColConcepto=concat(TipoConcepto,Concepto)
-- select * from #CAT_CONCEPTOS 


set @Var_NumConceptos = (select count(*) from #CAT_CONCEPTOS )
-- print @Var_NumConceptos
 while @Var_i <=@Var_NumConceptos
 BEGIN
    SET @Var_Concepto=(select Concepto from #CAT_CONCEPTOS where ConceptoID=@Var_i)
    SET @Var_TipoConcepto=(select TipoConcepto from #CAT_CONCEPTOS where ConceptoID=@Var_i)

    update TMP_CONCEPTOS set ConceptoID=@Var_i where TipoConcepto=@Var_TipoConcepto and Concepto=@Var_Concepto

    --  print @Var_i
     set @Var_i=@Var_i+1
 END  -- 1:37



if object_id('tblpivot','U') is not null
begin
    drop table tblpivot
end




SET @Var_PivColumnas=(select STRING_AGG(concat('[', ConceptoID,']'),',') from  #CAT_CONCEPTOS )
SET @Var_PivHeader=(select STRING_AGG(concat('isnull([', ConceptoID,'],0) as ',ColConcepto),',') from #CAT_CONCEPTOS )
SET @Var_NodosXML= (select STRING_AGG(concat('[', ColConcepto,']'),',') from  #CAT_CONCEPTOS )

SET @Var_PivHeader=concat('select NumComprobante,Plaza,CURP,  ',@Var_PivHeader,' into tblpivot FROM (')

SET @Var_PivSQL=' select NumComprobante,Plaza,CURP, ConceptoID, Importe from TMP_CONCEPTOS )as Conceptos PIVOT (sum(Importe) FOR ConceptoID in ('
SET @Var_PivSQL=concat(@Var_PivSQL,@Var_PivColumnas,'))as ConceptosCol')

SET @Var_PivSQL= concat(@Var_PivHeader,@Var_PivSQL)

-- select @Var_PivSQL
exec sp_executesql @Var_PivSQL



--SET @Var_XmlSQL=concat('select NumComprobante,Plaza,CURP,(SELECT ',@Var_NodosXML,' FROM #tblpivot as tmp1 where tmp1.NumComprobante=tmp2.NumComprobante and tmp1.Plaza=tmp2.Plaza and tmp1.CURP=tmp1.CURP FOR XML PATH(''''))as Conceptos ')
SET @Var_XmlSQL=concat('select NumComprobante,Plaza,CURP,(SELECT ',@Var_NodosXML,' FROM tblpivot tmp1  where tmp1.NumComprobante=tmp2.NumComprobante and tmp1.Plaza=tmp2.Plaza and tmp1.CURP=tmp2.CURP FOR XML PATH(''''))as Conceptos ')
SET @Var_XmlSQL=concat(@Var_XmlSQL,' FROM tblpivot as tmp2 ')

-- select @Var_XmlSQL

insert into tmp_comprobanteconceptos(NumComprobante,Plaza,CURP,Conceptos) exec sp_executesql @Var_XmlSQL

insert into datos_enviados_ctosxml(PeriodoID,NumComprobante,Plaza,CURP,Conceptos) select @Var_PeriodoID, NumComprobante,Plaza,CURP,Conceptos from tmp_comprobanteconceptos



select 00 MensajeID,'Terminado' Mensaje

SET NOCOUNT OFF

END
GO



