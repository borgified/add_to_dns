$TTL 3D

@       IN      SOA     ns1.paraccel.com. root.paraccel.com. (
                        2014081206      ; serial, todays date + todays serial #
                        8H              ; refresh, seconds
                        2H              ; retry, seconds
                        4W              ; expire, seconds
                        1D )            ; minimum, seconds

                TXT             "Internal ParAccel DNS for Anne Arbor"
                NS              ns1.paraccel.com.
		NS	cam-ns1.paraccel.com.
		NS	sd-ns1.paraccel.com.


;ns1             A               192.168.6.10
;ns2             A               192.168.159.11

;ts-tglc2e	A	192.168.158.24
;aasql		A	192.168.158.33
;xencom01	A	192.168.158.51
;aa-printer	A	192.168.158.253
