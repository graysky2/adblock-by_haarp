#!/bin/sh
## Clean, Lean and Mean Adblock by haarp
##
## Options:
## 'force': force updating sources,
## 'stop': disable Adblock, 'toggle': quickly toggle Adblock on and off
## 'restart': restart Adblock (e.g. for config changes)

## TODO: 'clean', 'status' options

alias elog='logger -t ADBLOCK -s'
alias iptables='/usr/sbin/iptables'

pidfile=/var/run/adblock.pid
kill -0 $(cat $pidfile 2>/dev/null) &>/dev/null && {
elog "Another instance found ($pidfile), exiting!"
exit 1
}
echo $$ > $pidfile

pexit() {
	elog "Exiting"
	rm $pidfile
	exit $@
}

stop() {
	elog "Stopping"
	rm "$CONF" &>/dev/null

	iptables -D INPUT -i "$BRIDGE" -p tcp -d "$redirip" --dport 80 -j ACCEPT &>/dev/null
	killall pixelserv &>/dev/null
	ifconfig "$BRIDGE":1 down &>/dev/null
	iptables -D INPUT -i "$BRIDGE" -p all -d "$redirip" -j DROP &>/dev/null

	elog "Done, restarting dnsmasq"
	service dnsmasq restart
}

grabsource() {
	local host=$(echo "$1" | awk -F"/" '{print $3}')
	local path=$(echo "$1" | awk -F"/" '{print substr($0, index($0,$4))}')
	local lastmod=$(echo -e "HEAD /$path HTTP/1.1\r\nHost: $host\r\n\r\n" | nc -w30 "$host" 80 | tr -d '\r' | grep "Last-Modified")

	local lmfile="$listprefix/lastmod-$(echo "$1" | md5sum | cut -c 1-8)"
	local sourcefile="$listprefix/source-$(echo "$1" | md5sum | cut -c 1-8)"

	[ "$force" != "1" -a -e "$sourcefile" -a -n "$lastmod" -a "$lastmod" == "$(cat "$lmfile" 2>/dev/null)" ] && {
	elog "Unchanged: $1 ($lastmod)"
	echo 2 >>"$listprefix/status"
	return 2
}

(
if wget "$1" -O -; then
	[ -n "$lastmod" ] && echo "$lastmod" > "$lmfile"
	echo 0 >>"$listprefix/status"
else
	elog "Failed: $1"
	echo 1 >>"$listprefix/status"
fi
) | tr -d "\r" | sed -e '/^[[:alnum:]:]/!d' | awk '{print $2}' | sed -e '/^localhost$/d' > "$sourcefile"
}

confgen() {
	elog "Generating $listprefix/blocklist"
	rm "$CONF" &>/dev/null

	if [ -e "$prefix/whitelist" ]; then
		sort -u "$listprefix"/source-* | grep -v -f "$prefix/whitelist" > "$listprefix/blocklist"
	else
		sort -u "$listprefix"/source-* > "$listprefix/blocklist"
	fi
	for w in $WHITELIST; do
		sed -i -e "/$w/d" "$listprefix/blocklist"
	done

	[ -e "$prefix/blacklist" ] && {
	cat "$prefix/blacklist" >> "$listprefix/blocklist"
}
for b in $BLACKLIST; do
	echo "$b" >> "$listprefix/blocklist"
done

sed -i -e '/^$/d' -e "s:^:address=/:" -e "s:$:/$redirip:" "$listprefix/blocklist"

elog "Config generated, $(wc -l < "$listprefix/blocklist") unique hosts to block"
}

prefix="$(cd "$(dirname "$0")" && pwd)"
[ -e "$prefix/config" ] || {
elog "$prefix/config not found!"
pexit 11
}

# ensure that config has the correct path
cd "$prefix" || exit

source "config"

if [ "$RAMLIST" == "1" ]; then
	listprefix="/var/lib/adblock"
	[ -d "$listprefix" ] || mkdir "$listprefix"
else
	listprefix="$prefix"
fi
if [ "$PIXEL_IP" == "0" ]; then
	redirip="0.0.0.0"
else
	[ -x "$prefix/pixelserv" ] || {
	elog "$prefix/pixelserv not found/executable!"
	pexit 10
}
redirip=$(ifconfig "$BRIDGE" | awk '/inet addr/{print $3}' | awk -F":" '{print $2}' | sed -e "s/255/$PIXEL_IP/")
fi


case "$1" in
	restart) stop;;
	stop)	stop; pexit 0;;
	toggle)	[ -e "$CONF" ] && { stop; pexit 0; };;
	force)	force="1";;
	"")	:;;
	*)	elog "'$1' not understood!"; pexit 1;;
esac


elog "Download starting"
until ping -q -c1 google.com >/dev/null; do
	elog "Waiting for connectivity..."
	sleep 30
done

trap 'elog "Signal received, cancelling"; rm "$listprefix"/source-* &>/dev/null; rm "$listprefix"/lastmod-* &>/dev/null; pexit 130' SIGQUIT SIGINT SIGTERM SIGHUP

echo -n "" >"$listprefix/status"
for s in $SOURCES; do
	grabsource "$s" &
done
wait

while read ret; do
	case "$ret" in
		0)	downloaded=1;;
		1)	failed=1;;
		2)	unchanged=1;;
	esac
done < "$listprefix/status"
rm "$listprefix/status"

trap - SIGQUIT SIGINT SIGTERM SIGHUP

if [ "$downloaded" == "1" ]; then
	elog "Downloaded"
	confgen
elif [ "$unchanged" == "1" ]; then
	elog "Filters unchanged"
	if [ ! -e "$listprefix/blocklist" ]; then
		confgen
	elif [ ! -e "$CONF" ]; then #needlink
		:
	else pexit 2
	fi
else
	elog "Download failed"
	if [ -e "$listprefix/blocklist" -a ! -e "$CONF" ]; then #needlink
		:
	else pexit 3
	fi
fi

echo "conf-file=$listprefix/blocklist" > "$CONF"

if [ "$PIXEL_IP" != "0" ]; then
	if ps | grep -v grep | grep -q "$prefix/pixelserv $redirip"; then
		elog "pixelserv already running, skipping"
	else
		elog "Setting up pixelserv on $redirip"

		iptables -vL INPUT | grep -q "$BRIDGE.*$redirip *tcp dpt:www" || {
		iptables -I INPUT -i "$BRIDGE" -p all -d "$redirip" -j DROP
		iptables -I INPUT -i "$BRIDGE" -p tcp -d "$redirip" --dport 80 -j ACCEPT
	}
	ifconfig "$BRIDGE":1 "$redirip" up
	"$prefix/pixelserv" "$redirip" "$PIXEL_OPTS"
fi
fi

elog "Done, restarting dnsmasq"
service dnsmasq restart

pexit 0
