$TTL 3D

@       IN      SOA     ns1.paraccel.com. root.paraccel.com. (
                        2014081206      ; serial, todays date + todays serial #
                        8H              ; refresh, seconds
                        2H              ; retry, seconds
                        4W              ; expire, seconds
                        1D )            ; minimum, seconds
                TXT             "Paraccel Internal  DNS Server for San Diego"
        IN      NS              ns1.paraccel.com.
		NS	cam-ns1.paraccel.com.
		NS	sd-ns1.paraccel.com.


;ns1     IN      A               192.168.6.10
;ns2     IN      A               192.168.159.11

sd-printer      A               192.168.1.3
sd-printer2     A               192.168.1.6
wlan            A               192.168.1.99
wlan2           A               192.168.1.98
metroid         A               192.168.1.123
zelda           A               192.168.1.122

; Network equipment
fw1             A               192.168.1.4
core1           A               192.168.1.1
sw1             A               192.168.1.5
wireless        A               192.168.1.199
firefly         A               192.168.1.113
ldc-clstr-sw1	A		192.168.1.222
ldc-clstr-sw2	A		192.168.1.236
ldc-clstr-sw3	A		192.168.1.223
ldc-clstr-sw4	A		192.168.1.241
ldc-clstr-sw5	A		192.168.1.235
ldc-clstr-sw6	A		192.168.1.221


; Workstations
bchu-dev        A               192.168.1.11
teads-dev       A               192.168.1.12
bionicle-dev    A               192.168.1.13
tyler-dev       A               192.168.1.14
bzane-dev       A               192.168.1.15
bzane-icebox    A               192.168.1.89
thendrick-dev   A               192.168.1.16
xendev17        A               192.168.1.17
tdodd-dev       A               192.168.1.27
lkhosla-dev     A               192.168.1.28
kjain-dev       A               192.168.1.29
schrist-dev     A               192.168.1.32
qa-work3        A               192.168.1.112
qa-work4        A               192.168.1.106
qa-work5        A               192.168.1.173
wmuntz-dev      A               192.168.1.124
qa-work7        A               192.168.1.34
qa-work8        A               192.168.1.33
ws-wernicke     A               192.168.1.100
ws-adamb        A               192.168.1.39
ws-mario        A               192.168.1.102
vmware-solaris  A               192.168.1.19
ws-alex		A		192.168.1.128
ws-aschwartz    A               192.168.1.87
ws-aschwartz-1  A               192.168.1.129
ws-aschwartz-2  A               192.168.1.130
ws-bmckenna	A		192.168.1.162
ws-fedorchak    A               192.168.1.109
qa-fedorchak	A		192.168.1.110
sfedorchak-2k3  A               192.168.1.110
ws-swhitmore    A               192.168.1.133
ws-sbettadapura A               192.168.1.163
ws-mpeterson	A		192.168.1.137
ws-wdeng        A               192.168.1.138
ws-rglick       A               192.168.1.131
fester          A               192.168.1.127
suntest-1	A		192.168.1.108
amcnee-dev	A		192.168.1.125
trandell-dev	A		192.168.1.88
ws-bzane	A		192.168.1.18
