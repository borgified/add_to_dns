./add.pl 10.11.12.13 10.12.23.34 ...

does the following:

1. add corresponding PTR entry in
db.12.11.10
db.23.12.10

2. updates db.paraccel.com with new ip

3. run setserial on updated db.* files

4. run service bind9 reload
