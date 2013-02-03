require 'rubygems'
require 'ffi-rzmq'
require 'json'
require 'zlib'
require 'mongo'
require 'logger'
include Mongo

# This connects to a local MongoDB instance. 
# Feel free to change it if you want to connect to a remote instance.
@client = MongoClient.new('127.0.0.1', 27017)
@db = @client['eve']
@orders = @db['orders']
@history = @db['history']

# Setup ZeroMQ
context = ZMQ::Context.new
subscriber = context.socket(ZMQ::SUB)

# It is recommended to keep at least 3 mirrors from this list.
subscriber.connect("tcp://relay-eu-uk-1.eve-emdr.com:8050")
subscriber.connect("tcp://relay-us-east-1.eve-emdr.com:8050")
subscriber.connect("tcp://relay-us-west-1.eve-emdr.com:8050")
subscriber.connect("tcp://relay-ca-east-1.eve-emdr.com:8050")
subscriber.connect("tcp://relay-eu-france-2.eve-emdr.com:8050")
subscriber.connect("tcp://relay-us-central-1.eve-emdr.com:8050")
subscriber.connect("tcp://relay-eu-denmark-1.eve-emdr.com:8050")
subscriber.connect("tcp://relay-eu-germany-1.eve-emdr.com:8050")
subscriber.setsockopt(ZMQ::SUBSCRIBE,"")

# Setup logger. Feel free to change the logs' location
logger = Logger.new('/var/log/eve/emdr-read.log')
logger.info { "Starting up EMDR reader" }

# Start reading messages
loop do

  # Grab the latest message, and put it in a hash
  subscriber.recv_string(string = '')
  market_json = Zlib::Inflate.new(Zlib::MAX_WBITS).inflate(string)
  market_data = JSON.parse(market_json)

  # Get only the necessary information. The rest can be discarded.
  category = market_data.fetch('resultType')
  columns = market_data.fetch('columns')
  rows = market_data.fetch('rowsets')

  # Iterate over the several items which may be present in a single message.
  for row in rows

    # This is the date format that MongoDB uses. 
    # We only then have to compare them alphabetically.
    curr_date = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S+00:00")
    # We first check if the data is not corrupted
    date = row.fetch('generatedAt')
    if ( category == "history" or category == "orders" ) and date <= curr_date

      # Specifies which category this record is about.
      if category == "history"
        @selected = @history
      else
        @selected = @orders
      end

      # We change the rows from a 2-dimensional array to an array of hashes.
      # This means that each row will be a sub-document in MongoDB
      sub_rows = row.fetch('rows')
      hashed_rows = Array[]
      for sub_row in sub_rows
        hashed_row = Hash[columns.zip(sub_row)]
        hashed_rows.push(hashed_row)
      end

      # We check if a record is already there for the given region and item
      region = row.fetch('regionID')
      type = row.fetch('typeID')
      item = @selected.find_one({"regionID" => region, "typeID" => type})
      
      # If there's no record for one item, we add it.
      if item == nil
        @selected.insert(row)

      # If there's a record already, we may want to update it.
      else
        id = item.fetch("_id")
        item_date = item.fetch("generatedAt")

        # If the new data is not older than what we have, we update the DB.
        if item_date < date
          @selected.update({"_id" => id}, row)
        end 
      end

    # Catch errors from malformed items
    else 
      if date > curr_date
        logger.error { "Time #{date} happens after current time #{curr_date}." }
      else
        logger.error { "Category #{category} doesn't exist." }
      end

      # Also output the message in question for tracking
      logger.info { 'Offending message caught:' }
      logger.info { market_data }
    end
  end
end
