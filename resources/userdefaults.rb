#
# Cookbook:: mac_os_x
#
# Copyright:: 2011-2018, Joshua Timberman
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
#

# align with apple's marketing department
resource_name :macos_userdefaults
provides :mac_os_x_userdefaults
provides :macos_userdefaults

property :domain, String, required: true
property :global, [true, false], default: false
property :key, String
property :value, [Integer, Float, String, true, false, Hash, Array], required: true, coerce: proc { |v| coerce_booleans(v) }
property :type, String, default: ''
property :user, String
property :sudo, [true, false], default: false
property :is_set, [true, false], default: false

# coerce various ways of representing a boolean into either 0 (false) or 1 (true)
# which is what the defaults CLI expects. Why? Well defaults itself accepts a few
# different formats, but when you do a read command it all comes back as 1 or 0.
def coerce_booleans(val)
  return 1 if [true, 'TRUE', '1', 'true', 'YES', 'yes'].include?(val)
  return 0 if [false, 'FALSE', '0', 'false', 'NO', 'no'].include?(val)
  val
end

load_current_value do |desired|
  drcmd = "defaults read '#{desired.domain}' "
  drcmd << "'#{desired.key}' " if desired.key
  shell_out_opts = {}
  shell_out_opts[:user] = desired.user unless desired.user.nil?
  vc = shell_out("#{drcmd} | grep -qx '#{desired.value}'", shell_out_opts)
  is_set vc.exitstatus == 0 ? true : false
end

action :write do
  unless current_value.is_set
    cmd = ['defaults write']
    cmd.unshift('sudo') if new_resource.sudo

    cmd << if new_resource.global
             'NSGlobalDomain'
           else
             "'#{new_resource.domain}'"
           end

    cmd << "'#{new_resource.key}'" if new_resource.key
    value = new_resource.value
    type = new_resource.type.empty? ? value_type(value) : new_resource.type
    # creates a string of Key1 Value1 Key2 Value2...
    value = value.map { |k, v| "\"#{k}\" \"#{v}\"" }.join(' ') if type == 'dict'
    if type == 'array'
      value = value.join("' '")
      value = "'#{value}'"
    end
    cmd << "-#{type}" if type
    cmd << value

    execute cmd.join(' ') do
      user new_resource.user unless new_resource.user.nil?
    end
  end
end
