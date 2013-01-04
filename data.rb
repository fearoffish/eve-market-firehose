require 'rubygems'
require 'ffi-rzmq'
require 'json'
require 'zlib'
require 'mongo'
include Mongo

@client = MongoClient.new('127.0.0.1', 27017)
@db = @client['eve']
@orders = @db['orders']
@history = @db['history']

context = ZMQ::Context.new
subscriber = context.socket(ZMQ::SUB)

subscriber.connect("tcp://relay-us-central-1.eve-emdr.com:8050")
subscriber.setsockopt(ZMQ::SUBSCRIBE,"")

loop do
  subscriber.recv_string(string = '')
  market_json = Zlib::Inflate.new(Zlib::MAX_WBITS).inflate(string)
  market_data = JSON.parse(market_json)

  puts "LOG: Recieved message"
  puts market_data

  category = market_data.fetch('resultType')
  rows = market_data.fetch('rowsets')
  for row in rows
    region = row.fetch('regionID')
    type = row.fetch('typeID')
    date = row.fetch('generatedAt')

    if category == "history" or category == "orders"
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
      puts "ERROR: Category #{type} doesn't exist."
    end
  end
end