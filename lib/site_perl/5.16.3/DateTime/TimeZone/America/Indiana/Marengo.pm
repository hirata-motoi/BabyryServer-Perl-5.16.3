# This file is auto-generated by the Perl DateTime Suite time zone
# code generator (0.07) This code generator comes with the
# DateTime::TimeZone module distribution in the tools/ directory

#
# Generated from /tmp/Qd5wmh7n8P/northamerica.  Olson data version 2014a
#
# Do not edit this file directly.
#
package DateTime::TimeZone::America::Indiana::Marengo;
$DateTime::TimeZone::America::Indiana::Marengo::VERSION = '1.65';
use strict;

use Class::Singleton 1.03;
use DateTime::TimeZone;
use DateTime::TimeZone::OlsonDB;

@DateTime::TimeZone::America::Indiana::Marengo::ISA = ( 'Class::Singleton', 'DateTime::TimeZone' );

my $spans =
[
    [
DateTime::TimeZone::NEG_INFINITY, #    utc_start
59418036000, #      utc_end 1883-11-18 18:00:00 (Sun)
DateTime::TimeZone::NEG_INFINITY, #  local_start
59418015277, #    local_end 1883-11-18 12:14:37 (Sun)
-20723,
0,
'LMT',
    ],
    [
59418036000, #    utc_start 1883-11-18 18:00:00 (Sun)
60502406400, #      utc_end 1918-03-31 08:00:00 (Sun)
59418014400, #  local_start 1883-11-18 12:00:00 (Sun)
60502384800, #    local_end 1918-03-31 02:00:00 (Sun)
-21600,
0,
'CST',
    ],
    [
60502406400, #    utc_start 1918-03-31 08:00:00 (Sun)
60520546800, #      utc_end 1918-10-27 07:00:00 (Sun)
60502388400, #  local_start 1918-03-31 03:00:00 (Sun)
60520528800, #    local_end 1918-10-27 02:00:00 (Sun)
-18000,
1,
'CDT',
    ],
    [
60520546800, #    utc_start 1918-10-27 07:00:00 (Sun)
60533856000, #      utc_end 1919-03-30 08:00:00 (Sun)
60520525200, #  local_start 1918-10-27 01:00:00 (Sun)
60533834400, #    local_end 1919-03-30 02:00:00 (Sun)
-21600,
0,
'CST',
    ],
    [
60533856000, #    utc_start 1919-03-30 08:00:00 (Sun)
60551996400, #      utc_end 1919-10-26 07:00:00 (Sun)
60533838000, #  local_start 1919-03-30 03:00:00 (Sun)
60551978400, #    local_end 1919-10-26 02:00:00 (Sun)
-18000,
1,
'CDT',
    ],
    [
60551996400, #    utc_start 1919-10-26 07:00:00 (Sun)
61255468800, #      utc_end 1942-02-09 08:00:00 (Mon)
60551974800, #  local_start 1919-10-26 01:00:00 (Sun)
61255447200, #    local_end 1942-02-09 02:00:00 (Mon)
-21600,
0,
'CST',
    ],
    [
61255468800, #    utc_start 1942-02-09 08:00:00 (Mon)
61366287600, #      utc_end 1945-08-14 23:00:00 (Tue)
61255450800, #  local_start 1942-02-09 03:00:00 (Mon)
61366269600, #    local_end 1945-08-14 18:00:00 (Tue)
-18000,
1,
'CWT',
    ],
    [
61366287600, #    utc_start 1945-08-14 23:00:00 (Tue)
61370290800, #      utc_end 1945-09-30 07:00:00 (Sun)
61366269600, #  local_start 1945-08-14 18:00:00 (Tue)
61370272800, #    local_end 1945-09-30 02:00:00 (Sun)
-18000,
1,
'CPT',
    ],
    [
61370290800, #    utc_start 1945-09-30 07:00:00 (Sun)
61536088800, #      utc_end 1951-01-01 06:00:00 (Mon)
61370269200, #  local_start 1945-09-30 01:00:00 (Sun)
61536067200, #    local_end 1951-01-01 00:00:00 (Mon)
-21600,
0,
'CST',
    ],
    [
61536088800, #    utc_start 1951-01-01 06:00:00 (Mon)
61546291200, #      utc_end 1951-04-29 08:00:00 (Sun)
61536067200, #  local_start 1951-01-01 00:00:00 (Mon)
61546269600, #    local_end 1951-04-29 02:00:00 (Sun)
-21600,
0,
'CST',
    ],
    [
61546291200, #    utc_start 1951-04-29 08:00:00 (Sun)
61559593200, #      utc_end 1951-09-30 07:00:00 (Sun)
61546273200, #  local_start 1951-04-29 03:00:00 (Sun)
61559575200, #    local_end 1951-09-30 02:00:00 (Sun)
-18000,
1,
'CDT',
    ],
    [
61559593200, #    utc_start 1951-09-30 07:00:00 (Sun)
61640640000, #      utc_end 1954-04-25 08:00:00 (Sun)
61559571600, #  local_start 1951-09-30 01:00:00 (Sun)
61640618400, #    local_end 1954-04-25 02:00:00 (Sun)
-21600,
0,
'CST',
    ],
    [
61640640000, #    utc_start 1954-04-25 08:00:00 (Sun)
61653942000, #      utc_end 1954-09-26 07:00:00 (Sun)
61640622000, #  local_start 1954-04-25 03:00:00 (Sun)
61653924000, #    local_end 1954-09-26 02:00:00 (Sun)
-18000,
1,
'CDT',
    ],
    [
61653942000, #    utc_start 1954-09-26 07:00:00 (Sun)
61672089600, #      utc_end 1955-04-24 08:00:00 (Sun)
61653920400, #  local_start 1954-09-26 01:00:00 (Sun)
61672068000, #    local_end 1955-04-24 02:00:00 (Sun)
-21600,
0,
'CST',
    ],
    [
61672089600, #    utc_start 1955-04-24 08:00:00 (Sun)
61685391600, #      utc_end 1955-09-25 07:00:00 (Sun)
61672071600, #  local_start 1955-04-24 03:00:00 (Sun)
61685373600, #    local_end 1955-09-25 02:00:00 (Sun)
-18000,
1,
'CDT',
    ],
    [
61685391600, #    utc_start 1955-09-25 07:00:00 (Sun)
61704144000, #      utc_end 1956-04-29 08:00:00 (Sun)
61685370000, #  local_start 1955-09-25 01:00:00 (Sun)
61704122400, #    local_end 1956-04-29 02:00:00 (Sun)
-21600,
0,
'CST',
    ],
    [
61704144000, #    utc_start 1956-04-29 08:00:00 (Sun)
61717446000, #      utc_end 1956-09-30 07:00:00 (Sun)
61704126000, #  local_start 1956-04-29 03:00:00 (Sun)
61717428000, #    local_end 1956-09-30 02:00:00 (Sun)
-18000,
1,
'CDT',
    ],
    [
61717446000, #    utc_start 1956-09-30 07:00:00 (Sun)
61735593600, #      utc_end 1957-04-28 08:00:00 (Sun)
61717424400, #  local_start 1956-09-30 01:00:00 (Sun)
61735572000, #    local_end 1957-04-28 02:00:00 (Sun)
-21600,
0,
'CST',
    ],
    [
61735593600, #    utc_start 1957-04-28 08:00:00 (Sun)
61748895600, #      utc_end 1957-09-29 07:00:00 (Sun)
61735575600, #  local_start 1957-04-28 03:00:00 (Sun)
61748877600, #    local_end 1957-09-29 02:00:00 (Sun)
-18000,
1,
'CDT',
    ],
    [
61748895600, #    utc_start 1957-09-29 07:00:00 (Sun)
61767043200, #      utc_end 1958-04-27 08:00:00 (Sun)
61748874000, #  local_start 1957-09-29 01:00:00 (Sun)
61767021600, #    local_end 1958-04-27 02:00:00 (Sun)
-21600,
0,
'CST',
    ],
    [
61767043200, #    utc_start 1958-04-27 08:00:00 (Sun)
61780345200, #      utc_end 1958-09-28 07:00:00 (Sun)
61767025200, #  local_start 1958-04-27 03:00:00 (Sun)
61780327200, #    local_end 1958-09-28 02:00:00 (Sun)
-18000,
1,
'CDT',
    ],
    [
61780345200, #    utc_start 1958-09-28 07:00:00 (Sun)
61798492800, #      utc_end 1959-04-26 08:00:00 (Sun)
61780323600, #  local_start 1958-09-28 01:00:00 (Sun)
61798471200, #    local_end 1959-04-26 02:00:00 (Sun)
-21600,
0,
'CST',
    ],
    [
61798492800, #    utc_start 1959-04-26 08:00:00 (Sun)
61811794800, #      utc_end 1959-09-27 07:00:00 (Sun)
61798474800, #  local_start 1959-04-26 03:00:00 (Sun)
61811776800, #    local_end 1959-09-27 02:00:00 (Sun)
-18000,
1,
'CDT',
    ],
    [
61811794800, #    utc_start 1959-09-27 07:00:00 (Sun)
61829942400, #      utc_end 1960-04-24 08:00:00 (Sun)
61811773200, #  local_start 1959-09-27 01:00:00 (Sun)
61829920800, #    local_end 1960-04-24 02:00:00 (Sun)
-21600,
0,
'CST',
    ],
    [
61829942400, #    utc_start 1960-04-24 08:00:00 (Sun)
61843244400, #      utc_end 1960-09-25 07:00:00 (Sun)
61829924400, #  local_start 1960-04-24 03:00:00 (Sun)
61843226400, #    local_end 1960-09-25 02:00:00 (Sun)
-18000,
1,
'CDT',
    ],
    [
61843244400, #    utc_start 1960-09-25 07:00:00 (Sun)
61861996800, #      utc_end 1961-04-30 08:00:00 (Sun)
61843222800, #  local_start 1960-09-25 01:00:00 (Sun)
61861975200, #    local_end 1961-04-30 02:00:00 (Sun)
-21600,
0,
'CST',
    ],
    [
61861996800, #    utc_start 1961-04-30 08:00:00 (Sun)
62104165200, #      utc_end 1969-01-01 05:00:00 (Wed)
61861978800, #  local_start 1961-04-30 03:00:00 (Sun)
62104147200, #    local_end 1969-01-01 00:00:00 (Wed)
-18000,
0,
'EST',
    ],
    [
62104165200, #    utc_start 1969-01-01 05:00:00 (Wed)
62114194800, #      utc_end 1969-04-27 07:00:00 (Sun)
62104147200, #  local_start 1969-01-01 00:00:00 (Wed)
62114176800, #    local_end 1969-04-27 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
62114194800, #    utc_start 1969-04-27 07:00:00 (Sun)
62129916000, #      utc_end 1969-10-26 06:00:00 (Sun)
62114180400, #  local_start 1969-04-27 03:00:00 (Sun)
62129901600, #    local_end 1969-10-26 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
62129916000, #    utc_start 1969-10-26 06:00:00 (Sun)
62145644400, #      utc_end 1970-04-26 07:00:00 (Sun)
62129898000, #  local_start 1969-10-26 01:00:00 (Sun)
62145626400, #    local_end 1970-04-26 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
62145644400, #    utc_start 1970-04-26 07:00:00 (Sun)
62161365600, #      utc_end 1970-10-25 06:00:00 (Sun)
62145630000, #  local_start 1970-04-26 03:00:00 (Sun)
62161351200, #    local_end 1970-10-25 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
62161365600, #    utc_start 1970-10-25 06:00:00 (Sun)
62177094000, #      utc_end 1971-04-25 07:00:00 (Sun)
62161347600, #  local_start 1970-10-25 01:00:00 (Sun)
62177076000, #    local_end 1971-04-25 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
62177094000, #    utc_start 1971-04-25 07:00:00 (Sun)
62193420000, #      utc_end 1971-10-31 06:00:00 (Sun)
62177079600, #  local_start 1971-04-25 03:00:00 (Sun)
62193405600, #    local_end 1971-10-31 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
62193420000, #    utc_start 1971-10-31 06:00:00 (Sun)
62209148400, #      utc_end 1972-04-30 07:00:00 (Sun)
62193402000, #  local_start 1971-10-31 01:00:00 (Sun)
62209130400, #    local_end 1972-04-30 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
62209148400, #    utc_start 1972-04-30 07:00:00 (Sun)
62224869600, #      utc_end 1972-10-29 06:00:00 (Sun)
62209134000, #  local_start 1972-04-30 03:00:00 (Sun)
62224855200, #    local_end 1972-10-29 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
62224869600, #    utc_start 1972-10-29 06:00:00 (Sun)
62240598000, #      utc_end 1973-04-29 07:00:00 (Sun)
62224851600, #  local_start 1972-10-29 01:00:00 (Sun)
62240580000, #    local_end 1973-04-29 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
62240598000, #    utc_start 1973-04-29 07:00:00 (Sun)
62256319200, #      utc_end 1973-10-28 06:00:00 (Sun)
62240583600, #  local_start 1973-04-29 03:00:00 (Sun)
62256304800, #    local_end 1973-10-28 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
62256319200, #    utc_start 1973-10-28 06:00:00 (Sun)
62262370800, #      utc_end 1974-01-06 07:00:00 (Sun)
62256301200, #  local_start 1973-10-28 01:00:00 (Sun)
62262352800, #    local_end 1974-01-06 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
62262370800, #    utc_start 1974-01-06 07:00:00 (Sun)
62287772400, #      utc_end 1974-10-27 07:00:00 (Sun)
62262352800, #  local_start 1974-01-06 02:00:00 (Sun)
62287754400, #    local_end 1974-10-27 02:00:00 (Sun)
-18000,
1,
'CDT',
    ],
    [
62287772400, #    utc_start 1974-10-27 07:00:00 (Sun)
62298054000, #      utc_end 1975-02-23 07:00:00 (Sun)
62287754400, #  local_start 1974-10-27 02:00:00 (Sun)
62298036000, #    local_end 1975-02-23 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
62298054000, #    utc_start 1975-02-23 07:00:00 (Sun)
62319218400, #      utc_end 1975-10-26 06:00:00 (Sun)
62298039600, #  local_start 1975-02-23 03:00:00 (Sun)
62319204000, #    local_end 1975-10-26 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
62319218400, #    utc_start 1975-10-26 06:00:00 (Sun)
62325003600, #      utc_end 1976-01-01 05:00:00 (Thu)
62319200400, #  local_start 1975-10-26 01:00:00 (Sun)
62324985600, #    local_end 1976-01-01 00:00:00 (Thu)
-18000,
0,
'EST',
    ],
    [
62325003600, #    utc_start 1976-01-01 05:00:00 (Thu)
63271774800, #      utc_end 2006-01-01 05:00:00 (Sun)
62324985600, #  local_start 1976-01-01 00:00:00 (Thu)
63271756800, #    local_end 2006-01-01 00:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63271774800, #    utc_start 2006-01-01 05:00:00 (Sun)
63279644400, #      utc_end 2006-04-02 07:00:00 (Sun)
63271756800, #  local_start 2006-01-01 00:00:00 (Sun)
63279626400, #    local_end 2006-04-02 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63279644400, #    utc_start 2006-04-02 07:00:00 (Sun)
63297784800, #      utc_end 2006-10-29 06:00:00 (Sun)
63279630000, #  local_start 2006-04-02 03:00:00 (Sun)
63297770400, #    local_end 2006-10-29 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
63297784800, #    utc_start 2006-10-29 06:00:00 (Sun)
63309279600, #      utc_end 2007-03-11 07:00:00 (Sun)
63297766800, #  local_start 2006-10-29 01:00:00 (Sun)
63309261600, #    local_end 2007-03-11 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63309279600, #    utc_start 2007-03-11 07:00:00 (Sun)
63329839200, #      utc_end 2007-11-04 06:00:00 (Sun)
63309265200, #  local_start 2007-03-11 03:00:00 (Sun)
63329824800, #    local_end 2007-11-04 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
63329839200, #    utc_start 2007-11-04 06:00:00 (Sun)
63340729200, #      utc_end 2008-03-09 07:00:00 (Sun)
63329821200, #  local_start 2007-11-04 01:00:00 (Sun)
63340711200, #    local_end 2008-03-09 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63340729200, #    utc_start 2008-03-09 07:00:00 (Sun)
63361288800, #      utc_end 2008-11-02 06:00:00 (Sun)
63340714800, #  local_start 2008-03-09 03:00:00 (Sun)
63361274400, #    local_end 2008-11-02 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
63361288800, #    utc_start 2008-11-02 06:00:00 (Sun)
63372178800, #      utc_end 2009-03-08 07:00:00 (Sun)
63361270800, #  local_start 2008-11-02 01:00:00 (Sun)
63372160800, #    local_end 2009-03-08 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63372178800, #    utc_start 2009-03-08 07:00:00 (Sun)
63392738400, #      utc_end 2009-11-01 06:00:00 (Sun)
63372164400, #  local_start 2009-03-08 03:00:00 (Sun)
63392724000, #    local_end 2009-11-01 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
63392738400, #    utc_start 2009-11-01 06:00:00 (Sun)
63404233200, #      utc_end 2010-03-14 07:00:00 (Sun)
63392720400, #  local_start 2009-11-01 01:00:00 (Sun)
63404215200, #    local_end 2010-03-14 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63404233200, #    utc_start 2010-03-14 07:00:00 (Sun)
63424792800, #      utc_end 2010-11-07 06:00:00 (Sun)
63404218800, #  local_start 2010-03-14 03:00:00 (Sun)
63424778400, #    local_end 2010-11-07 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
63424792800, #    utc_start 2010-11-07 06:00:00 (Sun)
63435682800, #      utc_end 2011-03-13 07:00:00 (Sun)
63424774800, #  local_start 2010-11-07 01:00:00 (Sun)
63435664800, #    local_end 2011-03-13 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63435682800, #    utc_start 2011-03-13 07:00:00 (Sun)
63456242400, #      utc_end 2011-11-06 06:00:00 (Sun)
63435668400, #  local_start 2011-03-13 03:00:00 (Sun)
63456228000, #    local_end 2011-11-06 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
63456242400, #    utc_start 2011-11-06 06:00:00 (Sun)
63467132400, #      utc_end 2012-03-11 07:00:00 (Sun)
63456224400, #  local_start 2011-11-06 01:00:00 (Sun)
63467114400, #    local_end 2012-03-11 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63467132400, #    utc_start 2012-03-11 07:00:00 (Sun)
63487692000, #      utc_end 2012-11-04 06:00:00 (Sun)
63467118000, #  local_start 2012-03-11 03:00:00 (Sun)
63487677600, #    local_end 2012-11-04 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
63487692000, #    utc_start 2012-11-04 06:00:00 (Sun)
63498582000, #      utc_end 2013-03-10 07:00:00 (Sun)
63487674000, #  local_start 2012-11-04 01:00:00 (Sun)
63498564000, #    local_end 2013-03-10 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63498582000, #    utc_start 2013-03-10 07:00:00 (Sun)
63519141600, #      utc_end 2013-11-03 06:00:00 (Sun)
63498567600, #  local_start 2013-03-10 03:00:00 (Sun)
63519127200, #    local_end 2013-11-03 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
63519141600, #    utc_start 2013-11-03 06:00:00 (Sun)
63530031600, #      utc_end 2014-03-09 07:00:00 (Sun)
63519123600, #  local_start 2013-11-03 01:00:00 (Sun)
63530013600, #    local_end 2014-03-09 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63530031600, #    utc_start 2014-03-09 07:00:00 (Sun)
63550591200, #      utc_end 2014-11-02 06:00:00 (Sun)
63530017200, #  local_start 2014-03-09 03:00:00 (Sun)
63550576800, #    local_end 2014-11-02 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
63550591200, #    utc_start 2014-11-02 06:00:00 (Sun)
63561481200, #      utc_end 2015-03-08 07:00:00 (Sun)
63550573200, #  local_start 2014-11-02 01:00:00 (Sun)
63561463200, #    local_end 2015-03-08 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63561481200, #    utc_start 2015-03-08 07:00:00 (Sun)
63582040800, #      utc_end 2015-11-01 06:00:00 (Sun)
63561466800, #  local_start 2015-03-08 03:00:00 (Sun)
63582026400, #    local_end 2015-11-01 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
63582040800, #    utc_start 2015-11-01 06:00:00 (Sun)
63593535600, #      utc_end 2016-03-13 07:00:00 (Sun)
63582022800, #  local_start 2015-11-01 01:00:00 (Sun)
63593517600, #    local_end 2016-03-13 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63593535600, #    utc_start 2016-03-13 07:00:00 (Sun)
63614095200, #      utc_end 2016-11-06 06:00:00 (Sun)
63593521200, #  local_start 2016-03-13 03:00:00 (Sun)
63614080800, #    local_end 2016-11-06 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
63614095200, #    utc_start 2016-11-06 06:00:00 (Sun)
63624985200, #      utc_end 2017-03-12 07:00:00 (Sun)
63614077200, #  local_start 2016-11-06 01:00:00 (Sun)
63624967200, #    local_end 2017-03-12 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63624985200, #    utc_start 2017-03-12 07:00:00 (Sun)
63645544800, #      utc_end 2017-11-05 06:00:00 (Sun)
63624970800, #  local_start 2017-03-12 03:00:00 (Sun)
63645530400, #    local_end 2017-11-05 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
63645544800, #    utc_start 2017-11-05 06:00:00 (Sun)
63656434800, #      utc_end 2018-03-11 07:00:00 (Sun)
63645526800, #  local_start 2017-11-05 01:00:00 (Sun)
63656416800, #    local_end 2018-03-11 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63656434800, #    utc_start 2018-03-11 07:00:00 (Sun)
63676994400, #      utc_end 2018-11-04 06:00:00 (Sun)
63656420400, #  local_start 2018-03-11 03:00:00 (Sun)
63676980000, #    local_end 2018-11-04 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
63676994400, #    utc_start 2018-11-04 06:00:00 (Sun)
63687884400, #      utc_end 2019-03-10 07:00:00 (Sun)
63676976400, #  local_start 2018-11-04 01:00:00 (Sun)
63687866400, #    local_end 2019-03-10 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63687884400, #    utc_start 2019-03-10 07:00:00 (Sun)
63708444000, #      utc_end 2019-11-03 06:00:00 (Sun)
63687870000, #  local_start 2019-03-10 03:00:00 (Sun)
63708429600, #    local_end 2019-11-03 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
63708444000, #    utc_start 2019-11-03 06:00:00 (Sun)
63719334000, #      utc_end 2020-03-08 07:00:00 (Sun)
63708426000, #  local_start 2019-11-03 01:00:00 (Sun)
63719316000, #    local_end 2020-03-08 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63719334000, #    utc_start 2020-03-08 07:00:00 (Sun)
63739893600, #      utc_end 2020-11-01 06:00:00 (Sun)
63719319600, #  local_start 2020-03-08 03:00:00 (Sun)
63739879200, #    local_end 2020-11-01 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
63739893600, #    utc_start 2020-11-01 06:00:00 (Sun)
63751388400, #      utc_end 2021-03-14 07:00:00 (Sun)
63739875600, #  local_start 2020-11-01 01:00:00 (Sun)
63751370400, #    local_end 2021-03-14 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63751388400, #    utc_start 2021-03-14 07:00:00 (Sun)
63771948000, #      utc_end 2021-11-07 06:00:00 (Sun)
63751374000, #  local_start 2021-03-14 03:00:00 (Sun)
63771933600, #    local_end 2021-11-07 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
63771948000, #    utc_start 2021-11-07 06:00:00 (Sun)
63782838000, #      utc_end 2022-03-13 07:00:00 (Sun)
63771930000, #  local_start 2021-11-07 01:00:00 (Sun)
63782820000, #    local_end 2022-03-13 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63782838000, #    utc_start 2022-03-13 07:00:00 (Sun)
63803397600, #      utc_end 2022-11-06 06:00:00 (Sun)
63782823600, #  local_start 2022-03-13 03:00:00 (Sun)
63803383200, #    local_end 2022-11-06 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
63803397600, #    utc_start 2022-11-06 06:00:00 (Sun)
63814287600, #      utc_end 2023-03-12 07:00:00 (Sun)
63803379600, #  local_start 2022-11-06 01:00:00 (Sun)
63814269600, #    local_end 2023-03-12 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63814287600, #    utc_start 2023-03-12 07:00:00 (Sun)
63834847200, #      utc_end 2023-11-05 06:00:00 (Sun)
63814273200, #  local_start 2023-03-12 03:00:00 (Sun)
63834832800, #    local_end 2023-11-05 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
63834847200, #    utc_start 2023-11-05 06:00:00 (Sun)
63845737200, #      utc_end 2024-03-10 07:00:00 (Sun)
63834829200, #  local_start 2023-11-05 01:00:00 (Sun)
63845719200, #    local_end 2024-03-10 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63845737200, #    utc_start 2024-03-10 07:00:00 (Sun)
63866296800, #      utc_end 2024-11-03 06:00:00 (Sun)
63845722800, #  local_start 2024-03-10 03:00:00 (Sun)
63866282400, #    local_end 2024-11-03 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
    [
63866296800, #    utc_start 2024-11-03 06:00:00 (Sun)
63877186800, #      utc_end 2025-03-09 07:00:00 (Sun)
63866278800, #  local_start 2024-11-03 01:00:00 (Sun)
63877168800, #    local_end 2025-03-09 02:00:00 (Sun)
-18000,
0,
'EST',
    ],
    [
63877186800, #    utc_start 2025-03-09 07:00:00 (Sun)
63897746400, #      utc_end 2025-11-02 06:00:00 (Sun)
63877172400, #  local_start 2025-03-09 03:00:00 (Sun)
63897732000, #    local_end 2025-11-02 02:00:00 (Sun)
-14400,
1,
'EDT',
    ],
];

sub olson_version { '2014a' }

sub has_dst_changes { 39 }

sub _max_year { 2024 }

sub _new_instance
{
    return shift->_init( @_, spans => $spans );
}

sub _last_offset { -18000 }

my $last_observance = bless( {
  'format' => 'E%sT',
  'gmtoff' => '-5:00',
  'local_start_datetime' => bless( {
    'formatter' => undef,
    'local_rd_days' => 732312,
    'local_rd_secs' => 0,
    'offset_modifier' => 0,
    'rd_nanosecs' => 0,
    'tz' => bless( {
      'name' => 'floating',
      'offset' => 0
    }, 'DateTime::TimeZone::Floating' ),
    'utc_rd_days' => 732312,
    'utc_rd_secs' => 0,
    'utc_year' => 2007
  }, 'DateTime' ),
  'offset_from_std' => 0,
  'offset_from_utc' => -18000,
  'until' => [],
  'utc_start_datetime' => bless( {
    'formatter' => undef,
    'local_rd_days' => 732312,
    'local_rd_secs' => 18000,
    'offset_modifier' => 0,
    'rd_nanosecs' => 0,
    'tz' => bless( {
      'name' => 'floating',
      'offset' => 0
    }, 'DateTime::TimeZone::Floating' ),
    'utc_rd_days' => 732312,
    'utc_rd_secs' => 18000,
    'utc_year' => 2007
  }, 'DateTime' )
}, 'DateTime::TimeZone::OlsonDB::Observance' )
;
sub _last_observance { $last_observance }

my $rules = [
  bless( {
    'at' => '2:00',
    'from' => '2007',
    'in' => 'Nov',
    'letter' => 'S',
    'name' => 'US',
    'offset_from_std' => 0,
    'on' => 'Sun>=1',
    'save' => '0',
    'to' => 'max',
    'type' => undef
  }, 'DateTime::TimeZone::OlsonDB::Rule' ),
  bless( {
    'at' => '2:00',
    'from' => '2007',
    'in' => 'Mar',
    'letter' => 'D',
    'name' => 'US',
    'offset_from_std' => 3600,
    'on' => 'Sun>=8',
    'save' => '1:00',
    'to' => 'max',
    'type' => undef
  }, 'DateTime::TimeZone::OlsonDB::Rule' )
]
;
sub _rules { $rules }


1;

