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
# This assumes you'll be around US-East, but you can change this.
#subscriber.connect('tcp://relay-us-west-1.eve-emdr.com:8050')
subscriber.connect('tcp://relay-us-central-1.eve-emdr.com:8050')
subscriber.connect('tcp://relay-ca-east-1.eve-emdr.com:8050')
subscriber.connect('tcp://relay-us-east-1.eve-emdr.com:8050')
#subscriber.connect('tcp://relay-eu-uk-1.eve-emdr.com:8050')
#subscriber.connect('tcp://relay-eu-france-2.eve-emdr.com:8050')
#subscriber.connect('tcp://relay-eu-germany-1.eve-emdr.com:8050')
#subscriber.connect('tcp://relay-eu-denmark-1.eve-emdr.com:8050')
subscriber.setsockopt(ZMQ::SUBSCRIBE,'')

# Setup logger. Feel free to change the logs' location
logger = Logger.new('/var/log/eve/emdr-read.log')
logger.info {'Starting up EMDR reader' }


# This function is tailored to keep older history records on board.
# It adds to 'main' all elements from 'secondary' that don't exist in 'main'
# It takes as input the content of 'rows' in the data.
def combine_rows(main, secondary)
   for sec_row in secondary
    matching_row = main.select{|f| f['date'] == sec_row['date']}
    if matching_row == nil
      main.push(matching_row)
    end
  end
  return main
end

# Start reading messages
loop do

  # Grab the latest message, and put it in a hash
  subscriber.recv_string(string = '')
  market_json = Zlib::Inflate.new(Zlib::MAX_WBITS).inflate(string)
  market_data = JSON.parse(market_json)

  # Get only the necessary information. The rest can be discarded.
  category = market_data['resultType']
  columns = market_data['columns']
  rowsets = market_data['rowsets']

  # Iterate over the several items which may be present in a single message.
  for entry in rowsets

    # This is the date format that MongoDB uses. 
    # We only then have to compare them alphabetically.
    system_date = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S+00:00")
    # We first check if the data is not corrupted
    entry_date = entry['generatedAt']
    if ( category == 'history' or category == 'orders' ) and entry_date <= system_date

      # Specifies which category this record is about.
      if category == 'history'
        @selected = @history
      else
        @selected = @orders
      end

      # We change the rows from a 2-dimensional array to an array of hashes.
      # This means that each row will be a sub-document in MongoDB
      entry_rows = entry['rows']
      hashed_rows = Array[]
      for entry_row in entry_rows
        hashed_row = Hash[columns.zip(entry_row)]
        hashed_rows.push(hashed_row)
      end

      # And we also update the entry with the newly formatted rows
      entry.update(Hash['rows', hashed_rows])
      
      # We check if a record is already there for the given region and item
      region = entry['regionID']
      type = entry['typeID']
      current = @selected.find_one({'regionID' => region, 'typeID' => type})
      
      # If there's no record for one item, we add it.
      if current == nil
        @selected.insert(entry)

      # If there's a record already, we may want to update it.
      else
        id = current["_id"]
        current_date = current['generatedAt']

        # If the entry is newer than what we currently have, we update the DB.
        if current_date < entry_date

          # If we're working with history, we have to keep some subdocuments,
          # Given that the database may have some older records, too.
          # To do so, we modify 'entry' to include older records.
          if @selected == @history
            rows = combine_rows(entry['rows'], current['rows'])
            entry.update(Hash['rows', rows])
          end

          # Finally, we update our entry.
          @selected.update({'_id' => id}, entry)

        # If the current document is older than the latest,
        # It may still contain old data the DB doesn't have
        elsif @selected == @history
            rows = combine_rows(current['rows'], entry['rows'])
            @selected.update({'_id' => id}, {'$set' => {'rows' => rows}})
        end 
      end

    # Catch errors from malformed items
    else 
      if entry_date > system_date
        logger.error { "Time #{date} happens after current time #{system_date}." }
      else
        logger.error { "Category #{category} doesn't exist." }
      end

      # Also output the message in question for tracking
      logger.info { 'Offending message caught:' }
      logger.info { market_data }
    end
  end
end