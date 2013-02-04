# Copyright 2012-2013 Benjamin Savoy
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

require 'rubygems'
require 'ffi-rzmq'
require 'zlib'
require 'cityhash'
require 'logger'
require 'mongo'
require 'json'
include Mongo

### Begin config

# This connects to a local MongoDB instance. 
# Feel free to change it to your own specifications
@client = MongoClient.new('127.0.0.1', 27017)
@db = @client['eve']
@coll = Hash[]
@coll.default_proc = proc do |hash, key|
  hash[key] = @db[key]
end

# The amount of message hashes to keep in memory.
# Default size is 64 which consumes very little RAM.
buffer_size = 64

# Setup logger. Feel free to change the location.
# Default location is /var/log/eve/emdr-{read, api}.log
# Default threshold is Logger::INFO
logger = Logger.new('/var/log/eve/emdr-read.log')
logger.sev_threshold = Logger::INFO

# All mirrors can be left uncommented, as deduplication occurs.
# But if you prefer, you can go down to 2-3 mirrors.
relays = Array[]
relays.push('tcp://relay-us-west-1.eve-emdr.com:8050')
relays.push('tcp://relay-us-central-1.eve-emdr.com:8050')
relays.push('tcp://relay-ca-east-1.eve-emdr.com:8050')
relays.push('tcp://relay-us-east-1.eve-emdr.com:8050')
relays.push('tcp://relay-eu-uk-1.eve-emdr.com:8050')
relays.push('tcp://relay-eu-france-2.eve-emdr.com:8050')
relays.push('tcp://relay-eu-germany-1.eve-emdr.com:8050')
relays.push('tcp://relay-eu-denmark-1.eve-emdr.com:8050')

### End config

context = ZMQ::Context.new
subscriber = context.socket(ZMQ::SUB)

relays.each do |relay|
  subscriber.connect(relay)
end

subscriber.setsockopt(ZMQ::SUBSCRIBE,'')

class Hash
  # This function transforms an entry's rows into hashes, 
  # With indexes specified by 'columns'
  def zip!(columns)
    hashed_rows = Array[]
    self['rows'].each do |self_row|
      hashed_rows.push(Hash[columns.zip(self_row)])
    end
    self['rows'] = hashed_rows
  end

  # This function takes two entries and merges rows
  # From 'hash' to 'self' if they don't exist already.
  def combine!(hash)
    self_rows = self['rows']
    hash['rows'].each do |hash_row|
      matching_row = self_rows.find {|f| f['date'] == hash_row['date']}
      if matching_row == nil
        self_rows.push(hash_row)
      end
    end
    self['rows'] = self_rows
  end

  # This is a simple function to keep a hash to a moderate size
  def cleanup!(max_len)
    if self.length >= max_len
      self.clear
    end
  end
end

logger.fatal "Started EMDR Reader"
processed = Hash[]
loop do

  subscriber.recv_string(string = '')
  market_json = Zlib::Inflate.new(Zlib::MAX_WBITS).inflate(string)
  message_id = CityHash.hash128(market_json)

  if processed[message_id] == nil
    processed.cleanup!(buffer_size)
    processed[message_id] = 1

    system_date = Time.now.utc.strftime("%Y-%m-%dT%H:%M:%S+00:00")
    market_data = JSON.parse(market_json)

    category = market_data['resultType']
    columns = market_data['columns']
    rowsets = market_data['rowsets']

    rowsets.each do |entry|
      entry_date = entry['generatedAt']

      if (category == 'history' or category == 'orders') and entry_date <= system_date

        region = entry['regionID']
        type = entry['typeID']
        current = @coll[category].find_one({'regionID' => region, 'typeID' => type})

        if current == nil
          entry.zip!(columns)
          @coll[category].insert(entry)

        else
          current_date = current['generatedAt']
          id = current['_id']

          if category == 'history'
            entry.zip!(columns)
            if current_date < entry_date
              main_record = entry
              sec_record = current
            else
              main_record = current
              sec_record = entry
            end
            main_record.combine!(sec_record)
            @coll['history'].update({'_id' => id}, main_record)

          elsif current_date < entry_date
            entry.zip!(columns)
            @coll[category].update({'_id' => id}, entry)
          end
        end
      else 
        if entry_date > system_date
          logger.warn "Time #{date} happens after current time #{system_date}."
        else
          logger.warn "Category #{category} doesn't exist."
        end
        logger.info "Offending message is #{market_data}"
      end
    end
  end
end