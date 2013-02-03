all: install

install:
	mkdir -pm 755 /usr/lib/eve /var/log/eve
	chown daemon:daemon /var/log/eve
	install -m 644 data.rb /usr/lib/eve/data.rb
	touch /var/log/eve/emdr-read.log
	chown daemon:daemon /var/log/eve/emdr-read.log
	install -m 644 emdr-read.service /usr/lib/systemd/system/emdr-read.service

uninstall:
	rm -f /usr/lib/eve/data.rb
	rm -f /var/log/eve/emdr-read.log
	rm -f /usr/lib/systemd/system/emdr-read.service
	rm -f /etc/systemd/sytem/multi-user.target.wants/emdr-read.service
	@if [ -z `ls /usr/lib/eve` ]; then \
		rm -rf /usr/lib/eve; \
	fi
	@if [ -z `ls /var/log/eve` ]; then \
		rm -rf /var/log/eve; \
	fi