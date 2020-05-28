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

module SnowplowTracker

  class Subject

    @@default_platform = 'srv'
    @@supported_platforms = ['pc', 'tv', 'mob', 'cnsl', 'iot']

    attr_reader :standard_nv_pairs

    def initialize
      @standard_nv_pairs = {"p" => @@default_platform}
      self
    end

    # Specify the platform
    #
    def set_platform(value)
      if @@supported_platforms.include?(value)
        @standard_nv_pairs['p'] = value
      else
        raise "#{value} is not a supported platform"
      end

      self
    end

    # Set the business-defined user ID for a user
    #
    def set_user_id(user_id)
      @standard_nv_pairs['uid'] = user_id
      self
    end

    # Set fingerprint for the user
    #
    def set_fingerprint(fingerprint)
      @standard_nv_pairs['fp'] = fingerprint
      self
    end

    # Set the screen resolution for a device
    #
    def set_screen_resolution(width, height)
      @standard_nv_pairs['res'] = "#{width}x#{height}"
      self
    end

    # Set the dimensions of the current viewport
    #
    def set_viewport(width, height)
      @standard_nv_pairs['vp'] = "#{width}x#{height}"
      self
    end

    # Set the color depth of the device in bits per pixel
    #
    def set_color_depth(depth)
      @standard_nv_pairs['cd'] = depth
      self
    end

    # Set the timezone field
    #
    def set_timezone(timezone)
      @standard_nv_pairs['tz'] = timezone
      self
    end

    # Set the language field
    #
    def set_lang(lang)
      @standard_nv_pairs['lang'] = lang
      self
    end

    # Set the domain user ID
    #
    def set_domain_user_id(duid)
      @standard_nv_pairs['duid'] = duid
      self
    end

    # Set the IP address field
    #
    def set_ip_address(ip)
      @standard_nv_pairs['ip'] = ip
      self
    end

    # Set the user agent
    #
    def set_useragent(ua)
      @standard_nv_pairs['ua'] = ua
      self
    end

    # Set the network user ID field
    #  This overwrites the nuid field set by the collector
    #
    def set_network_user_id(nuid)
      @standard_nv_pairs['tnuid'] = nuid
      self
    end

  end

end
