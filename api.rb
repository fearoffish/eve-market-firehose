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

require 'logger'
require 'sinatra'
require 'mongo'
require 'json'
include Mongo

# This connects to a local MongoDB instance. 
# Feel free to change it to your own specifications

class MongoFactory
  def self.connection
    if @connection == nil
      self.connect
    end
    @connection 
  end
  def self.connect
    @connection = MongoClient.new('127.0.0.1', 27017, :timeout => 3600)
  end
end

def get_average(typeID, coll)
  cmd = [
      {"$match" => {
        :typeID => typeID}},
      {"$unwind" => "$rows"},
      {"$group" => {
        :_id => "$rows.date", 
        :quantity => {"$sum" => "$rows.quantity"}, 
        :volume => {"$sum" => {"$multiply" => 
          ["$rows.quantity", "$rows.average"]}}}},
      {"$sort" => {:_id => -1}}, 
      {"$limit" => 7},
      {"$group" => {
        :_id => 0,
        :quantity => {"$sum" => "$quantity"},
        :volume => {"$sum" => "$volume"}}},
      {"$project" => {
        :_id => 0, 
        :average => {"$divide" => 
          ["$volume", "$quantity"]}}}]

  output = coll.aggregate(cmd)

  if output != nil && output[0] != nil
    output[0]['average']
  else 
    0
  end
end

get '/prices' do
  @mongo = MongoFactory.connection
  @db = @client['eve']

  ids_cmd = [{'$project' => 
    {:_id => 0, :typeID => 1}}]

  ids = @db['history'].aggregate(ids_cmd)

  names_hash = Hash[]
  names_cmd = [{'$project' => 
    {:_id => 0, :typeID => 1, :typeName => 1}}]

  names = @db['invTypes'].aggregate(names_cmd)
  names.each do |entry|
    names_hash[entry['typeID']] = entry['typeName']
  end

  result = Hash[]
  ids.each do |rec|
    id = Integer(rec['typeID'])
    result[id] = Hash[]
    result[id]['avg'] = get_average(id, @db['history'])
    result[id]['name'] = names_hash[id]
  end

  JSON.fast_generate(result)
end