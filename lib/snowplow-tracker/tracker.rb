# Copyright (c) 2013-2014 Snowplow Analytics Ltd. All rights reserved.
#
# This program is licensed to you under the Apache License Version 2.0,
# and you may not use this file except in compliance with the Apache License Version 2.0.
# You may obtain a copy of the Apache License Version 2.0 at http://www.apache.org/licenses/LICENSE-2.0.
#
# Unless required by applicable law or agreed to in writing,
# software distributed under the Apache License Version 2.0 is distributed on an
# "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the Apache License Version 2.0 for the specific language governing permissions and limitations there under.

# Author:: Alex Dean, Fred Blundun (mailto:support@snowplowanalytics.com)
# Copyright:: Copyright (c) 2013-2014 Snowplow Analytics Ltd
# License:: Apache License Version 2.0

require 'securerandom'
require 'set'

module SnowplowTracker

  class Tracker
    @@version = TRACKER_VERSION
    @@default_encode_base64 = true

    @@base_schema_path = "iglu:com.snowplowanalytics.snowplow"
    @@schema_tag = "jsonschema"
    @@context_schema = "#{@@base_schema_path}/contexts/#{@@schema_tag}/1-0-1"
    @@unstruct_event_schema = "#{@@base_schema_path}/unstruct_event/#{@@schema_tag}/1-0-0"

    def initialize(emitters, subject=nil, namespace=nil, app_id=nil, encode_base64=@@default_encode_base64)
      @emitters = Array(emitters)
      if subject.nil?
        @subject = Subject.new
      else
        @subject = subject
      end
      @standard_nv_pairs = {
        'tna' => namespace,
        'tv'  => @@version,
        'aid' => app_id
      }
      @config = {
        'encode_base64' => encode_base64
      }

      self
    end

    # Call subject methods from tracker instance
    #
    Subject.instance_methods(false).each do |name|
      define_method name, ->(*splat) do
        @subject.method(name.to_sym).call(*splat)

        self
      end
    end

    # Generates a type-4 UUID to identify this event
    def get_event_id()
      SecureRandom.uuid
    end

    # Generates the timestamp (in milliseconds) to be attached to each event
    #
    def get_timestamp
      (Time.now.to_f * 1000).to_i
    end

    # Builds a self-describing JSON from an array of custom contexts
    #
    def build_context(context)
      SelfDescribingJson.new(
        @@context_schema,
        context.map {|c| c.to_json}
        ).to_json
    end

    # Tracking methods

    # Attaches all the fields in @standard_nv_pairs to the request
    #  Only attaches the context vendor if the event has a custom context
    #
    def track(pb)
      pb.add_dict(@subject.standard_nv_pairs)
      pb.add_dict(@standard_nv_pairs)
      pb.add('eid', get_event_id())
      @emitters.each{ |emitter| emitter.input(pb.context)}

      nil
    end

    # Log a visit to this page
    #
    def track_page_view(page_url, page_title=nil, referrer=nil, context=nil, tstamp=nil)
      if tstamp.nil?
        tstamp = get_timestamp
      end
      tstamp = DeviceTimestamp.new(tstamp) unless tstamp.kind_of?(Timestamp)

      pb = Payload.new
      pb.add('e', 'pv')
      pb.add('url', page_url)
      pb.add('page', page_title)
      pb.add('refr', referrer)

      unless context.nil?
        pb.add_json(build_context(context), @config['encode_base64'], 'cx', 'co')
      end

      pb.add(tstamp.type, tstamp.value)

      track(pb)

      self
    end

    # Track a single item within an ecommerce transaction
    #   Not part of the public API
    #
    def track_ecommerce_transaction_item(argmap)
      pb = Payload.new
      pb.add('e', 'ti')
      pb.add('ti_id', argmap['order_id'])
      pb.add('ti_sk', argmap['sku'])
      pb.add('ti_pr', argmap['price'])
      pb.add('ti_qu', argmap['quantity'])
      pb.add('ti_nm', argmap['name'])
      pb.add('ti_ca', argmap['category'])
      pb.add('ti_cu', argmap['currency'])
      unless argmap['context'].nil?
        pb.add_json(build_context(argmap['context']), @config['encode_base64'], 'cx', 'co')
      end
      pb.add(argmap['tstamp'].type, argmap['tstamp'].value)
      track(pb)

      self
    end

    # Track an ecommerce transaction and all the items in it
    #
    def track_ecommerce_transaction(transaction, items, context=nil, tstamp=nil)
      if tstamp.nil?
        tstamp = get_timestamp
      end
      tstamp = DeviceTimestamp.new(tstamp) unless tstamp.kind_of?(Timestamp)

      pb = Payload.new
      pb.add('e', 'tr')
      pb.add('tr_id', transaction['order_id'])
      pb.add('tr_tt', transaction['total_value'])
      pb.add('tr_af', transaction['affiliation'])
      pb.add('tr_tx', transaction['tax_value'])
      pb.add('tr_sh', transaction['shipping'])
      pb.add('tr_ci', transaction['city'])
      pb.add('tr_st', transaction['state'])
      pb.add('tr_co', transaction['country'])
      pb.add('tr_cu', transaction['currency'])
      unless context.nil?
        pb.add_json(build_context(context), @config['encode_base64'], 'cx', 'co')
      end

      pb.add(tstamp.type, tstamp.value)

      track(pb)

      for item in items
        item['tstamp'] = tstamp
        item['order_id'] = transaction['order_id']
        item['currency'] = transaction['currency']
        track_ecommerce_transaction_item(item)
      end

      self
    end

    # Track a structured event
    #
    def track_struct_event(category, action, label=nil, property=nil, value=nil, context=nil, tstamp=nil)
      if tstamp.nil?
        tstamp = get_timestamp
      end
      tstamp = DeviceTimestamp.new(tstamp) unless tstamp.kind_of?(Timestamp)

      pb = Payload.new
      pb.add('e', 'se')
      pb.add('se_ca', category)
      pb.add('se_ac', action)
      pb.add('se_la', label)
      pb.add('se_pr', property)
      pb.add('se_va', value)
      unless context.nil?
        pb.add_json(build_context(context), @config['encode_base64'], 'cx', 'co')
      end

      pb.add(tstamp.type, tstamp.value)
      track(pb)

      self
    end

    # Track a screen view event
    #
    def track_screen_view(name=nil, id=nil, context=nil, tstamp=nil)
      screen_view_properties = {}
      unless name.nil? 
        screen_view_properties['name'] = name
      end
      unless id.nil? 
        screen_view_properties['id'] = id
      end
      screen_view_schema = "#{@@base_schema_path}/screen_view/#{@@schema_tag}/1-0-0"

      event_json = SelfDescribingJson.new(screen_view_schema, screen_view_properties)

      self.track_unstruct_event(event_json, context, tstamp)

      self
    end

    # Better name for track unstruct event
    # set the timestamp to the device timestamp
    def track_self_describing_event(event_json, context=nil, tstamp=nil)
      track_unstruct_event(event_json, context, tstamp)
    end

    # Track an unstructured event
    #
    def track_unstruct_event(event_json, context=nil, tstamp=nil)
      if tstamp.nil?
        tstamp = get_timestamp
      end
      tstamp = DeviceTimestamp.new(tstamp) unless tstamp.kind_of?(Timestamp)

      pb = Payload.new
      pb.add('e', 'ue')
      
      envelope = SelfDescribingJson.new(@@unstruct_event_schema, event_json.to_json)

      pb.add_json(envelope.to_json, @config['encode_base64'], 'ue_px', 'ue_pr')

      unless context.nil?
        pb.add_json(build_context(context), @config['encode_base64'], 'cx', 'co')
      end

      pb.add(tstamp.type, tstamp.value)

      track(pb)

      self
    end

    # Flush all events stored in all emitters
    #
    def flush(async=false)
      @emitters.each do |emitter|
        emitter.flush(async)
      end

      self
    end

    # Set the subject of the events fired by the tracker
    #
    def set_subject(subject)
      @subject = subject
      self
    end

    # Add a new emitter
    #
    def add_emitter(emitter)
      @emitters.push(emitter)
      self
    end

    private :get_timestamp,
            :build_context,
            :track,
            :track_ecommerce_transaction_item

  end

end
