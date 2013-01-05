require 'rubygems'
require 'ffi-rzmq'
require 'json'
require 'zlib'
require 'mongo'
include Mongo

# This connects to a local MongoDB instance. 
# Feel free to change it if you want to connect to a remote instance.
@client = MongoClient.new('127.0.0.1', 27017)
@db = @client['eve']
@orders = @db['orders']
@history = @db['history']

context = ZMQ::Context.new
subscriber = context.socket(ZMQ::SUB)

# It is recommended to uncomment at least 2 mirrors from this list. 
# By default we assume that you are located in the USA.
subscriber.connect("tcp://relay-us-central-1.eve-emdr.com:8050")
subscriber.connect("tcp://relay-us-east-1.eve-emdr.com:8050")
subscriber.connect("tcp://relay-us-west-1.eve-emdr.com:8050")
# subscriber.connect("tcp://relay-eu-uk-1.eve-emdr.com:8050")
# subscriber.connect("tcp://relay-eu-france-2.eve-emdr.com:8050")
# subscriber.connect("tcp://relay-eu-denmark-1.eve-emdr.com:8050")
# subscriber.connect("tcp://relay-eu-germany-1.eve-emdr.com:8050")

subscriber.setsockopt(ZMQ::SUBSCRIBE,"")

loop do
  subscriber.recv_string(string = '')
  market_json = Zlib::Inflate.new(Zlib::MAX_WBITS).inflate(string)
  market_data = JSON.parse(market_json)

  category = market_data.fetch('resultType')
  rows = market_data.fetch('rowsets')
  for row in rows
    region = row.fetch('regionID')
    type = row.fetch('typeID')
    date = row.fetch('generatedAt')
    curr_date = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S+00:00")

    if ( category == "history" or category == "orders" ) and date <= curr_date
      # Specifies which category this record is about.
      if category == "history"
        @selected = @history
      else
        @selected = @orders
      end

      item = @selected.find_one({"regionID" => region, "typeID" => type})
      if item == nil
        # If there's no record for one item, we add it.
        @selected.insert(row)
      else
        id = item.fetch("_id")
        item_date = item.fetch("generatedAt")
        # If the stored date is earlier than the new one, 
        # We update the element for the newest one
        if item_date < date
          @selected.update({"_id" => id}, row)
        end 
      end
    else 
      if date > curr_date
        puts "ERROR: Time #{date} happens after current time #{curr_date}. Offending message is:"
      else
        puts "ERROR: Category #{category} doesn't exist. Offending message is:"
      end
      puts market_data
    end
  end
end
