/*
 * $Id$
 */

/*
 * Harbour Project source code:
 *    uHTTPD (Micro HTTP server) cookie functions
 *
 * Copyright 2009 Francesco Saverio Giudice <info / at / fsgiudice.com>
 * www - http://harbour-project.org
 *
 * This program is free software; you can redistribute it and/or modify
 * it under the terms of the GNU General Public License as published by
 * the Free Software Foundation; either version 2, or (at your option)
 * any later version.
 *
 * This program is distributed in the hope that it will be useful,
 * but WITHOUT ANY WARRANTY; without even the implied warranty of
 * MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
 * GNU General Public License for more details.
 *
 * You should have received a copy of the GNU General Public License
 * along with this software; see the file COPYING.  If not, write to
 * the Free Software Foundation, Inc., 59 Temple Place, Suite 330,
 * Boston, MA 02111-1307 USA (or visit the web site http://www.gnu.org/).
 *
 * As a special exception, the Harbour Project gives permission for
 * additional uses of the text contained in its release of Harbour.
 *
 * The exception is that, if you link the Harbour libraries with other
 * files to produce an executable, this does not by itself cause the
 * resulting executable to be covered by the GNU General Public License.
 * Your use of that executable is in no way restricted on account of
 * linking the Harbour library code into it.
 *
 * This exception does not however invalidate any other reasons why
 * the executable file might be covered by the GNU General Public License.
 *
 * This exception applies only to the code released by the Harbour
 * Project under the name Harbour.  If you copy code from other
 * Harbour Project or Free Software Foundation releases into a copy of
 * Harbour, as the General Public License permits, the exception does
 * not apply to the code that you add in this way.  To avoid misleading
 * anyone as to the status of such modified files, you must delete
 * this exception notice from them.
 *
 * If you write modifications of your own for Harbour, it is your choice
 * whether to permit this exception to apply to your modifications.
 * If you do not wish that, delete this exception notice.
 *
 */

#include "common.ch"
#include "hbclass.ch"

#command IF <lexpr> THEN <*statement*>  =>;
         IF (<lexpr>) ; <statement> ; END

#command IF <lexpr> THEN <statement1> ELSE <statement2> =>;
         IF (<lexpr>) ; <statement1> ; ELSE ; <statement2> ; END

MEMVAR _COOKIE

FUNCTION uhttpd_CookieNew( cDomain, cPath, nExpireDays, nExpireSecs )
RETURN uhttpd_Cookie():New( cDomain, cPath, nExpireDays, nExpireSecs )

CLASS uhttpd_Cookie

   // Data for cookies
   DATA aCookies           INIT {}  // Using an array to mantain order
   DATA cDomain
   DATA cPath              INIT "/"
   DATA cExpire
   DATA lSecure            INIT .F.
   DATA lHttpOnly
   DATA nExpireDays        INIT 0
   DATA nExpireSecs        INIT 7200       // 1 hour  - TODO set environment constant
   DATA lCookiesSent       INIT .F.

   METHOD SetCookie()
   METHOD DeleteCookie()
   METHOD DeleteAllCookies()
   METHOD GetCookie()
   METHOD IsCookie( cCookieName )  INLINE ::GetCookie( cCookieName ) != NIL
   METHOD IsCookies()      INLINE !Empty( ::aaCookieToSet )
   METHOD SetCookieDefaults()

ENDCLASS

// ------------------------------ ***************************** -----------------------------------

METHOD SetCookieDefaults( cDomain, cPath, nExpireDays, nExpireSecs ) CLASS uhttpd_Cookie
   IF cDomain     <> NIL THEN ::cDomain     := cDomain
   IF cPath       <> NIL THEN ::cPath       := cPath
   IF nExpireDays <> NIL THEN ::nExpireDays := nExpireDays
   IF nExpireSecs <> NIL THEN ::nExpireSecs := nExpireSecs
   RETURN NIL

METHOD SetCookie( cCookieName, xValue, cDomain, cPath, cExpires, lSecure, lHttpOnly ) CLASS uhttpd_Cookie
   LOCAL cStr, nPos, nCookies

   DEFAULT cDomain      TO ::cDomain
   DEFAULT cPath        TO ::cPath
   DEFAULT cExpires     TO uhttpd_DateToGMT( Date(), Time(), ::nExpireDays, ::nExpireSecs )
   DEFAULT lHttpOnly    TO .F.

   ::lHttpOnly := lHttpOnly

   IF xValue != NIL
      // Search if a cookie already exists
                                        // case sensitive
      IF ( nPos := aScan( ::aCookies, {|e| e[ 1 ] == cCookieName } ) ) > 0
         ::aCookies[ nPos ][ 2 ] := uhttpd_UrlEncode( hb_cStr( xValue ) )
      ELSE
         aAdd( ::aCookies, { cCookieName, uhttpd_UrlEncode( hb_cStr( xValue ) ) } )
      ENDIF
   ELSE
      IF ( nPos := aScan( ::aCookies, {|e| e[ 1 ] == cCookieName } ) ) > 0
         hb_aDel( ::aCookies, nPos, .T. )
      ENDIF
   ENDIF

   // Rebuild cookie string as per RFC2616 (comma separated list)
   cStr     := ""
   nCookies := Len( ::aCookies )
   aEval( ::aCookies, {|e, i| cStr += e[ 1 ] + "=" + e[ 2 ] + IIF( i < nCookies, ",", "" ) } )

   //cStr := cCookieName + "=" + uhttpd_UrlEncode( hb_cStr( xValue ) )

   IF cDomain <> NIL
      cStr += "; domain=" + cDomain
   ENDIF
   IF cPath <> NIL
      cStr += "; path=" + cPath
   ENDIF
   IF cExpires <> NIL
      cStr += "; expires=" + cExpires
   ENDIF
   IF ValType( lSecure ) == "L" .AND. lSecure
       cStr += "; secure"
   ENDIF

   // Send the header
   //uhttpd_SetHeader( "Set-Cookie", cStr, .F. )
   uhttpd_SetHeader( "Set-Cookie", cStr )

   RETURN NIL

METHOD DeleteCookie( cCookieName, cDomain, cPath, lSecure ) CLASS uhttpd_Cookie
   LOCAL cExpires := uhttpd_DateToGMT( DATE() - 1 ) // Setting date in the past delete cookie

   ::SetCookie( cCookieName, "", cDomain, cPath, cExpires, lSecure )

   RETURN NIL

METHOD DeleteAllCookies( cDomain, cPath, lSecure ) CLASS uhttpd_Cookie
   LOCAL cCookieName

   FOR EACH cCookieName IN _COOKIE:Keys
       //::DeleteCookie( Substr( cCookieName, 2 ), cDomain, cPath, lSecure )
       ::DeleteCookie( cCookieName, cDomain, cPath, lSecure )
   NEXT

   RETURN NIL

METHOD GetCookie( cCookieName ) CLASS uhttpd_Cookie
   LOCAL cHeader, cRet
   LOCAL nPos := 1
   DO WHILE .T.
       IF ( cHeader := uhttpd_GetHeader( "Set-Cookie", @nPos ) ) != NIL
          IF cHeader == cCookieName
             cRet := cHeader
             EXIT
          ELSE
             nPos++
          ENDIF
       ELSE
          EXIT
       ENDIF
   ENDDO
   RETURN cRet