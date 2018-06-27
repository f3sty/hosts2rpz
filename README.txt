hosts2rpz.pl - script for converting a generic hosts file into an rpz zone db.

If you're using a service like dns4me for "geographic flexibility" but don't really want to pass all your DNS requests through them,
this script will take the output of their hosts file generator API and construct an rpz zone file, allowing the hosts on your network
to all be geographically liberated without having to update a stack of hosts files every few days.
It also gets around the problem of devices not having easily-modified hosts files.

Of course its also useful for more than just geoblocking services - it can also form the basis of a network-wide adblocker. 
i.e. 
 $ wget -O /tmp/hosts https://raw.githubusercontent.com/StevenBlack/hosts/master/data/yoyo.org/hosts 
 $ hosts2rpz.pl --in /tmp/hosts --out /etc/bind/rpz-adblock.db

