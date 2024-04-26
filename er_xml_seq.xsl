<xsl:stylesheet version="1.0" xmlns:xsl="http://www.w3.org/1999/XSL/Transform">
  <xsl:output method="text"/>
  <!-- Definice parametrů s výchozími hodnotami -->
  <xsl:param name="maxPrice" select="50"/>
  <xsl:param name="allowedFormats" select="'ebook audiobook'"/>
  <xsl:param name="currentDate" select="'19000101'"/>
  
  <xsl:template match="/">
    <xsl:apply-templates select="//product[rents='true' and price &lt;= $maxPrice and contains(concat($allowedFormats, ' '), @type)]"/>
  </xsl:template>
  
  <xsl:template match="product[rents='true']">
    <!-- Pořadí záznamu formátované na 9 znaků -->
    <xsl:variable name="nr" select="format-number(position(), '000000000')" />
    
    <!-- FMT -->
    <!-- LDR -->
    <!-- 007 -->
    <xsl:choose>
      <xsl:when test="@type='ebook'">
        <xsl:value-of select="$nr" /><xsl:text> FMT   L BK&#10;</xsl:text>
        <xsl:value-of select="$nr" /><xsl:text> LDR   L 00000nam-a22-----7i-4500&#10;</xsl:text>
        <xsl:value-of select="$nr" /><xsl:text> 007   L cr-|n|||||||||&#10;</xsl:text>
      </xsl:when>
      <xsl:when test="@type='audiobook'">
        <xsl:value-of select="$nr" /><xsl:text> FMT   L AM&#10;</xsl:text>
        <xsl:value-of select="$nr" /><xsl:text> LDR   L 00000nmm-a22-----7i-4500&#10;</xsl:text>
        <xsl:value-of select="$nr" /><xsl:text> 007   L sz-uunnnnn|und&#10;</xsl:text>
      </xsl:when>
    </xsl:choose >
    <!-- 003 -->
    <xsl:value-of select="$nr" /><xsl:text> 003   L CZ-OsMVK&#10;</xsl:text>

    <!-- 008 -->
    <xsl:value-of select="$nr" /><xsl:text> 008   L 980122s</xsl:text>
	<xsl:value-of select="publisYear" /><xsl:text>----xx-|||||||||||||||||</xsl:text>
    <xsl:variable name="langValue" select="lang[1]" />
    <xsl:choose>
      <xsl:when test="$langValue = 'en'">
        <xsl:text>ang-d&#10;</xsl:text>
      </xsl:when>
      <xsl:when test="$langValue = 'sk'">
        <xsl:text>slo-d&#10;</xsl:text>
      </xsl:when>
      <xsl:when test="$langValue = 'cs'">
        <xsl:text>cze-d&#10;</xsl:text>
      </xsl:when>
      <xsl:otherwise>
        <xsl:text>|||-d&#10;</xsl:text>
      </xsl:otherwise>
    </xsl:choose>

    <!-- 020 -->
    <xsl:choose>
      <xsl:when test="@type='ebook'">
        <xsl:for-each select="format[(@type='pap' and isbn) or (@type='pdf' and isbn) or (@type='epub' and isbn)]">
          <xsl:choose>
            <xsl:when test="@type='pap' and isbn">
              <xsl:value-of select="$nr" /><xsl:text> 020   L $$a</xsl:text>
              <xsl:value-of select="isbn" /><xsl:text>$$q(print)&#10;</xsl:text>
            </xsl:when>
            <xsl:when test="(@type='pdf' and string-length(normalize-space(isbn)) > 0) or (@type='epub' and string-length(normalize-space(isbn)) > 0)">
              <xsl:value-of select="$nr" /><xsl:text> 020   L $$a</xsl:text>
              <xsl:value-of select="isbn" /><xsl:text>$$q(online ;$$q</xsl:text><xsl:value-of select="@type" /><xsl:text>)&#10;</xsl:text>
            </xsl:when>
          </xsl:choose>
        </xsl:for-each>
      </xsl:when>

    <!-- 024, 787 -->
      <xsl:when test="@type='audiobook'">
        <xsl:for-each select="format[@type='cd' and ean]">
          <xsl:value-of select="$nr" /><xsl:text> 0243  L </xsl:text>
          <xsl:text>$$a</xsl:text>
          <xsl:value-of select="ean" /><xsl:text>$$q(</xsl:text><xsl:value-of select="@type" /><xsl:text>)&#10;</xsl:text>
        </xsl:for-each>
        <xsl:for-each select="format[@type='mp3' and ean]">
          <xsl:value-of select="$nr" /><xsl:text> 0243  L </xsl:text>
          <xsl:text>$$a</xsl:text>
          <xsl:value-of select="ean" /><xsl:text>$$q(</xsl:text><xsl:value-of select="@type" /><xsl:text>)&#10;</xsl:text>
        </xsl:for-each>
        <xsl:for-each select="format[@type='pap' and isbn ]">
          <xsl:value-of select="$nr" /><xsl:text> 7870  L $$z</xsl:text>
          <xsl:value-of select="isbn" /><xsl:text>&#10;</xsl:text>
        </xsl:for-each>
      </xsl:when>
    </xsl:choose>

    <!-- 040 -->
    <xsl:value-of select="$nr" /><xsl:text> 040   L $$aPalmknihy$$bcze$$dOSA001$$erda&#10;</xsl:text>

    <!-- 100, 700 -->
	<!-- Počet autorů -->
    <xsl:variable name="authorCount" select="count(person[@role='author'])"/>
    <xsl:variable name="author">
      <xsl:choose>
        <xsl:when test="($authorCount &gt;= 1 and $authorCount &lt;= 5)">
          <xsl:text> 1001  L $$a</xsl:text>
        </xsl:when>
        <xsl:otherwise>
          <xsl:text> 7001  L $$a</xsl:text>
        </xsl:otherwise>
      </xsl:choose>
    </xsl:variable>

    <xsl:choose>
      <xsl:when test="person[@role='author'][1]">
        <xsl:value-of select="$nr" /><xsl:value-of select="$author" /><!--xsl:text> 1001  L $$a</xsl:text-->
        <xsl:value-of select="person[@role='author'][1]/keyNames" />
        <xsl:text>, </xsl:text>
        <xsl:value-of select="person[@role='author'][1]/names" />
        <xsl:text>$$4aut&#10;</xsl:text>
        <xsl:for-each select="person[@role='author'][position() > 1]">
          <xsl:value-of select="$nr" /><xsl:text> 7001  L </xsl:text>
          <xsl:text>$$a</xsl:text><xsl:value-of select="keyNames" /><xsl:text>, </xsl:text>
          <xsl:value-of select="names" /><xsl:text>$$4aut&#10;</xsl:text>
        </xsl:for-each>
      </xsl:when>
    </xsl:choose>
    <xsl:choose>
      <xsl:when test="person[@role!='author' and @role!='publisher']">
        <xsl:for-each select="person[@role!='author' and @role!='publisher']">
          <xsl:value-of select="$nr" /><xsl:text> 7001  L </xsl:text>
          <xsl:text>$$a</xsl:text><xsl:value-of select="keyNames" /><xsl:text>, </xsl:text>
          <xsl:value-of select="names" /><xsl:text>$$4</xsl:text>
		  <!--xsl:value-of select="@role" /-->
          <xsl:variable name="translatedRole">
            <xsl:call-template name="translateRole">
            <xsl:with-param name="role" select="@role"/>
           </xsl:call-template>
          </xsl:variable>
          <xsl:value-of select="$translatedRole" />
		  <xsl:text>&#10;</xsl:text>
        </xsl:for-each>
      </xsl:when>
    </xsl:choose>

    <!-- 240, 130 -->
    <xsl:if test="originalTitle">
      <xsl:choose>
       <xsl:when test="$author = ' 1001  L $$a'">
         <xsl:value-of select="$nr" /><xsl:text> 24010 L $$a</xsl:text>
         <xsl:value-of select="originalTitle" /><xsl:text>&#10;</xsl:text>
       </xsl:when>
       <xsl:otherwise>
         <xsl:value-of select="$nr" /><xsl:text> 1300  L $$a</xsl:text>
         <xsl:value-of select="originalTitle" /><xsl:text>&#10;</xsl:text>
       </xsl:otherwise>
      </xsl:choose>
    </xsl:if>

    <!-- 245 -->
    <xsl:value-of select="$nr" /><xsl:text> 24510 L </xsl:text>
    <xsl:text>$$a</xsl:text><xsl:value-of select="title"/>
    <xsl:if test="subtitle">
      <xsl:text> : $$b</xsl:text><xsl:value-of select="subtitle" />
    </xsl:if>
	<xsl:text>&#10;</xsl:text>
    <!-- 264 -->
    <xsl:value-of select="$nr" /><xsl:text> 264 1 L </xsl:text>
    <xsl:text>$$a[Místo vydání není známé] :$$b</xsl:text><xsl:value-of select="publisher"/>
    <xsl:text>,$$c</xsl:text><xsl:value-of select="publisYear"/><xsl:text>&#10;</xsl:text>
    <!-- 300 -->
    <xsl:value-of select="$nr" /><xsl:text> 300   L </xsl:text>
    <xsl:text>$$a1 online zdroj </xsl:text>
    <xsl:if test="pages">
      <xsl:text>(</xsl:text><xsl:value-of select="pages" /><xsl:text> stran)</xsl:text>
    </xsl:if>
	<xsl:text>&#10;</xsl:text>
    <!-- 336 -->
    <xsl:value-of select="$nr" /><xsl:text> 336   L </xsl:text>
    <xsl:choose>
      <xsl:when test="format[@type='pdf' or @type='epub']">
        <xsl:text>$$atext$$btxt$$2rdacontent&#10;</xsl:text>
      </xsl:when>
      <xsl:when test="format[@type='mp3' or @type='cd']">
        <xsl:text>$$amluvené slovo$$bspw$$2rdacontent&#10;</xsl:text>
      </xsl:when>
    </xsl:choose >
    <!-- 337 -->
    <xsl:value-of select="$nr" /><xsl:text> 337   L </xsl:text>
    <xsl:text>$$apočítač$$bc$$2rdamedia&#10;</xsl:text>
    <!-- 338 -->
    <xsl:value-of select="$nr" /><xsl:text> 338   L </xsl:text>
    <xsl:text>$$aonline zdroj$$2cr$$2rdacarrier&#10;</xsl:text>
    <!-- 490 -->
    <xsl:if test="series/title">
      <xsl:value-of select="$nr" /><xsl:text> 4901  L </xsl:text>
      <xsl:text>$$a</xsl:text><xsl:value-of select="series/title"/>
      <xsl:if test="series/part">
        <xsl:text> ;$$v</xsl:text><xsl:value-of select="series/part" />
      </xsl:if>
      <xsl:text>&#10;</xsl:text>
    </xsl:if>
    <!-- 520 -->
    <xsl:value-of select="$nr" /><xsl:text> 5202  L </xsl:text>
    <xsl:text>$$a</xsl:text>
	<!--xsl:value-of select="annotation"/><xsl:text>&#10;</xsl:text-->
    <xsl:variable name="cleanedText">
      <xsl:call-template name="removeTags">
        <xsl:with-param name="text" select="annotation"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:variable name="cleanedTextNonSpaces">
      <xsl:call-template name="removeNonBreakingSpaces">
        <xsl:with-param name="text" select="$cleanedText"/>
      </xsl:call-template>
    </xsl:variable>
    <xsl:value-of select="normalize-space($cleanedTextNonSpaces)"/><xsl:text>&#10;</xsl:text>
<!-- 653 -->
    <xsl:for-each select="subject[. != 'E-knihy' and . != 'Audioknihy']">
      <xsl:value-of select="$nr" /><xsl:text> 653   L $$a</xsl:text><xsl:value-of select="." /><xsl:text>&#10;</xsl:text>
    </xsl:for-each>
<!-- 655 -->
    <xsl:value-of select="$nr" /><xsl:text> 655 7 L </xsl:text>
	<xsl:if test="@type='ebook'">
      <xsl:text>$$aelektronické knihy$$7fd186907$$2czenas&#10;</xsl:text>
    </xsl:if>
	<xsl:if test="@type='audiobook'">
      <xsl:text>$$aaudioknihy$$7fd119452$$2czenas&#10;</xsl:text>
    </xsl:if>

<!-- IST -->
    <xsl:value-of select="$nr" /><xsl:text> IST   L $$aeread</xsl:text><xsl:value-of select="$currentDate"/><xsl:text>&#10;</xsl:text>
	
 <!-- NUM -->
    <xsl:value-of select="$nr" />
    <xsl:text> NUM   L </xsl:text>
    <xsl:text>$$k</xsl:text><xsl:value-of select="@id"/>
    <xsl:text>$$mEBOOK$$nBOOK$$o75$$qEREAD</xsl:text>
    <xsl:text>$$c</xsl:text><xsl:value-of select="shopURL"/>
    <xsl:choose>
      <xsl:when test="@type='ebook'">
        <xsl:if test="format[@type='epub']/sampleURL"><xsl:text>$$1</xsl:text><xsl:value-of select="format[@type='epub']/sampleURL"/></xsl:if>
        <xsl:if test="format[@type='pdf']/sampleURL"><xsl:text>$$2</xsl:text><xsl:value-of select="format[@type='pdf']/sampleURL"/></xsl:if>
      </xsl:when>
      <xsl:when test="@type='audiobook'">
        <xsl:if test="format[@type='mp3']/sampleURL"><xsl:text>$$1</xsl:text><xsl:value-of select="format[@type='mp3']/sampleURL"/></xsl:if>
      </xsl:when>
    </xsl:choose >
    <xsl:text>$$3</xsl:text><xsl:value-of select="translate(licenseEnd, '-', '')"/>
    <xsl:text>$$bEREAD</xsl:text><xsl:value-of select="@id"/>
    <xsl:text>$$d</xsl:text><xsl:value-of select="translate(substring(ancestor::export/@time, 1, 10), '-', '')"/>
 <!-- Nový řádek pro každý záznam -->
    <xsl:text>&#10;</xsl:text>
  </xsl:template>

<!-- Template pro odstranění HTML značek -->
<xsl:template name="removeTags">
  <xsl:param name="text"/>
  <xsl:choose>
    <xsl:when test="contains($text, '&lt;')">
      <xsl:value-of select="substring-before($text, '&lt;')"/>
      <xsl:call-template name="removeTags">
        <xsl:with-param name="text" select="substring-after($text, '&gt;')"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$text"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>
<!-- Template pro odstranění nezlomitelných mezer -->
<xsl:template name="removeNonBreakingSpaces">
  <xsl:param name="text"/>
  <xsl:choose>
    <xsl:when test="contains($text, '&amp;nbsp;')">
      <xsl:value-of select="substring-before($text, '&amp;nbsp;')"/>
      <xsl:text> </xsl:text>
      <xsl:call-template name="removeNonBreakingSpaces">
        <xsl:with-param name="text" select="substring-after($text, '&amp;nbsp;')"/>
      </xsl:call-template>
    </xsl:when>
    <xsl:otherwise>
      <xsl:value-of select="$text"/>
    </xsl:otherwise>
  </xsl:choose>
</xsl:template>
<!-- Parametrická šablona pro překlad role - v. 1.0 funkce nepodporuje  -->
<xsl:template name="translateRole">
  <xsl:param name="role"/>
  <xsl:choose>
    <xsl:when test="$role = 'author'">aut</xsl:when>
    <xsl:when test="$role = 'translator'">trl</xsl:when>
    <xsl:when test="$role = 'publisher'">pbl</xsl:when>
    <xsl:when test="$role = 'interpreter'">prf</xsl:when>
    <xsl:when test="$role = 'director'">drt</xsl:when>
    <xsl:when test="$role = 'illustrator'">ill</xsl:when>
    <xsl:when test="$role = 'editor'">edt</xsl:when>
    <xsl:when test="$role = 'music'">mus</xsl:when>
    <xsl:when test="$role = 'reader'">nrt</xsl:when>
    <xsl:otherwise>oth</xsl:otherwise>
  </xsl:choose>
</xsl:template>

</xsl:stylesheet>