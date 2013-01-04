# EvE Market Data Client
## Dependencies:
- MongoDB
- Ruby (Tested with 1.9.3)
- ZeroMQ

## Notes:
I recommend that you perform the following operations on the MongoDB database before anything else:

    mongo
    > use eve
    > db.history.ensureIndex( { "typeID": 1, "regionID": 1 }, { unique: true, dropDups: true } )
    > db.orders.ensureIndex( { "typeID": 1, "regionID": 1 }, { unique: true, dropDups: true } )
    > db.orders.ensureIndex( { regionID: 1 } )
    > db.orders.ensureIndex( { typeID: 1 } )
    > db.history.ensureIndex( { typeID: 1 } )
    > db.history.ensureIndex( { regionID: 1 } )
    > exit


## Hardware requirements:

Currently this program consumes almost always less than (Along with the MongoDB writes):

- 512MB RAM
- 360 MHz (From an Atom D425 CPU)
