# PalmKnihy
V katalogu alephu jsou eknihy zakomponovány  pomocí pole NUM a 856 jako odkaz na evýpůjčku v záznamu a k  nim přiřazených jednotek se spec. statusem pro eknihy. 
 
Postup:
-	stáhneme z Palmknih data XML, která pomocí xsl převedeme na aleph sekvenční soubor pro import.
-	Podle ISBN-EAN najdeme v katalogu záznamy, ke kterým připojíme pole NUM, (příp. záznamy stáhneme z jiných knihoven, příp. dáme import ze stažených dat)
-	Z obsahu pole NUM se vygenerují jednotky (pro OPAC skryté)
-	Fixem se vygeneruje pole 85640 – odkaz na vypůjčení eknihy = odkaz na šablonu pro vypůjčení příslušné jednotky
-	Výpůjčka: pro čtenáře se vygeneruje virtuální jednotka, kterou dostane na konto na 31 dní. (aby si jednu knihu mohlo vypůjčit více čtenářů, každému z nich se vygeneruje jeho jednotka). 
-	Pošle se požadavek na Palmknihy na výpůjčku – email čtenáře(=jeho konto u Palmknih) a ID titulu, vrací se kód s příp. chybou.
-	Výpůjčky v aplikaci Palmknihy si řídí Palmknihy samy – to je mimo nás, stejně tak odstranění titulu po konci výpůjčky v aplikaci Palmknih.
-	Prošlé evýpůjčky z konta čtenáře v alephu vymaže každodenní job.
-	Rozdíl mezi eknihou a audioknihou není pro nás prakticky žádný, k oběma přistupujeme úplně stejně – pouze formát záznamu je BK nebo AM.

Základní nastavení
Pro eknihy máme nastavenu dílčí knihovnu EBOOK, sbírku EREAD, jednotky mají svůj status (75) a procesní status (EB)

tab_sub_library.lng  nastavena dílčí knihovna pro e-knihy(vč. audioknih) 
EBOOK 1 MVK50 L E-knihy                        15A   16A   EBOOK MVK50
Založena kvůli výpůjčním lhůtám a uzavření knihovny. Pro eknihy NELZE brát v úvahu uzavření knihovny dle tab17, vrací se po 31 dnech automaticky poskytovanou službou na straně Palmknihy (pův. Ereading).

Tab15.lng (item statuses)
15A   ## EB L Palmknihy/Flexibooks půjčená   Y N N N N N N N N    N
15A   75 ## L E-kniha k vypůjčení            Y N T N N N N N N    N
tab37 (hold request pickup list) - musi se nastavit, jinak aleph nedovoli pozadavek
EBOOK ## ## ## # MSVK
tab40.lng (sbirky) 
 EREAD EBOOK L E-knihy eReading
