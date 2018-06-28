hosts2rpz.pl - script for converting a generic hosts file into an rpz zone db.

If you're using a service like dns4me for "geographic flexibility" but don't
really want to pass all your DNS requests through them, this script will take the
output of their hosts file generator API and construct an rpz zone file,
allowing the hosts on your network to all be geographically liberated without
having to update a stack of hosts files every few days.
It also gets around the problem of devices not having easily-modified hosts files.

For use with dns4me.net, use your uuid (see their FAQ for how to find this).
This can be run from crontab by any user that has permission to 'rndc reload'
(it does not require root access, just the correct group membership)

 $ hosts2rpz.pl -u xxxxxxxx-xxxx-xxxx-xxxxxxxxxxxx


Of course its also useful for more than just geoblocking services - it can
also form the basis of a network-wide adblocker. 
i.e. 
 $ wget -O /tmp/hosts https://raw.githubusercontent.com/StevenBlack/hosts/master/data/yoyo.org/hosts 
 $ hosts2rpz.pl --in /tmp/hosts --out /etc/bind/rpz-adblock.db






Bind 9 Configuration
====================

Define the response policy and rpz zone in the appropriate place (debian - /etc/bind/named.conf.local, RedHat - /etc/named.conf), e.g:


  response-policy { zone "rpz"; };

  zone "rpz" IN {
      type master;
      file "/var/lib/bind/rpz.db";
      allow-query { none; };
      allow-transfer { none; };
    };

and reload bind. 

Enabling rpz logging can help with troubleshooting. In the logging section of your bind config (debian: /etc/bind/named.conf.options, RedHat: /etc/named.conf) add the following:

     channel rpzlog  {
       file "/var/log/bind/rpz.log" versions 3 size 10m;
       print-time yes;
       print-category  yes;
       print-severity  yes;
       severity        debug;
     };
     category rpz { rpzlog; };


RPZ can be used within views, just make sure the zone and response-policy are both defined within the same view.

