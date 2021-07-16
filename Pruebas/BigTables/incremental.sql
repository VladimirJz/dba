drop table if exists datos_enviados_ctosxml;
truncate table datos_enviados_ctosxml
CREATE TABLE [dbo].[datos_enviados_ctosxml](
    [PeriodoID]     INT,
	[NumComprobante] [int] NULL,
	[Plaza] [varchar](30) NULL,
	[CURP] [varchar](30) NULL,
	[Conceptos] [xml] NULL
)
GO



--- INCREMENTAL DE BD

truncate table TMP_CONCEPTOS

drop table if exists #CAT_CONCEPTOS
create table #CAT_CONCEPTOS

(
    ConceptoID int IDENTITY(1,1),
    TipoConcepto char,
    Concepto varchar(5),
    ColConcepto varchar(5)
)



