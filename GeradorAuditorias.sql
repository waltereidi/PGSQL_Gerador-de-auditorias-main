CREATE OR REPLACE FUNCTION gerar_rules(pSchema VARCHAR(63) )
RETURNS TEXT AS 
$body$


DECLARE 
vAudTable VARCHAR(63);
rTables RECORD ; 
rColumns RECORD ; 
tBigQuery TEXT := '';
BEGIN 

tBigQuery:=tBigQuery||'CREATE SCHEMA IF NOT EXISTS auditoria ;'||E'\n'; 
IF pSchema = (SELECT schema_name FROM information_schema.schemata WHERE schema_name = pSchema) THEN 

FOR rTables IN SELECT table_name FROM information_schema.tables WHERE table_schema= pSchema 
LOOP 

FOR rColumns IN EXECUTE 'SELECT '||$$REPLACE(REPLACE(REPLACE(REPLACE( array_agg('#'||
column_name||'# '||data_type||CASE WHEN data_type='character varying' THEN '('||character_maximum_length||')' ELSE '' END 
)::text ,'{' , ''),E'\"', '' ),'}' , '') ,'#' ,'"')AS query $$||'FROM information_schema.columns WHERE table_schema='||E'\''||pSchema||E'\''||'AND table_name = '||E'\''||rTables.table_name||E'\'' 

LOOP 
vAudTable := 'aud_'||rTables.table_name::varchar(54);
tBigQuery := tBigQuery||'CREATE SEQUENCE IF NOT EXISTS auditoria.'||vAudTable||'_seq;'||E'\n';
tBigQuery := tBigQuery|| 'CREATE TABLE IF NOT EXISTS auditoria."'||vAudTable||'"(
idaud BIGINT DEFAULT nextval('||E'\''||'auditoria.aud_'||rTables.table_name||'_seq'||E'\''||'::regclass),
  tipoaud VARCHAR(1),
  dataaud TIMESTAMP WITHOUT TIME ZONE,
  hostaud VARCHAR(50),
  loginaud VARCHAR(50),'||
rColumns.query|| ' ,'||
'CONSTRAINT "'||vAudTable||'_pkey" '||' PRIMARY KEY(idaud) );'||E'\n'||'COMMIT;';
END LOOP ; 


tBigQuery := tBigQuery || 'CREATE OR REPLACE RULE "rule_'||rTables.table_name::varchar(51)||'_insert" AS '||
'ON INSERT TO '||pSchema||'."'||rTables.table_name||'" DO ('||
'INSERT INTO auditoria."'||vAudTable||'"'||
'SELECT nextval( '||E'\''||'auditoria.aud_'||rTables.table_name||'_seq'||E'\''||'::regclass ) ,'||
E'\''||'I'||E'\'' ||' , now() , '||
'CASE WHEN inet_client_addr() IS NULL THEN '||E'\''||'localhost'||E'\''||'ELSE inet_client_port()::varchar END , '||
'SESSION_USER , NEW.* ); '||E'\n';

tBigQuery := tBigQuery || 'CREATE OR REPLACE RULE "rule_'||rTables.table_name::varchar(51)||'_update" AS '||
'ON UPDATE TO '||pSchema||'."'||rTables.table_name||'" DO ('||
'INSERT INTO auditoria."'||vAudTable||'"'||
'SELECT nextval( '||E'\''||'auditoria.aud_'||rTables.table_name||'_seq'||E'\''||'::regclass ) ,'||
E'\''||'U'||E'\'' ||' , now() , '||
'CASE WHEN inet_client_addr() IS NULL THEN '||E'\''||'localhost'||E'\''||'ELSE inet_client_port()::varchar END , '||
'SESSION_USER , OLD.* ); '||E'\n';

tBigQuery := tBigQuery || 'CREATE OR REPLACE RULE "rule_'||rTables.table_name::varchar(51)||'_delete" AS '||
'ON DELETE TO '||pSchema||'."'||rTables.table_name||'" DO ('||
'INSERT INTO auditoria."'||vAudTable||'"'||
'SELECT nextval( '||E'\''||'auditoria.aud_'||rTables.table_name||'_seq'||E'\''||'::regclass ) ,'||
E'\''||'D'||E'\'' ||' , now() , '||
'CASE WHEN inet_client_addr() IS NULL THEN '||E'\''||'localhost'||E'\''||'ELSE inet_client_port()::varchar END , '||
'SESSION_USER , OLD.* ); '||E'\n';



END LOOP ; 

RETURN tBigQuery ; 

ELSE 
RETURN 'schemata invalido';

END IF ;



END
$body$
LANGUAGE 'plpgsql' ; 