$TTL 3D

@       IN      SOA     ns1.paraccel.com. root.paraccel.com. (
                        2014081206      ; serial, todays date + todays serial #
                        8H              ; refresh, seconds
                        2H              ; retry, seconds
                        4W              ; expire, seconds
                        1D )            ; minimum, seconds
;
                TXT             "Paraccel Internal DNS Server for Cupertino"
        IN      NS              ns1.paraccel.com.
		NS	cam-ns1.paraccel.com.
		NS	sd-ns1.paraccel.com.


;ns1     IN      A               192.168.6.10
ns2     IN      A               192.168.159.12

; Network Services Equipments
core-fw		A	192.168.159.1
prt-hplj	A	192.168.159.3
wlan		A	192.168.159.7
core-sw1	A	192.168.159.9
loglogic-test   A       192.168.159.28
kamek           A       192.168.159.44
qa-ittest       A       192.168.159.50
fawful          A       192.168.159.12
wart            A       192.168.159.243

; Workstations
ws-kforte	A	192.168.159.31
qa-kforte	A	192.168.159.32
ws-bnarasimhan	A	192.168.159.36
ws-rcole	A	192.168.159.41
ws-brumsby	A	192.168.159.46
ws-sperfilov	A	192.168.159.51
ws-sperfilov2	A	192.168.159.52
ws-asinha	A	192.168.159.56
ws-joechen	A	192.168.159.69
;ws-sreiss	A	192.168.159.71
;qa-sreiss	A	192.168.159.72
;ws-cyang	A	192.168.159.76
;ws-jallen	A	192.168.159.81
ws-slstestbox	A	192.168.159.86
ws-rprakash	A	192.168.159.91
ws-jmoore	A	192.168.159.102
ws-dwilhite	A	192.168.159.104
ws-bdesantis	A	192.168.159.105
bdesantis-dev	A	192.168.159.234
ws-lcolby       A       192.168.159.177

; DHCP pool for laptops and phones
bscott-laptop		A	192.168.159.231
dsteinhoff-laptop	A	192.168.159.232
rcole-laptop		A       192.168.159.235
sperfilov-laptop	A       192.168.159.236
asinha-laptop		A       192.168.159.237
bnarasimhan-laptop	A       192.168.159.238
;sreiss-laptop		A       192.168.159.239
;rli-laptop		A       192.168.159.240
jchen-laptop		A	192.168.159.241
;cyang-laptop		A       192.168.159.242
brumsby-laptop		A       192.168.159.243
;mahiers-laptop		A       192.168.159.244
pcarr-laptop		A       192.168.159.245
kforte-laptop		A       192.168.159.246
;darnold-laptop		A       192.168.159.247
rprakash-laptop		A       192.168.159.248
;abadri-laptop		A       192.168.159.249
;jallen-laptop		A       192.168.159.250
;ashu-laptop		A       192.168.159.251
dhcp252                 A       192.168.159.252
dhcp253                 A       192.168.159.253
dhcp254		        A	192.168.159.254

; Cupertino Wireless Access Points Static IP Addresses
;AP001e.f7ee.8738	A	192.168.159.240
;AP001e.f7ee.87d8	A	192.168.159.247
;AP001e.f7ee.8aa2	A	192.168.158.239
;cup_wctr	        A	192.168.159.248

; Cupertino Wireless Access Points Static IP Addresses
;AP001e.f7ee.8738        A       192.168.159.240
APWIFICUP4              A       192.168.159.18
;AP001e.f7ee.87d8        A       192.168.159.247
APWIFICUP2              A       192.168.159.17
;AP001e.f7ee.8aa2        A       192.168.158.239
APWIFICUP3              A       192.168.159.16
;cup_wctr               A       192.168.159.248
