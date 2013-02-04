all: install

install:
	mkdir -pm 755 /usr/lib/eve /var/log/eve
	touch /var/log/eve/emdr-read.log
	touch /var/log/eve/emdr-api.log
	chown -R daemon:daemon /var/log/eve
	install -m 644 data.rb /usr/lib/eve/data.rb
	install -m 644 data.rb /usr/lib/eve/api.rb
	install -m 644 data.rb /usr/lib/eve/settings.rb
	install -m 644 emdr-read.service /usr/lib/systemd/system/emdr-read.service
	install -m 644 emdr-api.service /usr/lib/systemd/system/emdr-api.service

uninstall:
	rm -f /usr/lib/systemd/system/emdr-read.service
	rm -f /usr/lib/systemd/system/emdr-api.service
	rm -f /etc/systemd/sytem/multi-user.target.wants/emdr-read.service
	rm -f /etc/systemd/sytem/multi-user.target.wants/emdr-api.service
	rm -rf /usr/lib/eve
	rm -rf /var/log/eve