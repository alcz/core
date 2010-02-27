/*
 * $Id$
 */

#include "simpleio.ch"
#include "hbrddsql.ch"

REQUEST SDDOCI, SQLMIX

PROCEDURE Main()
   LOCAL tmp

   RDDSETDEFAULT( "SQLMIX" )
   SET( _SET_DATEFORMAT, "yyyy-mm-dd" )

   AEVAL( rddList(), {| X | QOut( X ) } )

   ? "-1-"
   ? "Connect:", tmp := RDDINFO( RDDI_CONNECT, { "OCILIB", "ORCL", "scott", "tiger" } )
   IF tmp == 0
      ? "Unable connect to the server"
   ENDIF
   ? "-2-"
   ? "Use:", DBUSEAREA( .T.,, "select * from emp", "emp" )
   ? "-3-"
   ? "Alias:", ALIAS()
   ? "-4-"
   ? "DB struct:", HB_VALTOEXP( DBSTRUCT() )
   ? "-5-"
   INKEY( 0 )
   BROWSE()

   INDEX ON FIELD->SAL TO salary
   DBGOTOP()
   BROWSE()
   DBCLOSEAREA()

   RETURN