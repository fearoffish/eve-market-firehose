# EvE Market Data Client
## Dependencies:
- MongoDB
- ZeroMQ
- Ruby (Tested with 1.9.3)

## Notes:
I recommend that you perform the following operations on the MongoDB database before anything else:

    $ mongo
    use eve
    db.history.ensureIndex( { "typeID": 1, "regionID": 1 }, { unique: true, dropDups: true } )
    db.orders.ensureIndex( { "typeID": 1, "regionID": 1 }, { unique: true, dropDups: true } )
    db.orders.ensureIndex( { regionID: 1 } )
    db.orders.ensureIndex( { typeID: 1 } )
    db.history.ensureIndex( { typeID: 1 } )
    db.history.ensureIndex( { regionID: 1 } )
    exit

## Installation

Get the gems with bundler! But be careful, they should be installed system-wide or for the user who'll run this program (Daemon by default)

Installing files is made through the Makefile. It also has an uninstall option.

	sudo make install

	# Installs the following:
	/usr/lib/systemd/system/emdr-read.service
	/usr/lib/eve/data.rb
	/var/log/eve/emdr-read.log

It assumes that you're using systemd for init. Otherwise feel free to start it up with your own script.

The target emdr-read.target is composed of the EMDR Relay and MongoDB in my case. Feel free to change it how you'd like