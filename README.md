# EvE Market Data Client

## About
This is an optimized and fully featured reader for the EvE Market Data Relay, which uses MongoDB as backend.

Cool stuff:

- It is not fooled by fake data, and aggregates the items history for as many years as you'll be running.
- It can easily get data from an enormous amount of relays with very little drawback, thanks to de-duplication.
- It's open source!

## Requirements
- MongoDB
- ZeroMQ
- Ruby (Tested with 1.9.3)

## Notes:

You will need to have hardware time very well synced otherwise the reader will drop some messages incorrectly.

I also recommend that you perform the following operations on the MongoDB database before anything else:

    $ mongo
    use eve
    db.history.ensureIndex( 
        {'typeID': 1, 'regionID': 1}, 
        {unique: true, dropDups: true})
    db.history.ensureIndex({'regionID': 1})
    db.history.ensureIndex({'typeID': 1})
    db.history.ensureIndex({'rows.date': 1})
    db.orders.ensureIndex( 
        {'typeID': 1, 'regionID': 1}, 
        {unique: true, dropDups: true})
    db.orders.ensureIndex({'regionID': 1})
    db.orders.ensureIndex({'typeID': 1})
    exit

## Installation

Get the gems with bundler! But be careful, they should be installed system-wide or for the user who'll run this program (Daemon by default)

Installing files is made through the Makefile. It also has an uninstall option.

	sudo make install

It assumes that you're using systemd for init. Otherwise feel free to start it up with your own script.

## License

Copyright 2012-2013 Benjamin Savoy

This project is licensed under the Apache License, Version 2.0 (the "License"); you may not use the files herein except 
in compliance with the License. You may obtain a copy of the License at:

http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
specific language governing permissions and limitations under the License.